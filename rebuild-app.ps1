#!/usr/bin/env pwsh
# Rebuild and test the SafetySafar app

Write-Host "Building SafetySafar app with fixed backend..." -ForegroundColor Cyan

$appDir = "d:\SafetySafar_majorProject\safety_safar_app"
Set-Location $appDir

Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Green
Write-Host "Running flutter run..." -ForegroundColor Yellow

& flutter run -v
