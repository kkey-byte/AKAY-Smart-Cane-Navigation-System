'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
process.env.NOMINATIM_BASE_URL='';
process.env.PHOTON_BASE_URL='https://photon.example.test';
const db=require.resolve('../database/db');require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async()=>({rows:[]})}};
const {searchDestinations}=require('../services/searchService');
test('Photon fallback preserves named places, coordinates and unknown accessibility',async()=>{
 const original=global.fetch;let calls=0;
 global.fetch=async uri=>{calls++;assert.equal(uri.host,'photon.example.test');assert.equal(uri.searchParams.get('q'),'School named landmark');return {ok:true,json:async()=>({features:[{geometry:{type:'Point',coordinates:[2,1]},properties:{osm_id:42,osm_type:'N',name:'School named landmark',city:'Synthetic city',osm_value:'school'}},{geometry:{type:'Point',coordinates:[null,null]},properties:{name:'Invalid'}}]})};};
 try{const rows=await searchDestinations({query:'School named landmark',latitude:1,longitude:2});assert.equal(rows.length,1);assert.equal(rows[0].name,'School named landmark');assert.equal(rows[0].latitude,1);assert.equal(rows[0].longitude,2);assert.equal(rows[0].isAccessible,false);assert.equal(calls,1);}finally{global.fetch=original;}
});
