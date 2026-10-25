'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
// No network or application database access; provider calls are stubbed.
process.env.NOMINATIM_BASE_URL='https://geocoder.example.test';
const db=require.resolve('../database/db');
require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async()=>({rows:[]})}};
const {searchDestinations}=require('../services/searchService');
test('search rejects invalid inputs without provider traffic',async()=>{
  const original=global.fetch;global.fetch=()=>{throw new Error('Unexpected request');};
  try {
    for(const data of [{query:['school'],latitude:1,longitude:2},{query:'school',latitude:91,longitude:2},{query:'school',latitude:1,longitude:2,radius:Infinity}]) {
      await assert.rejects(searchDestinations(data),e=>e.status===400);
    }
  } finally {global.fetch=original;}
});
test('empty search makes one request; cached repeat makes none; wheelchair=no never becomes accessible',async()=>{
  const original=global.fetch;let calls=0;
  global.fetch=async()=>{calls++;return {ok:true,json:async()=>calls===1?[]:[{place_id:1,lat:'1',lon:'2',name:'Inaccessible ramp',display_name:'Synthetic',extratags:{wheelchair:'no'}}]};};
  try {
    const input={query:'synthetic-empty',latitude:1,longitude:2};
    assert.deepEqual(await searchDestinations(input),[]);
    assert.deepEqual(await searchDestinations(input),[]);assert.equal(calls,1);
    const rows=await searchDestinations({...input,query:'synthetic-other'});
    assert.equal(calls,2);assert.equal(rows[0].isAccessible,false);
  } finally {global.fetch=original;}
});
