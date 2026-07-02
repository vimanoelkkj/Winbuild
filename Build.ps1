# ==========================================================
# Windows Mod - Build
# ==========================================================

$ErrorActionPreference = "Stop"

$Root = "C:\Windows-Mod"

. "$Root\Scripts\Utils\Initialize.ps1"
. "$Root\Scripts\Utils\Helpers.ps1"

$StartTime = Get-Date

function Invoke-BuildStep {

    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter(Mandatory)]
        [int]$Total,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    Write-Host ""
    Write-Log "[$Number/$Total] $Name"

    if (!(Test-Path $ScriptPath)) {
        Write-Log "Script nao encontrado: $ScriptPath" "ERROR"
        exit 1
    }

    & $ScriptPath

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Falha na etapa: $Name" "ERROR"
        exit 1
    }

    Write-Log "$Name concluido." "SUCCESS"
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "       Windows Mod Builder" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Administrator)) {
    Write-Log "Execute o Build.ps1 como Administrador." "ERROR"
    exit 1
}

$Steps = @(
    @{
        Name = "Clean Workspace"
        Path = "$Root\Scripts\Core\Clean.ps1"
    },
    @{
        Name = "Extract ISO"
        Path = "$Root\Scripts\Core\ExtractISO.ps1"
    },
    @{
        Name = "Mount Image"
        Path = "$Root\Scripts\Core\MountImage.ps1"
    },

    # Features
@{
    Name = "Setup PostInstall"
    Path = "$Root\Scripts\Features\SetupPostInstall.ps1"
},
    @{
        Name = "Unmount Image"
        Path = "$Root\Scripts\Core\UnmountImage.ps1"
    },
    @{
        Name = "Create ISO"
        Path = "$Root\Scripts\Core\CreateISO.ps1"
    }
)

for ($i = 0; $i -lt $Steps.Count; $i++) {
    Invoke-BuildStep `
        -Number ($i + 1) `
        -Total $Steps.Count `
        -Name $Steps[$i].Name `
        -ScriptPath $Steps[$i].Path
}

$Duration = (Get-Date) - $StartTime

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "        BUILD FINALIZADO" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

Write-Log "Output: $OutputPath"
Write-Log ("Tempo total: {0:hh\:mm\:ss}" -f $Duration) "SUCCESS"