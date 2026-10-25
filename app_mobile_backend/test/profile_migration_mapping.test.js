'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const path=require('node:path');

test('runtime-role migration renders grants only for the lowercase patient table',async()=>{
  for(const configured of [undefined,'patientprofiles','PatientProfiles']) {
    let output='',failure='';
    let finish;
    const done=new Promise(resolve=>{finish=resolve;});
    const pool={query:async(sql,args)=>{
      if(sql.includes('SELECT relname')) return {rows:[{relname:'Users'}]};
      if(sql.includes('information_schema.tables')) {
        assert.deepEqual(args[0],['patientprofiles']);
        return {rows:[{table_name:'patientprofiles'}]};
      }
      if(sql.includes('information_schema.columns')) return {rows:[{column_name:'user_id'}]};
      return {rows:[{}]};
    },end:async()=>finish()};
    const filename=require.resolve('../scripts/migratePairing');
    const fakeProcess={argv:['node',filename,'--migration=003_runtime_role'],env:{...(configured?{AKAY_PATIENT_TABLE:configured}:{})},stdout:{write:value=>{output+=value;}}};
    const load=id=>id==='../database/db'?pool:id==='../database/schemaCatalog'?require('../database/schemaCatalog'):require(id);
    new Function('require','process','console','__dirname',readFileSync(filename,'utf8'))(load,fakeProcess,{error:value=>{failure=value;},log:()=>{}},path.dirname(filename));
    await done;
    if(configured==='PatientProfiles') {
      assert.equal(output,'');assert.match(failure,/Unsupported configured table name/);
    } else {
      assert.equal(failure,'');assert.match(output,/GRANT SELECT,INSERT ON "patientprofiles",navigationsessions/);
      assert.doesNotMatch(output,/__PATIENT_TABLE__|PatientProfiles/);
    }
  }
});
