# ==========================================================
# Windows Mod - Initialize
# ==========================================================
#
# Este arquivo é sempre dot-sourced a partir de outro script (Build.ps1
# ou os scripts em Scripts\Core). Dentro de um script dot-sourced, o
# $PSScriptRoot do PRÓPRIO arquivo continua correto independente de
# quem o chamou — por isso conseguimos descobrir a raiz do projeto sem
# depender de nenhum caminho fixo tipo "C:\Windows-Mod".
#
# Scripts\Utils\Initialize.ps1 -> raiz do projeto é dois níveis acima.
# ==========================================================

$Global:ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

$ConfigPath = Join-Path $ProjectRoot "Config\BuildConfig.json"

if (!(Test-Path $ConfigPath)) {
    Write-Host ""
    Write-Host "ERRO: BuildConfig.json não encontrado em $ConfigPath" -ForegroundColor Red
    exit 1
}

$Global:Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# ----------------------------------------------------------
# Caminhos
# ----------------------------------------------------------
#
# Cada caminho no BuildConfig.json pode ser:
#   - Absoluto  (ex: "D:\Windows-Mod\Extract")   -> usado como está
#   - Relativo  (ex: ".\Extract" ou "Extract")   -> resolvido a partir
#                                                    da raiz do projeto
#
# Isso permite tanto rodar tudo de forma portátil (relativo) quanto
# apontar pastas pesadas (Extract/Mount, que podem passar de 20GB)
# para outro disco, se preferir.

function Resolve-ConfigPath {

    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }

    return (Join-Path $ProjectRoot $Value)

}

$Global:RootPath         = $ProjectRoot
$Global:ISOPath          = Resolve-ConfigPath $Config.Paths.ISO
$Global:ExtractPath      = Resolve-ConfigPath $Config.Paths.Extract
$Global:MountPath        = Resolve-ConfigPath $Config.Paths.Mount
$Global:OutputPath       = Resolve-ConfigPath $Config.Paths.Output
$Global:LogsPath         = Resolve-ConfigPath $Config.Paths.Logs
$Global:InstallersPath   = Resolve-ConfigPath $Config.Paths.Installers
$Global:DriversPath      = Resolve-ConfigPath $Config.Paths.Drivers
$Global:AutounattendPath = Resolve-ConfigPath $Config.Paths.Autounattend

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
    $ISOPath,
    $ExtractPath,
    $MountPath,
    $OutputPath,
    $LogsPath,
    $InstallersPath,
    $DriversPath,
    $AutounattendPath
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
Write-Host "Raiz........: $ProjectRoot"
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
