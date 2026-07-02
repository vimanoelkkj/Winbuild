. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Configurando PostInstall..."

$OEMRoot = Join-Path $ExtractPath "sources"
$OEMRoot = Join-Path $OEMRoot '$OEM$'
$TargetRoot = Join-Path $OEMRoot '$1\Windows-Mod'

$TargetInstallers = Join-Path $TargetRoot "Installers"
$TargetPostInstall = Join-Path $TargetRoot "PostInstall"

New-Item -ItemType Directory -Force -Path $TargetInstallers | Out-Null
New-Item -ItemType Directory -Force -Path $TargetPostInstall | Out-Null

Copy-Item -Path "$InstallersPath\*" -Destination $TargetInstallers -Recurse -Force
Copy-Item -Path "$RootPath\Scripts\PostInstall\*" -Destination $TargetPostInstall -Recurse -Force

$ScriptsDir = Join-Path $OEMRoot '$$\Setup\Scripts'
New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null

@"
@echo off
powershell.exe -ExecutionPolicy Bypass -File C:\Windows-Mod\PostInstall\InstallDrivers.ps1
"@ | Set-Content (Join-Path $ScriptsDir "SetupComplete.cmd") -Encoding ASCII

Write-Log "PostInstall configurado." "SUCCESS"