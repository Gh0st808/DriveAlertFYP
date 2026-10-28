param([switch]$BuildApk)
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot
try {
    $python = Join-Path $PSScriptRoot "backend\.venv\Scripts\python.exe"
    if (!(Test-Path -LiteralPath $python)) {
        $python = Join-Path $PSScriptRoot "backend\venv\Scripts\python.exe"
    }
    if (!(Test-Path -LiteralPath $python)) {
        throw "Set up the backend virtual environment and install its dependencies before running validation."
    }
    Push-Location "backend"
    try {
        & $python manage.py test --settings=config.test_settings
        if ($LASTEXITCODE -ne 0) { throw "Backend tests failed." }
        & $python manage.py makemigrations --check --dry-run --settings=config.test_settings
        if ($LASTEXITCODE -ne 0) { throw "Migration consistency check failed." }
    } finally { Pop-Location }
    Push-Location "DriveAlert App"
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "Flutter dependency resolution failed." }
        flutter analyze
        if ($LASTEXITCODE -ne 0) { throw "Flutter analysis failed." }
        flutter test
        if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed." }
        if ($BuildApk) {
            flutter build apk --debug
            if ($LASTEXITCODE -ne 0) { throw "Android build failed." }
        }
    } finally { Pop-Location }
    Write-Host "Checks passed. Complete the phone and Pi acceptance checks in docs/testing/VALIDATION.md."
} finally { Pop-Location }
