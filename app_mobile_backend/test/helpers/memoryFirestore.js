'use strict';
function memoryFirestore() {
  const records=new Map();let fail=false;
  const snap=ref=>({ref,id:ref.id,exists:records.has(ref.path),data:()=>records.get(ref.path)});
  function doc(path) {return {path,id:path.split('/').at(-1),collection:name=>query(`${path}/${name}`),
    get:async()=>snap(doc(path)),set:async(value,options)=>records.set(path,options?.merge?{...records.get(path),...value}:value)};}
  function query(path,orders=[],maximum=Infinity,after=null,filters=[]) {
    return {path,doc:id=>doc(`${path}/${id}`),
      orderBy:(key,direction)=>query(path,[...orders,[typeof key==='string'?key:'__name__',direction]],maximum,after,filters),
      limit:n=>query(path,orders,n,after,filters),startAfter:(...args)=>query(path,orders,maximum,args,filters),
      where:(key,op,value)=>query(path,orders,maximum,after,[...filters,[key,op,value]]),
      async get() {
        let rows=[...records.keys()].filter(k=>k.startsWith(path+'/')&&k.split('/').length===path.split('/').length+1).map(k=>snap(doc(k)));
        const val=(d,key)=>key==='__name__'?d.id:d.data()[key]?.toMillis?.()??d.data()[key];
        for(const [key,op,value] of filters) rows=rows.filter(d=>op==='=='?val(d,key)===value:val(d,key)<(value?.toMillis?.()??value));
        rows.sort((a,b)=>{for(const [key,dir] of orders){const av=val(a,key),bv=val(b,key);if(av!==bv)return (av<bv?-1:1)*(dir==='desc'?-1:1);}return 0;});
        if(after){const values=after[0]?.ref?orders.map(([key])=>val(after[0],key)):after.map(v=>v?.toMillis?.()??v);rows=rows.filter(d=>{for(let i=0;i<orders.length;i++){const v=val(d,orders[i][0]);if(v!==values[i])return orders[i][1]==='desc'?v<values[i]:v>values[i];}return false;});}
        rows=rows.slice(0,maximum);return {docs:rows,size:rows.length};
      }};
  }
  const store={collection:name=>query(name),async runTransaction(fn) {
    const writes=[];
    const tx={get:async ref=>ref.path.split('/').length%2===0?snap(ref):ref.get(),
      set:(ref,value,options)=>writes.push(()=>records.set(ref.path,options?.merge?{...records.get(ref.path),...value}:value)),
      update:(ref,value)=>writes.push(()=>records.set(ref.path,{...records.get(ref.path),...value}))};
    const result=await fn(tx);if(fail){fail=false;throw new Error('Synthetic interrupted commit');}
    writes.forEach(write=>write());return result;
  },async recursiveDelete(ref){for(const key of records.keys()) if(key===ref.path||key.startsWith(ref.path+'/'))records.delete(key);}};
  return {store,records,failNext:()=>{fail=true;}};
}
module.exports={memoryFirestore};
