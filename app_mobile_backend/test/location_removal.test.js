'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createLocationRemoval}=require('../services/locationRemoval');
test('account removal blocks Firebase first, erases SQL coordinates and retires active credentials',async()=>{
  const calls=[];
  const db={query:async sql=>{calls.push(sql);return {rows:sql.includes('FROM users')?[{user_id:'synthetic-user'}]:[]};},release:()=>calls.push('release')};
  const pool={query:async()=>({rows:[{id:'synthetic-user'}]}),connect:async()=>db};
  const remove=createLocationRemoval(pool,()=> 'users',{removeAccount:async()=>calls.push('firebase-block-and-remove')});
  await remove('synthetic-nav');
  assert.ok(calls.indexOf('firebase-block-and-remove')>calls.findIndex(sql=>sql.includes('FOR UPDATE OF d')));
  assert.ok(calls.indexOf('firebase-block-and-remove')<calls.findIndex(sql=>sql.includes('UPDATE akay_device_credentials')));
  assert.ok(calls.some(sql=>sql.includes('FOR UPDATE OF d')));
  assert.ok(calls.some(sql=>sql.includes('UPDATE akay_device_credentials')));
  assert.ok(calls.some(sql=>sql.includes('UPDATE akay_readings SET latitude=NULL,longitude=NULL')));
  assert.ok(calls.some(sql=>sql.includes('originaddress=NULL')));
  assert.equal(calls.at(-2),'COMMIT');assert.equal(calls.at(-1),'release');
  assert.ok(!calls.some(sql=>sql.includes('DELETE FROM akay_alerts')));
});
