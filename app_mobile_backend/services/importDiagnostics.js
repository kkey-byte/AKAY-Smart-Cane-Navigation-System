'use strict';
// Only fixed labels leave this boundary. SDK messages can contain credentials,
// project identifiers, document paths or user data, so never print them raw.
function importDiagnostic(error) {
  const code=String(error?.code??'').toLowerCase();
  const known={
    '8':['quota_exhausted','Firestore quota is exhausted. Wait for quota availability before importing.'],
    'resource-exhausted':['quota_exhausted','Firestore quota is exhausted. Wait for quota availability before importing.'],
    '7':['permission_denied','Check the backend service account IAM access and that Cloud Firestore API is enabled.'],
    'permission-denied':['permission_denied','Check the backend service account IAM access and that Cloud Firestore API is enabled.'],
    '16':['unauthenticated','Configure valid server credentials for Firebase Admin.'],
    'app/invalid-credential':['invalid_server_credentials','Check FIREBASE_SERVICE_ACCOUNT_JSON or Application Default Credentials.'],
    'app/invalid-app-options':['invalid_server_configuration','Check Firebase server project configuration.'],
    '5':['source_not_found','Check the selected Firebase project and that its default Firestore database exists.'],
    '14':['service_unavailable','The source service is unavailable. Check connectivity and retry later.'],
    '4':['deadline_exceeded','The source request timed out. Check connectivity and retry later.'],
    'enoent':['credentials_file_missing','Check that the configured server credentials file exists.'],
    'enotfound':['network_unavailable','Check network access to the configured service.'],
    'econnrefused':['connection_refused','Check that the configured PostgreSQL/service endpoint is running.'],
    'econnreset':['connection_reset','The database connection was closed before the check completed. Verify DB_SSL=true, the full external hostname, Render database availability and external IP access settings.'],
    '42p01':['sql_table_missing','Apply migration 007_postgres_history to the intended PostgreSQL database.'],
    '42501':['sql_permission_denied','Grant the backend role access to the new history table.'],
    '28p01':['sql_authentication_failed','Check PostgreSQL server credentials privately.'],
    '3d000':['sql_database_missing','Check DB_NAME against the database name in Render.'],
    '28000':['sql_connection_rejected','Check the database user, DB_SSL=true, and Render external connection access settings.'],
    'etimedout':['network_timeout','Check internet access, firewall settings and Render external connection access settings.'],
    'eai_again':['dns_lookup_failed','DNS lookup failed temporarily. Check connectivity and the full external hostname.'],
    'err_tls_cert_altname_invalid':['tls_hostname_mismatch','Use the full Render external hostname, not an IP address or custom alias.'],
    'cert_has_expired':['tls_certificate_expired','Check the computer clock and server certificate validity.'],
    'self_signed_cert_in_chain':['tls_untrusted_certificate','A certificate chain is not trusted. Check antivirus/proxy TLS interception or configure the correct trusted CA; keep certificate verification enabled.'],
    'depth_zero_self_signed_cert':['tls_untrusted_certificate','Check the trusted CA configuration; keep certificate verification enabled.'],
    'unable_to_verify_leaf_signature':['tls_untrusted_certificate','Check the trusted CA configuration or TLS-intercepting proxy; keep certificate verification enabled.'],
  };
  if(known[code]) return {code:known[code][0],hint:known[code][1]};
  const message=String(error?.message??'');
  if(/server does not support ssl/i.test(message))
    return {code:'ssl_not_supported',hint:'The selected server does not support TLS. Verify that DB_HOST is the intended Render external hostname.'};
  if(/could not load the default credentials|default credentials were not found|unable to detect a project id/i.test(message))
    return {code:'server_credentials_missing',hint:'Configure Firebase Admin Application Default Credentials or FIREBASE_SERVICE_ACCOUNT_JSON. Mobile Firebase configuration does not provide server credentials.'};
  return {code:'unclassified_import_failure',hint:'Check source record validity and server configuration privately. Raw error details are suppressed.'};
}
module.exports={importDiagnostic};
