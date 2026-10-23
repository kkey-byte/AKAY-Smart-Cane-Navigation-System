'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
process.env.NOMINATIM_BASE_URL='';
process.env.PHOTON_BASE_URL='https://photon.example.test';
const db=require.resolve('../database/db');let savedRows=[],sqlCalls=[];
require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async(sql,params)=>{sqlCalls.push({sql,params});return {rows:savedRows};}}};
const {resolveSearchIntent,searchDestinations}=require('../services/searchService');

for(const [query,key] of [
 ['mall','mall'],['nearby malls','mall'],['the mall','mall'],['malls near me','mall'],
 ['shopping centres','mall'],['nearest malls','mall'],['groceries near me','supermarket'],['find nearby restaurants','restaurant'],['hospitals around me','hospital'],
 ['pharmacies nearby','pharmacy'],['show me nearby ATMs','atm'],['nearby bus stations','bus terminal'],
]) test(`normalizes category request: ${query}`,()=>assert.equal(resolveSearchIntent(query).key,key));

test('named and arbitrary keywords retain text instead of becoming a category',()=>{
 for(const query of ['SM Mall of Asia','Small Garden','Bank of Islands','Elementary','Rizal Park']) {
  assert.deepEqual(resolveSearchIntent(query),{text:query,category:null,key:null});
 }
 assert.equal(resolveSearchIntent('nearby Central Plaza').text,'Central Plaza');
});
const feature=(id,name,lon,lat)=>({geometry:{type:'Point',coordinates:[lon,lat]},properties:{osm_id:id,osm_type:'W',name,osm_value:'mall'}});

test('mall and nearby malls list nearby category matches plus saved malls without repeated provider calls',async()=>{
 const original=global.fetch;let calls=0;sqlCalls=[];
 savedRows=[{id:'42',name:'Saved Shopping Centre',category:'Shopping Centre',address:'Synthetic',latitude:'1.003',longitude:'2.003',distance_m:'470'}];
 global.fetch=async uri=>{
  calls++;assert.equal(uri.pathname,'/reverse');assert.equal(uri.searchParams.get('osm_tag'),'shop:mall');
  assert.equal(uri.searchParams.has('q'),false);assert.equal(uri.searchParams.get('lat'),'1');assert.equal(uri.searchParams.get('lon'),'2');
  assert.equal(Number(uri.searchParams.get('radius')),6.75);assert.equal(uri.searchParams.has('viewbox'),false);
  return {ok:true,json:async()=>({features:[feature(1,'Nearby Atrium',2.001,1.001),feature(2,'Nearby City Centre',2.002,1.002),feature(3,'Far Away Mall',20,10)]})};
 };
 try {
  const first=await searchDestinations({query:'mall',latitude:1,longitude:2});
  const second=await searchDestinations({query:'nearby malls',latitude:1,longitude:2});
  assert.deepEqual(new Set(first.map(p=>p.name)),new Set(['Nearby Atrium','Nearby City Centre','Saved Shopping Centre']));
  assert.equal(first[0].name,'Nearby Atrium');
  assert.deepEqual(second,first);assert.equal(calls,1);assert.equal(sqlCalls.length,2);
  for(const {sql,params} of sqlCalls) {
   assert.match(sql,/LIKE ANY\(\$1::text\[\]\)/);assert.ok(params[0].includes('%mall%'));assert.ok(params[0].includes('%shopping centre%'));
   assert.ok(!params[0].includes('%nearby malls%'));
  }
 } finally {global.fetch=original;savedRows=[];}
});

test('named query uses forward search with a real nearby bounding box and keeps valid coordinates',async()=>{
 const original=global.fetch;
 global.fetch=async uri=>{
  assert.equal(uri.pathname,'/api/');assert.equal(uri.searchParams.get('q'),'SM Mall of Asia');assert.equal(uri.searchParams.has('osm_tag'),false);
  assert.equal(uri.searchParams.has('viewbox'),false);assert.equal(uri.searchParams.has('format'),false);
  const [left,bottom,right,top]=uri.searchParams.get('bbox').split(',').map(Number);
  assert.ok(left<2 && right>2 && bottom<1 && top>1);
  return {ok:true,json:async()=>({features:[feature(99,'SM Mall of Asia',2.001,1.001)]})};
 };
 try {const rows=await searchDestinations({query:'SM Mall of Asia',latitude:1,longitude:2});assert.equal(rows[0].name,'SM Mall of Asia');assert.equal(rows[0].longitude,2.001);}
 finally{global.fetch=original;}
});

test('a genuine zero-result keyword stays empty; outage stays an error',async()=>{
 const original=global.fetch;let failed=false;
 global.fetch=async()=>{if(failed) throw new Error('Synthetic outage');return {ok:true,json:async()=>({features:[]})};};
 try {
  assert.deepEqual(await searchDestinations({query:'no-such-keyword',latitude:1,longitude:2}),[]);
  failed=true;await assert.rejects(searchDestinations({query:'different-keyword',latitude:1,longitude:2}),e=>e.status===503);
 }finally{global.fetch=original;}
});
