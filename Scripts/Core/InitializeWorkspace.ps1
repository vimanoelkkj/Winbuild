# ==========================================================
# Windows Mod - Initialize Workspace
# ==========================================================

$Root = "C:\Windows-Mod"

$Folders = @(
    "Config",
    "Autounattend",
    "Extract",
    "ISO",
    "Installers",
    "Installers\AMD-Chipset",
    "Installers\Firefox",
    "Installers\NVIDIA",
    "Installers\Spotify",
    "Installers\Steam",
    "Installers\Vesktop",
    "Installers\WinRAR",
    "Logs",
    "Mount",
    "Output",
    "Resources",
    "Resources\Registry",
    "Resources\Wallpapers",
    "Scripts",
    "Scripts\Core",
    "Scripts\PostInstall",
    "Scripts\Utils",
    "Temp"
)

$GitKeepFolders = @(
    "Autounattend",
    "Extract",
    "ISO",
    "Installers",
    "Installers\AMD-Chipset",
    "Installers\Firefox",
    "Installers\NVIDIA",
    "Installers\Spotify",
    "Installers\Steam",
    "Installers\Vesktop",
    "Installers\WinRAR",
    "Logs",
    "Mount",
    "Output",
    "Temp"
)

Write-Host ""
Write-Host "====================================="
Write-Host "   Windows Mod - Initialize Workspace"
Write-Host "====================================="
Write-Host ""

foreach ($Folder in $Folders) {
    $Path = Join-Path $Root $Folder

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "[OK] Criado: $Folder"
    }
    else {
        Write-Host "[EXISTE] $Folder"
    }
}

Write-Host ""
Write-Host "Criando .gitkeep..."
Write-Host ""

foreach ($Folder in $GitKeepFolders) {
    $GitKeep = Join-Path $Root "$Folder\.gitkeep"

    if (!(Test-Path $GitKeep)) {
        New-Item -ItemType File -Path $GitKeep -Force | Out-Null
        Write-Host "[OK] $Folder\.gitkeep"
    }
    else {
        Write-Host "[EXISTE] $Folder\.gitkeep"
    }
}

Write-Host ""
Write-Host "Workspace pronto em: $Root"
Write-Host ""