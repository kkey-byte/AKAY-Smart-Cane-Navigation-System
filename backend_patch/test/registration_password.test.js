'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {scryptSync}=require('node:crypto');
const express=require('express');
let queries=[],fail=false;
const profile={user_id:'synthetic-account',firebase_uid:'synthetic-user',email:'synthetic@example.test',role:'caregiver'};
function stub(path,exports) {
  const id=require.resolve(path);
  require.cache[id]={id,filename:id,loaded:true,exports};
}
stub('../database/db',{query:async(sql,values)=>{
  queries.push({sql,values});
  if(fail) throw new Error('Synthetic database failure');
  return {rows:[profile]};
}});
stub('../database/ensureUsersTable',{usersTable:()=> 'users'});
stub('../middleware/identity',{verifyFirebase:(req,_res,next)=>{
  req.firebase={uid:profile.firebase_uid,email:profile.email};next();
}});
const app=express();app.use(express.json());app.use('/auth',require('../routes/auth'));

test('registration validates passwords, stores salted hashes, and excludes hashes from responses',async()=>{
  const server=app.listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  const request=body=>fetch(`http://127.0.0.1:${server.address().port}/auth/register`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),
  });
  try {
    for(const password of [undefined,null,'','short',123,{},'x'.repeat(4097)]) {
      assert.equal((await request({role:'caregiver',password})).status,400);
    }
    assert.equal(queries.length,0);
    const password='  synthetic-password 🦯  ';
    const hashes=[];
    for(const role of ['caregiver','visually_impaired']) {
      const response=await request({role,password});
      assert.equal(response.status,200);
      assert.deepEqual(await response.json(),{user:profile});
      const {sql,values}=queries.at(-1);
      assert.match(sql,/profile_picture,password\)/);
      assert.doesNotMatch(sql,/RETURNING[^]*\bpassword\b/);
      assert.equal(values.includes(password),false);
      const stored=values[6];hashes.push(stored);
      assert.ok(stored.length<=255);
      const [algorithm,n,r,p,salt,key]=stored.split('$');
      assert.equal(algorithm,'scrypt');
      assert.equal(salt.length,32);
      assert.equal(scryptSync(password,salt,64,{N:+n,r:+r,p:+p,maxmem:256*1024*1024}).toString('hex'),key);
      // Retrying registration cannot replace an existing account's password.
      assert.match(sql,/ON CONFLICT\(firebase_uid\) DO NOTHING/);
    }
    assert.notEqual(hashes[0],hashes[1]);
    fail=true;
    const response=await request({role:'caregiver',password});
    assert.equal(response.status,503);
    assert.deepEqual(await response.json(),{message:'Registration unavailable.'});
  } finally {await new Promise(resolve=>server.close(resolve));}
});
