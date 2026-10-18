$ErrorActionPreference = "Stop"
Set-Location -LiteralPath (Join-Path $PSScriptRoot "backend")
& ".\.venv\Scripts\python.exe" manage.py run_notifications

