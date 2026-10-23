const express = require('express');
const router = express.Router();
let busy = false, lastRequest = 0;
const base = process.env.OSRM_FOOT_BASE_URL || 'https://routing.openstreetmap.de/routed-foot';
router.get('/walk', async (req,res) => {
  res.set('Cache-Control','no-store');
  const value = req.query.coordinates;
  const number = '-?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?';
  const format = new RegExp(`^${number},${number};${number},${number}$`);
  const pairs = typeof value === 'string' ? value.split(';').map(p=>p.split(',').map(Number)) : [];
  if (pairs.length !== 2 || pairs.some(p=>p.length!==2 || p.some(v=>!Number.isFinite(v)) || Math.abs(p[0])>180 || Math.abs(p[1])>90) || typeof value !== 'string' || !format.test(value)) return res.status(400).json({message:'Valid origin and destination required.'});
  if (busy || Date.now()-lastRequest<1100) return res.status(429).json({message:'Route service busy. Try again shortly.'});
  busy = true; lastRequest = Date.now();
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(),12000);
  try {
    const url = new URL(`${base.replace(/\/+$/, '')}/route/v1/foot/${value}`);
    if(url.protocol!=='https:' || url.username || url.password) throw new Error('Invalid provider configuration');
    url.search = new URLSearchParams({overview:'full',geometries:'geojson',steps:'true'}).toString();
    const response = await fetch(url,{signal:controller.signal,headers:{Accept:'application/json','User-Agent':'AKAY-GABAY/1.0 (accessibility-navigation-app)'}});
    if(!response.ok) throw new Error('Upstream unavailable');
    const data = await response.json();
    if(data.code!=='Ok' || !Array.isArray(data.routes) || !data.routes.length) return res.status(422).json({message:'No walking route found for this destination.'});
    return res.json(data);
  } catch (_) { return res.status(503).json({message:'Walking directions unavailable. Try again.'}); }
  finally {clearTimeout(timer);busy=false;}
});
module.exports = router;
