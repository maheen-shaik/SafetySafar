#!/usr/bin/env pwsh
# SafetySafar App Build & Run Script

$appDir = "d:\SafetySafar_majorProject\safety_safar_app"
Set-Location $appDir

Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host "Building Flutter app..." -ForegroundColor Yellow

# Run Flutter
& flutter run -v
