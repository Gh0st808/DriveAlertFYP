param([string]$BackendUrl = "http://10.13.1.97:8000/api", [string]$Device = "")
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath (Join-Path $PSScriptRoot "DriveAlert App")
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Flutter dependency resolution failed." }
if ($Device) { flutter run -d $Device --dart-define="API_BASE_URL=$BackendUrl" }
else { flutter run --dart-define="API_BASE_URL=$BackendUrl" }

