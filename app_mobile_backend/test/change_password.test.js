'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {scryptSync}=require('node:crypto');
const express=require('express');
const createHandler=require('../services/changePassword');

test('password change requires recent password authentication and updates only its owner',async()=>{
  let queries=[],updates=[],failure,missing=false,mode='recent',released=0;
  const db={query:async(sql,values)=>{
    queries.push({sql,values});
    if(failure==='db' && sql.startsWith('UPDATE')) throw new Error('synthetic');
    if(failure==='commit' && sql==='COMMIT') throw new Error('synthetic');
    return {rows:missing?[]:[{user_id:'synthetic-owner'}]};
  },release:()=>released++};
  const app=express();app.use(express.json());
  app.use((req,res,next)=>{
    if(mode==='unauthenticated') return res.sendStatus(401);
    req.firebase={uid:'synthetic-owner',auth_time:mode==='stale'?1:1000,firebase:{sign_in_provider:mode==='provider'?'google.com':'password'}};next();
  });
  app.post('/change-password',createHandler({pool:{connect:async()=>db},usersTable:()=> 'users',clock:()=>1000000,
    firebase:{auth:()=>({updateUser:async(uid,body)=>{
      updates.push({uid,body});if(failure==='firebase') throw new Error('synthetic');
    }})},
  }));
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  const password='Synthetic!1';
  const request=body=>fetch(`http://127.0.0.1:${server.address().port}/change-password`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  try {
    for(mode of ['unauthenticated','stale','provider']) assert.equal((await request({password})).status,401);
    mode='recent';
    for(const invalid of [null,123,'short','lowercase!','Uppercaseonly','x'.repeat(4097)]) assert.equal((await request({password:invalid})).status,400);
    assert.equal(queries.length,0);
    const response=await request({password,firebase_uid:'another-user'});
    assert.equal(response.status,200);
    assert.deepEqual(await response.json(),{message:'Password updated successfully.'});
    assert.deepEqual(updates,[{uid:'synthetic-owner',body:{password}}]);
    const update=queries.find(q=>q.sql.startsWith('UPDATE'));
    assert.match(update.sql,/WHERE firebase_uid=\$2 RETURNING user_id/);
    assert.equal(update.values[1],'synthetic-owner');
    const [algorithm,n,r,p,salt,key]=update.values[0].split('$');
    assert.equal(algorithm,'scrypt');
    assert.equal(scryptSync(password,salt,64,{N:+n,r:+r,p:+p,maxmem:256*1024*1024}).toString('hex'),key);
    assert.equal(queries.at(-1).sql,'COMMIT');
    missing=true;queries=[];updates=[];
    assert.equal((await request({password})).status,404);
    assert.equal(updates.length,0);assert.equal(queries.at(-1).sql,'ROLLBACK');
    missing=false;
    for(failure of ['db','firebase','commit']) {
      queries=[];updates=[];
      const failed=await request({password});assert.equal(failed.status,503);
      assert.equal((await failed.json()).code,failure==='db'?'password_update_failed':'password_update_uncertain');
      assert.equal(queries.at(-1).sql,'ROLLBACK');
      if(failure==='db') assert.equal(updates.length,0);
    }
    assert.equal(released,5);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
