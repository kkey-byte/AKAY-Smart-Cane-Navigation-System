$ErrorActionPreference = 'Stop'
$patchRoot = $PSScriptRoot
$backendRoot = [IO.Path]::GetFullPath('C:\Users\Asus\app_mobile_backend')
if (-not (Test-Path -LiteralPath (Join-Path $backendRoot 'server.js'))) { throw 'Expected AKAY backend not found.' }
$files = @('server.js','package.json','package-lock.json','routes/auth.js','routes/search.js','routes/routing.js','services/searchService.js','routes/profile.js','routes/navigation.js','routes/pairing.js','middleware/identity.js','services/firebaseAdmin.js','services/pairingService.js','services/accountPairingService.js','services/dashboardService.js','database/db.js','database/migrations/001_pairing.sql','scripts/migratePairing.js','scripts/provisionCane.js','scripts/rearmCane.js','test/security.test.js','test/api_audit.test.js','test/schema_startup.test.js','database/schemaCatalog.js','database/ensureUsersTable.js','database/ensurePatientProfilesTable.js','database/create_patient_profiles.sql','database/ensurePlacesTable.js','middleware/validateProfile.js','database/migrations/002_integrity.sql','database/migrations/003_runtime_role.sql','database/migrations/004_accessible_pairing.sql','database/migrations/005_pairings.sql','database/dateTypes.js','services/httpPolicy.js','test/auth_startup.test.js')
$backupRoot = Join-Path $patchRoot ('original_backup/' + (Get-Date -Format 'yyyyMMddHHmmss'))
foreach ($file in $files) {
  $source = Join-Path $patchRoot $file
  $destination = [IO.Path]::GetFullPath((Join-Path $backendRoot $file))
  if (-not $destination.StartsWith($backendRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escaped the backend directory.' }
  if (-not (Test-Path -LiteralPath $source)) { throw "Missing prepared file: $file" }
  if (Test-Path -LiteralPath $destination) {
    $backup = Join-Path $backupRoot $file
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
    Copy-Item -LiteralPath $destination -Destination $backup
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}
Write-Output "Applied $($files.Count) reviewed source files. No database migration, server restart, or Firebase deployment was performed."





