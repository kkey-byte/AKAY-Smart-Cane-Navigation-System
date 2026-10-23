'use strict';

const {
    getApps,
    initializeApp,
    applicationDefault,
    cert,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');
const { getDatabase } = require('firebase-admin/database');

function app() {
    if (!getApps().length) {
        const serviceAccountJson =
            process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

        initializeApp({
            credential: serviceAccountJson
                ? cert(JSON.parse(serviceAccountJson))
                : applicationDefault(),
            databaseURL: process.env.FIREBASE_DATABASE_URL,
        });
    }

    return getApps()[0];
}

module.exports = {
    auth: () => getAuth(app()),
    database: () => getDatabase(app()),
};