'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createPairingService}=require('../services/pairingService');

test('connection photos use the existing actor-scoped read-only query', async()=>{
  const rows=[{caregiver_picture:'https://example.invalid/avatar.jpg'}];
  const pool={async query(sql,args){
    assert.match(sql,/^SELECT/);
    assert.match(sql,/g\.profile_picture AS caregiver_picture/);
    assert.match(sql,/WHERE c\.navigator_id=\$1 OR c\.caregiver_id=\$1/);
    assert.deepEqual(args,['signed-in-account']);
    return {rows};
  }};
  const service=createPairingService(pool,()=> 'users');
  assert.deepEqual(await service.connections({id:'signed-in-account'}),rows);
});
