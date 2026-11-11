'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {importDiagnostic}=require('../services/importDiagnostics');
test('quota, SQL migration and missing server credentials have actionable safe labels',()=>{
  assert.equal(importDiagnostic({code:8}).code,'quota_exhausted');
  assert.equal(importDiagnostic({code:'42P01'}).code,'sql_table_missing');
  assert.equal(importDiagnostic({message:'Could not load the default credentials.'}).code,'server_credentials_missing');
  assert.equal(importDiagnostic({code:'28P01'}).code,'sql_authentication_failed');
  assert.equal(importDiagnostic({code:'SELF_SIGNED_CERT_IN_CHAIN'}).code,'tls_untrusted_certificate');
  assert.equal(importDiagnostic({code:'ERR_TLS_CERT_ALTNAME_INVALID'}).code,'tls_hostname_mismatch');
});
test('private codes and raw SDK errors never appear in diagnostics',()=>{
  for(const code of ['private-token',7,'app/invalid-credential',undefined]) {
    const result=JSON.stringify(importDiagnostic({code,message:'private-token /private/location/path secret-credential'}));
    assert.equal(result.includes('private-token'),false);
    assert.equal(result.includes('/private/location/path'),false);
    assert.equal(result.includes('secret-credential'),false);
  }
});
