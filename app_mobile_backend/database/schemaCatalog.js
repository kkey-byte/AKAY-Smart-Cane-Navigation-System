'use strict';
// Catalog-only checks. Identifiers come from fixed allowlists, never requests.
async function resolveTable(pool,candidates,configured,columns,uniqueColumns=[]) {
  if(configured && !candidates.includes(configured)) throw new Error('Unsupported configured table name.');
  const rows=(await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name=ANY($1::text[]) AND table_type='BASE TABLE'",[candidates])).rows.map(r=>r.table_name);
  const selected=configured || (rows.length===1 ? rows[0] : null);
  if(!selected || !rows.includes(selected)) throw new Error('Missing or ambiguous table. Review schema and select an approved table explicitly.');
  const actual=(await pool.query("SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name=$1",[selected])).rows.map(r=>r.column_name);
  if(columns.some(c=>!actual.includes(c))) throw new Error('Required schema columns are missing. Review a migration before startup.');
  for(const column of uniqueColumns) {
    const result=await pool.query(`SELECT 1 FROM pg_index i JOIN pg_class t ON t.oid=i.indrelid
      JOIN pg_namespace n ON n.oid=t.relnamespace JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=i.indkey[0]
      WHERE n.nspname='public' AND t.relname=$1 AND a.attname=$2 AND i.indisunique AND i.indisvalid
      AND i.indnkeyatts=1 AND i.indpred IS NULL AND i.indexprs IS NULL`,[selected,column]);
    if(!result.rows.length) throw new Error('Required uniqueness is absent. Reconcile data and review a migration before startup.');
  }
  return '"'+selected+'"';
}
module.exports={resolveTable};
