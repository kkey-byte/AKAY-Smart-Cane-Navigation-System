'use strict';
const { getApps, initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getDatabase } = require('firebase-admin/database');
function app() {
  if (!getApps().length) {
    const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
    let credential;
    if (json) {
      try {
        credential = cert(JSON.parse(json));
      } catch (_) {
        // Never include a credential value or the JSON parser's excerpt.
        const error = new Error('Firebase server credentials are invalid. Check the private deployment variable.');
        error.code = 'app/invalid-credential';
        throw error;
      }
    } else {
      credential = applicationDefault();
    }
    initializeApp({credential, databaseURL: process.env.FIREBASE_DATABASE_URL});
  }
  return getApps()[0];
}
module.exports = {auth: () => getAuth(app()), database: () => getDatabase(app())};
