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
const health=require('../services/navigatorHealthService').createNavigatorHealthService(
  pool,service.authorize,usersTable,require('../database/ensurePatientProfilesTable').patientProfilesTable);
const trips=require('../services/tripStore').createTripStore(firebase);
const removeLocationAccount=require('../services/locationRemoval').createLocationRemoval(pool,usersTable,trips);
const caneGps=require('../services/caneGps').createCaneGps(service,pool,usersTable,trips,firebase);
const monitoring=require('../services/monitoringService').createMonitoringService(pool,firebase,trips);
const phoneLocation=require('../services/phoneLocation').createPhoneLocationService(pool,usersTable,firebase);
const emergencies=require('../services/emergencyService').createEmergencyService(pool,usersTable,firebase);
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
router.post('/gps',route(req=>{const [id,key]=machine(req); return caneGps(id,key,req.body||{});}));
router.get('/device-assignment',route(req=>{const [id,key]=machine(req); return service.hardware(id,key,async(_db,_d,_c,a)=>({assignmentId:a?.id??null}));}));
router.use(verifyFirebase,requireProfile);
const progress=require('../services/destinationProgress').createDestinationProgress(service.authorize,firebase,pool);
const destinations=require('../services/destinationAssignment').createDestinationAssignment(service.authorize,firebase,progress);
router.post('/navigators/:uid/destination',route(req=>destinations.send(req.actor,req.params.uid,req.body||{})));
router.get('/destination',route(req=>destinations.pending(req.actor)));
router.post('/destination/:id/acknowledge',route(req=>destinations.acknowledge(req.actor,req.params.id)));
router.post('/destination/:id/cancel',route(req=>progress.cancel(req.actor,req.params.id)));
router.get('/destination-notifications',route(req=>progress.list(req.actor)));
router.post('/destination-notifications/:id/respond',route(req=>progress.receipt(req.actor,req.params.id,req.body?.action)));
router.get('/alerts',route(req=>emergencies.list(req.actor)));
router.post('/alerts/:id/respond',route(req=>emergencies.respond(req.actor,req.params.id,req.body?.action)));
router.put('/push-token',route(req=>emergencies.token(req.actor,req.body?.token)));
router.delete('/push-token',route(req=>emergencies.token(req.actor,req.body?.token,true)));
router.put('/navigators/:uid/phone-location',route(async req=>{
  if(req.actor.uid!==req.params.uid) throw new ApiError(403,'source_not_owned','This phone source belongs to another account.');
  const result=await phoneLocation.publish(req.actor,req.body||{});
  if(result.applied) await progress.location(req.actor,req.body);
  return result;
}));
router.delete('/navigators/:uid/phone-location',route(req=>{
  if(req.actor.uid!==req.params.uid) throw new ApiError(403,'source_not_owned','This phone source belongs to another account.');
  return phoneLocation.clear(req.actor,req.body||{});
}));
router.post('/dashboard/presence',route(req=>dashboard.presence(req.actor,req.body?.active)));
router.get('/navigators/:uid/dashboard',route(req=>dashboard.snapshot(req.actor,req.params.uid)));
router.get('/navigators/:uid/health',route(req=>health.snapshot(req.actor,req.params.uid)));
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
  const live=await monitoring.read(result.navigator,{history:false});
  result.phoneLocation=live.phoneLocation;
  if(live.errors.length) result.phoneError='Live location is partially unavailable.';
  for(const device of result.devices) {
    const current=live.devices.find(d=>d.id===device.id&&d.assignment_id===device.assignment_id);
    if(current) Object.assign(device,{latitude:current.location.latitude,longitude:current.location.longitude,
      sampled_at:new Date(current.location.time).toISOString(),status:current.location.status??device.status});
  }
  await service.authorize(req.actor,req.params.uid);
  return result;
}));
router.get('/navigators/:uid/trips/:tripId',route(async req=>{
  await service.authorize(req.actor,req.params.uid);
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(req.params.tripId)) throw new ApiError(400,'invalid_trip','Invalid trip identifier.');
  const result=await trips.detail(req.params.uid,req.params.tripId);
  await service.authorize(req.actor,req.params.uid);
  return {trip:result};
}));
router.get('/navigators/:uid/trips',route(async req=>{
  await service.authorize(req.actor,req.params.uid);
  const requested=req.query.limit == null ? 100 : Number(req.query.limit);
  if(!Number.isFinite(requested) || !Number.isInteger(requested) || requested < 1) throw new ApiError(400,'invalid_limit','A positive integer limit is required.');
  const limit=Math.min(1000,Math.max(1,Math.floor(requested)));
  const result=await trips.list(req.params.uid,{limit,cursor:req.query.cursor});
  await service.authorize(req.actor,req.params.uid);
  return result;
}));
function owner(req) {
  if(req.actor.role!=='visually_impaired'||req.actor.uid!==req.params.uid)
    throw new ApiError(403,'owner_required','Only the navigator can modify history.');
}
router.put('/navigators/:uid/trips/:tripId/points',route(async req=>{
  owner(req); await service.authorize(req.actor,req.params.uid);
  return trips.phoneBatch(req.params.uid,req.params.tripId,req.body||{});
}));
router.put('/navigators/:uid/trips/:tripId/summary',route(async req=>{
  owner(req); await service.authorize(req.actor,req.params.uid);
  return trips.finalizePhone(req.params.uid,req.params.tripId,req.body||{});
}));
router.delete('/navigators/:uid/trips/:tripId',route(async req=>{
  owner(req); await service.authorize(req.actor,req.params.uid);
  return trips.remove(req.params.uid,req.params.tripId);
}));
router.delete('/navigators/:uid/location-history',route(async req=>{
  owner(req); await service.authorize(req.actor,req.params.uid);
  return removeLocationAccount(req.params.uid);
}));
router.use((error,_req,res,_next)=>{
  if(error instanceof ApiError) return res.status(error.status).json({code:error.code,message:error.message});
  if(error.code==='23505') return res.status(409).json({code:'conflict',message:'A conflicting record already exists. Refresh and try again.'});
  return res.status(503).json({code:'service_unavailable',message:'Pairing service unavailable. Please try again.'});
});
module.exports=router;
