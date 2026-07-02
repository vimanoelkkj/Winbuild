# ==========================================================
# Windows Mod - Initialize
# ==========================================================

$ConfigPath = "C:\Windows-Mod\Config\BuildConfig.json"

if (!(Test-Path $ConfigPath)) {
    Write-Host ""
    Write-Host "ERRO: BuildConfig.json não encontrado." -ForegroundColor Red
    exit 1
}

$Global:Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# ----------------------------------------------------------
# Caminhos
# ----------------------------------------------------------

$Global:RootPath       = $Config.Paths.Root
$Global:ISOPath        = $Config.Paths.ISO
$Global:ExtractPath    = $Config.Paths.Extract
$Global:MountPath      = $Config.Paths.Mount
$Global:OutputPath     = $Config.Paths.Output
$Global:LogsPath       = $Config.Paths.Logs
$Global:InstallersPath = $Config.Paths.Installers

# ----------------------------------------------------------
# Windows
# ----------------------------------------------------------

$Global:Edition = $Config.Windows.Edition
$Global:Index   = $Config.Windows.Index

# ----------------------------------------------------------
# Detectar DISM
# ----------------------------------------------------------

$ADKDism = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"

if (Test-Path $ADKDism) {

    $Global:DismPath = $ADKDism
    $Global:DismSource = "Windows ADK"

}
else {

    $Global:DismPath = "$env:SystemRoot\System32\dism.exe"
    $Global:DismSource = "Windows"

}

# ----------------------------------------------------------
# Criar pastas necessárias
# ----------------------------------------------------------

@(
    $RootPath,
    $ISOPath,
    $ExtractPath,
    $MountPath,
    $OutputPath,
    $LogsPath,
    $InstallersPath
) | ForEach-Object {

    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }

}

# ----------------------------------------------------------
# Banner
# ----------------------------------------------------------

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "        Windows Mod" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Projeto.....: $($Config.Project.Name)"
Write-Host "Versão......: $($Config.Project.Version)"
Write-Host "Windows.....: $Edition"
Write-Host "Índice......: $Index"
Write-Host "DISM........: $DismSource"
Write-Host "Executável..: $DismPath"
Write-Host ""

# ----------------------------------------------------------
# Função de Log
# ----------------------------------------------------------

function Write-Log {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "HH:mm:ss"

    switch ($Level) {

        "INFO" {
            $Color = "White"
        }

        "SUCCESS" {
            $Color = "Green"
        }

        "WARNING" {
            $Color = "Yellow"
        }

        "ERROR" {
            $Color = "Red"
        }

        default {
            $Color = "Gray"
        }

    }

    Write-Host "[$Time] [$Level] $Message" -ForegroundColor $Color

}