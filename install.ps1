#!/usr/bin/env pwsh
# One-liner installer for Windows — see README.md.
# Usage:  irm https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "antigravity-lowend\bin"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$ScriptUrl  = "https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/antigravity-optimizer.ps1"
$ScriptPath = Join-Path $InstallDir "antigravity-optimizer.ps1"

Write-Host "Downloading antigravity-optimizer.ps1..."
Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing

# .cmd shim so "antigravity-optimizer" works from cmd.exe and PowerShell alike
$ShimPath = Join-Path $InstallDir "antigravity-optimizer.cmd"
@
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$ScriptPath" %*
"@ | Set-Content -Path $ShimPath -Encoding ASCII

# Add install dir to the user PATH if it isn't already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
    Write-Host "Added $InstallDir to your user PATH."
    Write-Host "Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "$InstallDir is already on your PATH."
}

Write-Host ""
Write-Host "Installed. Run: antigravity-lowend"