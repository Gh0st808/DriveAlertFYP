param([switch]$BuildApk)
$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot
try {
    $python = Join-Path $PSScriptRoot "backend\.venv\Scripts\python.exe"
    if (!(Test-Path -LiteralPath $python)) {
        $python = Join-Path $PSScriptRoot "backend\venv\Scripts\python.exe"
    }
    if (!(Test-Path -LiteralPath $python)) {
        throw "Use the existing repaired folder with its backend virtual environment, or set up its Python dependencies first."
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
    Write-Host "Checks passed. Complete the phone and Pi acceptance checks in REPAIR_NOTES_2026-10-18.md."
} finally { Pop-Location }
