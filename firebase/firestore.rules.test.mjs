import {readFile} from 'node:fs/promises';
import {before,after,test} from 'node:test';
import {initializeTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,collection,getDocs} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-akay-breadcrumbs',firestore:{host:'127.0.0.1',port:8089,
  rules:await readFile(new URL('./firestore.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
test('history and archives require the consent-checked backend for every client role',async()=>{
  const paths=['navigators/navigator','navigators/navigator/trips/trip',
    'navigators/navigator/trips/trip/points/00000000','legacy_rtdb/breadcrumb_shares/records/navigator'];
  await env.withSecurityRulesDisabled(async c=>{
    for(const path of paths) await setDoc(doc(c.firestore(),path),{synthetic:true});
  });
  for(const uid of ['navigator','caregiver','stranger',null]) {
    const db=uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
    for(const path of paths) {
      await assertFails(getDoc(doc(db,path)));
      await assertFails(setDoc(doc(db,path),{forged:true}));
    }
    await assertFails(getDocs(collection(db,'navigators/navigator/trips')));
  }
});
