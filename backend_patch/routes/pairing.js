'use strict';
const express=require('express');
const pool=require('../database/db');
const {usersTable}=require('../database/ensureUsersTable');
const {verifyFirebase,requireProfile}=require('../middleware/identity');
const firebase=require('../services/firebaseAdmin');
const {createPairingService,ApiError}=require('../services/pairingService');
const service=createPairingService(pool,usersTable);
const accountPairings=require('../services/accountPairingService').createAccountPairingService(pool,usersTable);
const dashboard=require('../services/dashboardService').createDashboardService(pool,service.authorize,firebase);
const router=express.Router();
router.use((_req,res,next)=>{res.set('Cache-Control','no-store');next();});
const route=fn=>async(req,res,next)=>{try {res.json(await fn(req));} catch(error){next(error);}};
// Hardware endpoint is authenticated by a separately provisioned machine secret.
function machine(req) {
  const result=/^Device ([0-9a-f-]{36})\.([A-Za-z0-9_-]{43})$/i.exec(req.headers.authorization||'');
  if(!result) throw new ApiError(401,'device_auth_failed','Device credentials required.');
  return [result[1],result[2]];
}
router.post('/telemetry',route(req=>{const [id,key]=machine(req); return service.ingest(id,key,req.body||{});}));
router.get('/device-assignment',route(req=>{const [id,key]=machine(req); return service.hardware(id,key,async(_db,_d,_c,a)=>({assignmentId:a?.id??null}));}));
router.use(verifyFirebase,requireProfile);
router.post('/dashboard/presence',route(req=>dashboard.presence(req.actor,req.body?.active)));
router.get('/navigators/:uid/dashboard',route(req=>dashboard.snapshot(req.actor,req.params.uid)));
router.post('/pairings/codes',route(req=>accountPairings.generate(req.actor,req.body||{})));
router.post('/pairings/redeem',route(req=>accountPairings.redeem(req.actor,req.body||{},req.ip)));
router.get('/pairings',route(async req=>({pairings:await accountPairings.list(req.actor)})));
router.get('/connections',route(async req=>({connections:await service.connections(req.actor)})));
router.post('/invitations',route(req=>service.invite(req.actor)));
router.post('/invitations/redeem',route(req=>service.redeem(req.actor,req.body?.code,req.ip)));
router.post('/connections/:id/accept',route(req=>service.decide(req.actor,req.params.id,true)));
router.post('/connections/:id/reject',route(req=>service.decide(req.actor,req.params.id,false)));
router.delete('/connections/:id',route(req=>service.revoke(req.actor,req.params.id)));
router.get('/devices',route(async req=>({devices:await service.devices(req.actor)})));
router.post('/devices/claim',route(req=>service.claim(req.actor,req.body?.deviceId,req.body?.claimCode)));
router.post('/devices/:id/assign',route(req=>service.assign(req.actor,req.params.id)));
router.delete('/devices/:id/assignment',route(req=>service.release(req.actor,req.params.id,false)));
router.delete('/devices/:id/ownership',route(req=>service.release(req.actor,req.params.id,true)));
router.post('/devices/:id/transfer',route(req=>service.transfer(req.actor,req.params.id,req.body?.navigatorUid)));
router.post('/transfers/accept',route(req=>service.acceptTransfer(req.actor,req.body?.code)));
router.get('/navigators/:uid/snapshot',route(async req=>{
  const result=await service.snapshot(req.actor,req.params.uid);
  result.phoneLocation=null;
  try {
    const recent=await firebase.database().ref(`breadcrumb_trips/${req.params.uid}`).orderByChild('startedAt').limitToLast(1).get();
    const trip=Object.values(recent.val()||{})[0];
    const point=Object.values(trip?.points||{}).filter(p=>Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Math.abs(p.latitude)<=90&&Math.abs(p.longitude)<=180&&Number.isFinite(p.time)).sort((a,b)=>b.time-a.time)[0];
    if(point) result.phoneLocation={latitude:point.latitude,longitude:point.longitude,time:new Date(point.time).toISOString(),source:'phone_gps',fresh:trip.status==='recording'&&Date.now()-point.time>=-30000&&Date.now()-point.time<=45000};
  } catch(_) {result.phoneError='Phone GPS unavailable.';}
  await service.authorize(req.actor,req.params.uid);
  return result;
}));
router.get('/navigators/:uid/trips/:tripId',route(async req=>{
  await service.authorize(req.actor,req.params.uid);
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(req.params.tripId)) throw new ApiError(400,'invalid_trip','Invalid trip identifier.');
  const result=await firebase.database().ref(`breadcrumb_trips/${req.params.uid}/${req.params.tripId}`).get();
  await service.authorize(req.actor,req.params.uid);
  return {trip:result.val()};
}));
router.get('/navigators/:uid/trips',route(async req=>{
  await service.authorize(req.actor,req.params.uid);
  const requested=req.query.limit == null ? 100 : Number(req.query.limit);
  if(!Number.isFinite(requested) || !Number.isInteger(requested) || requested < 1) throw new ApiError(400,'invalid_limit','A positive integer limit is required.');
  const limit=Math.min(1000,Math.max(1,Math.floor(requested)));
  const snapshot=await firebase.database().ref(`breadcrumb_trips/${req.params.uid}`).orderByChild('startedAt').limitToLast(limit).get();
  await service.authorize(req.actor,req.params.uid);
  return {trips:snapshot.val()||{}};
}));
router.use((error,_req,res,_next)=>{
  if(error instanceof ApiError) return res.status(error.status).json({code:error.code,message:error.message});
  if(error.code==='23505') return res.status(409).json({code:'conflict',message:'A conflicting record already exists. Refresh and try again.'});
  return res.status(503).json({code:'service_unavailable',message:'Pairing service unavailable. Please try again.'});
});
module.exports=router;
