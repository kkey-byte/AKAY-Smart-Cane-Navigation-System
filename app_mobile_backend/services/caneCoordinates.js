'use strict';
// Firmware coordinates are independent of battery and alert availability.
function caneCoordinates(raw) {
  if(!raw || typeof raw!=='object' || Array.isArray(raw)) return null;
  const {latitude,longitude}=raw;
  if(typeof latitude!=='number'||typeof longitude!=='number'||
    !Number.isFinite(latitude)||!Number.isFinite(longitude)||
    Math.abs(latitude)>90||Math.abs(longitude)>180) return null;
  return {latitude,longitude};
}
module.exports={caneCoordinates};
