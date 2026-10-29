'use strict';
const router=require('express').Router();
const {verifyFirebase,requireProfile}=require('../middleware/identity');
const controller=require('../controllers/patientHealthStatus');
router.use(verifyFirebase,requireProfile);
router.use((_req,res,next)=>{res.set('Cache-Control','no-store');next();});
router.get('/',controller.get);
router.put('/',controller.put);
module.exports=router;
