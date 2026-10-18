$ErrorActionPreference = "Stop"
Set-Location -LiteralPath (Join-Path $PSScriptRoot "backend")
& ".\.venv\Scripts\python.exe" manage.py runserver 0.0.0.0:8000

