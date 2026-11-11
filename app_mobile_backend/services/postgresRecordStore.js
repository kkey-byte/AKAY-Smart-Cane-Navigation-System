'use strict';
// Private persistence adapter for the existing history model. All data and
// transactions below are PostgreSQL; no Firebase SDK is used by this adapter.
const key=/^[A-Za-z0-9_-]{1,128}$/;
function parts(path) {
  const p=path.split('/');
  if(!p.every(s=>key.test(s))||!(p[0]==='navigators'&&[2,4,6].includes(p.length)&&
    (p.length<4||p[2]==='trips')&&(p.length<6||p[4]==='points')||
    p.length===4&&p[0]==='legacy_rtdb'&&['breadcrumb_shares','breadcrumb_links'].includes(p[1])&&p[2]==='records'))
    throw new Error('Unsupported persistent record path.');
  return {owner:p[0]==='navigators'?p[1]:p[3],parent:p.slice(0,-1).join('/'),collection:p.at(-2)};
}
const numeric=new Set(['startedAt','endedAt','sequence']);
const fields=new Set([...numeric,'sourceType','deviceId','assignmentId','__name__']);
function expression(field) {
  if(!fields.has(field)) throw new Error('Unsupported record query field.');
  return field==='__name__'?'path':numeric.has(field)?`(data->>'${field}')::bigint`:`data->>'${field}'`;
}
function createPostgresRecordStore(pool) {
  const snapshot=(ref,data)=>({ref,id:ref.id,exists:data!=null,data:()=>data});
  async function writeMany(client,writes) {
    // Fold sequential updates to the same row, then insert point batches in
    // bounded SQL requests rather than one database round trip per GPS point.
    const combined=new Map();
    for(const [ref,value,merge] of writes) {
      const prior=combined.get(ref.path);
      combined.set(ref.path,prior&&merge?[ref,{...prior[1],...value},prior[2]]:[ref,value,merge]);
    }
    for(const merge of [false,true]) {
      const rows=[...combined.values()].filter(row=>row[2]===merge);
      for(let offset=0;offset<rows.length;offset+=500) {
        const args=[],values=[];
        for(const [ref,value] of rows.slice(offset,offset+500)) {
          const p=parts(ref.path),start=args.length;
          args.push(ref.path,p.parent,p.collection,p.owner,JSON.stringify(value));
          values.push(`($${start+1},$${start+2},$${start+3},$${start+4},$${start+5}::jsonb)`);
        }
        await client.query(`INSERT INTO akay_persistent_records(path,collection_path,collection_name,owner_uid,data)
          VALUES ${values.join(',')} ON CONFLICT(path) DO UPDATE SET
          data=${merge?'akay_persistent_records.data || EXCLUDED.data':'EXCLUDED.data'},updated_at=clock_timestamp()`,args);
      }
    }
  }
  function doc(path) {
    if(!/^legacy_rtdb\/(breadcrumb_shares|breadcrumb_links)$/.test(path)) parts(path);
    const ref={path,id:path.split('/').at(-1),collection:name=>query(`${path}/${name}`),
      get:async()=>snapshot(ref,(await pool.query('SELECT data FROM akay_persistent_records WHERE path=$1',[path])).rows[0]?.data),
      set:async(value,options)=>store.runTransaction(async tx=>{await tx.get(ref);tx.set(ref,value,options);})};
    Object.defineProperty(ref,'parent',{get:()=>({parent:docParent(path),id:path.split('/').at(-2)})});
    return ref;
  }
  function docParent(path) {const parent=path.split('/').slice(0,-2).join('/');return parent?doc(parent):null;}
  function query(path,orders=[],maximum=1000,after=null,filters=[],group=false) {
    const ref={path,doc:id=>doc(`${path}/${id}`),
      orderBy:(field,direction='asc')=>query(path,[...orders,[field,direction]],maximum,after,filters,group),
      limit:n=>query(path,orders,n,after,filters,group),
      startAfter:(...values)=>query(path,orders,maximum,values,filters,group),
      where:(field,op,value)=>query(path,orders,maximum,after,[...filters,[field,op,value]],group),
      get:()=>readQuery(pool,ref)};
    ref._query={path,orders,maximum,after,filters,group};return ref;
  }
  async function readQuery(client,ref) {
    const {path,orders,maximum,after,filters,group}=ref._query;
    if(!Number.isInteger(maximum)||maximum<1||maximum>1000) throw new Error('Invalid query size.');
    if(group&&path!=='trips') throw new Error('Unsupported collection group.');
    const args=[path],where=[`${group?'collection_name':'collection_path'}=$1`];
    for(const [field,op,value] of filters) {
      if(!['==','<'].includes(op)) throw new Error('Unsupported query operator.');
      args.push(value);where.push(`${expression(field)} ${op==='=='?'=':'<'} $${args.length}`);
    }
    if(after) {
      const values=after[0]?.ref?orders.map(([f])=>f==='__name__'?after[0].ref.path:after[0].data()[f]):after;
      if(values.length!==orders.length) throw new Error('Invalid query cursor.');
      const positions=values.map((value,i)=>{
        args.push(orders[i][0]==='__name__'&&!String(value).includes('/')?`${path}/${value}`:value);
        return `$${args.length}`;
      });
      where.push('('+orders.map(([field,direction],i)=>'('+[
        ...orders.slice(0,i).map(([prior],j)=>`${expression(prior)}=${positions[j]}`),
        `${expression(field)}${direction==='desc'?'<':'>'}${positions[i]}`].join(' AND ')+')').join(' OR ')+')');
    }
    const order=orders.map(([field,direction])=>{
      if(!['asc','desc'].includes(direction)) throw new Error('Invalid sort order.');
      return `${expression(field)} ${direction} NULLS LAST`;
    });
    args.push(maximum);
    const result=await client.query(`SELECT path,data FROM akay_persistent_records WHERE ${where.join(' AND ')}
      ${order.length?'ORDER BY '+order.join(','):''} LIMIT $${args.length}`,args);
    const docs=result.rows.map(row=>snapshot(doc(row.path),row.data));return {docs,size:docs.length};
  }
  const store={collection:name=>query(name),collectionGroup:name=>query(name,[],1000,null,[],true),
    async runTransaction(fn) {
      const client=await pool.connect();let lockedOwner;
      async function lock(ref) {
        if(ref._query) return;
        const owner=parts(ref.path).owner;
        if(lockedOwner&&lockedOwner!==owner) throw new Error('Cross-account history transaction denied.');
        if(!lockedOwner) {lockedOwner=owner;await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',[`akay_history:${owner}`]);}
      }
      const writes=[];
      try {
        await client.query('BEGIN');
        const tx={get:async ref=>{
          await lock(ref);
          return ref._query?readQuery(client,ref):snapshot(ref,(await client.query('SELECT data FROM akay_persistent_records WHERE path=$1',[ref.path])).rows[0]?.data);
        },set:(ref,value,options)=>writes.push([ref,value,options?.merge===true]),
          update:(ref,value)=>writes.push([ref,value,true])};
        const result=await fn(tx);
        for(const [ref] of writes) await lock(ref);
        await writeMany(client,writes);
        await client.query('COMMIT');return result;
      } catch(error) {await client.query('ROLLBACK');throw error;} finally {client.release();}
    },
    async recursiveDelete(ref) {
      // Exact prefix plus slash: never matches an adjacent account/trip name.
      await pool.query('DELETE FROM akay_persistent_records WHERE path=$1 OR left(path,length($1)+1)=$1 || \'/\'',[ref.path]);
    }};
  return store;
}
module.exports={createPostgresRecordStore};
