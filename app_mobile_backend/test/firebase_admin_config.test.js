'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(file, env, rejectCertificate = false) {
  const apps = [], calls = [];
  const context = {
    process: {env}, module: {exports: {}},
    require(name) {
      if (name === 'firebase-admin/app') return {
        getApps: () => apps,
        initializeApp: options => {calls.push(options); apps.push({options});},
        applicationDefault: () => 'default-credential',
        cert: value => {
          if (rejectCertificate) throw new Error('sensitive credential details');
          return {certificate: value};
        },
      };
      if (name === 'firebase-admin/auth') return {getAuth: app => app};
      if (name === 'firebase-admin/database') return {getDatabase: app => app};
      throw new Error('Unexpected import');
    },
  };
  vm.runInNewContext(readFileSync(file, 'utf8'), context);
  return {api: context.module.exports, calls};
}

for (const file of [
  path.join(__dirname, '../services/firebaseAdmin.js'),
  path.join(__dirname, '../../backend_patch/services/firebaseAdmin.js'),
]) {
  test(`${path.relative(process.cwd(), file)} selects deployment JSON and reuses the app`, () => {
    const {api, calls} = load(file, {
      FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({project_id: 'synthetic-project'}),
      FIREBASE_DATABASE_URL: 'https://synthetic-project.invalid',
    });
    assert.equal(api.auth(), api.database());
    assert.equal(calls.length, 1);
    assert.equal(calls[0].credential.certificate.project_id, 'synthetic-project');
    assert.equal(calls[0].databaseURL, 'https://synthetic-project.invalid');
  });
  test(`${path.relative(process.cwd(), file)} retains application-default support`, () => {
    const {api, calls} = load(file, {});
    api.auth();
    assert.equal(calls[0].credential, 'default-credential');
  });
  for (const rejectCertificate of [false, true]) {
    test(`${path.relative(process.cwd(), file)} rejects invalid credentials without revealing values (${rejectCertificate})`, () => {
      const {api, calls} = load(file, {
        FIREBASE_SERVICE_ACCOUNT_JSON: rejectCertificate ? '{}' : 'private-invalid-json',
      }, rejectCertificate);
      assert.throws(() => api.auth(), error =>
        error.code === 'app/invalid-credential' &&
        !error.message.includes('private-invalid-json') &&
        !error.message.includes('sensitive credential details'));
      assert.equal(calls.length, 0);
    });
  }
}
