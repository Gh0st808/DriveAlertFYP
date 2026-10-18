$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
if (-not (Test-Path -LiteralPath "backend\.env")) {
    python configure.py
    if ($LASTEXITCODE -ne 0) { throw "Configuration failed." }
}
Set-Location -LiteralPath (Join-Path $PSScriptRoot "backend")
if (-not (Test-Path -LiteralPath ".venv\Scripts\python.exe")) {
    python -m venv .venv
}
& ".\.venv\Scripts\python.exe" -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed." }
& ".\.venv\Scripts\python.exe" manage.py check
if ($LASTEXITCODE -ne 0) { throw "Backend checks failed." }
& ".\.venv\Scripts\python.exe" manage.py migrate
if ($LASTEXITCODE -ne 0) { throw "Migrations failed. Preserve the database and inspect the error; do not fake or reset migrations." }
Write-Output "Backend ready. Run start_backend.ps1 next."

