'use strict';
const fields = ['height','weight','medical_conditions','allergies','emergency_contact_phone'];
function validate(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('A health status object is required.');
  if (Object.keys(body).some(key => !fields.includes(key))) throw new Error('Unsupported health status field.');
  for (const [key,value] of Object.entries(body)) {
    if (value === null) continue;
    if (key === 'height' || key === 'weight') {
      if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0 || value >= 1000 || Math.abs(value*100-Math.round(value*100)) > 0.000001) throw new Error('Measurements must be positive numbers below 1000 with at most two decimals.');
    } else if (typeof value !== 'string' || value.length > (key === 'emergency_contact_phone' ? 40 : 10000)) {
      throw new Error('Invalid health status text.');
    }
  }
  return body;
}
const projection = 'medication_id, patient_id, height, weight, medical_conditions, allergies, emergency_contact_phone';
function map(row) {
  return row ? {...row, height: row.height == null ? null : Number(row.height), weight: row.weight == null ? null : Number(row.weight)} : null;
}
async function fetch(db, patientId) {
  return map((await db.query(`SELECT ${projection} FROM public.patientmedication WHERE patient_id=$1 AND health_status_record`, [patientId])).rows[0]);
}
async function save(db, patientId, patch) {
  const previous = await fetch(db, patientId) || {};
  const values = fields.map(key => Object.hasOwn(patch,key) ? patch[key] : previous[key] ?? null);
  return map((await db.query(`INSERT INTO public.patientmedication
    (medication_id,patient_id,health_status_record,${fields.join(',')})
    VALUES(gen_random_uuid(),$1,true,$2,$3,$4,$5,$6)
    ON CONFLICT(patient_id) WHERE health_status_record DO UPDATE SET
    ${fields.map(key => `${key}=EXCLUDED.${key}`).join(',')}
    RETURNING ${projection}`, [patientId,...values])).rows[0]);
}
module.exports = {validate,fetch,save};
