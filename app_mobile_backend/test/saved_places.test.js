'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
process.env.NOMINATIM_BASE_URL='https://geocoder.example.test';
const db=require.resolve('../database/db');
require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async()=>({rows:[
 {id:'42',name:'Saved destination',category:'Park',address:'Synthetic',latitude:'1.002',longitude:'2.002',distance_m:'300'},
 {id:'43',name:'Missing coordinate',latitude:null,longitude:'2',distance_m:null},
 {id:'44',name:'Out of range',latitude:'100',longitude:'2',distance_m:'100'}
]})}};
const {searchDestinations}=require('../services/searchService');
test('database places retain numeric-string coordinates; incomplete places are rejected',async()=>{
 const original=global.fetch;global.fetch=async()=>({ok:true,json:async()=>[]});
 try {const results=await searchDestinations({query:'Saved',latitude:1,longitude:2});
 assert.equal(results.length,1);assert.equal(results[0].id,'akay_42');assert.equal(results[0].latitude,1.002);assert.equal(results[0].longitude,2.002);assert.equal(results[0].source,'AKAY');
 }finally{global.fetch=original;}
});
