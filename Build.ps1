# ==========================================================
# Windows Mod - Build
# ==========================================================

$ErrorActionPreference = "Stop"

# Root = pasta onde este Build.ps1 está, não importa de onde foi chamado
# nem onde o projeto foi extraído/clonado (Downloads, D:\, etc.)
$Root = $PSScriptRoot

# Helpers.ps1 só define funções (sem efeito colateral), por isso pode
# ser carregado antes do Initialize.ps1 aqui, só pra termos acesso ao
# Test-Administrator antes de qualquer outra coisa rodar.
. "$Root\Scripts\Utils\Helpers.ps1"

# ----------------------------------------------------------
# Auto-elevação (UAC)
# ----------------------------------------------------------
#
# Se não estiver rodando como Administrador, o script se relança
# sozinho numa nova janela elevada (dispara o prompt do UAC) e encerra
# a instância atual. O -NoExit mantém a janela nova aberta no final,
# pra você conseguir ver o resultado do build.

if (!(Test-Administrator)) {
    Write-Host ""
    Write-Host "Privilégios de administrador necessários. Solicitando elevação (UAC)..." -ForegroundColor Yellow
    $PowerShellArgs = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`""
    $HasWindowsTerminal = [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)
    try {
        if ($HasWindowsTerminal) {
            # Abre uma aba do Windows Terminal já elevada rodando o powershell.exe
            Start-Process -FilePath "wt.exe" -ArgumentList "powershell.exe $PowerShellArgs" -Verb RunAs
        }
        else {
            # Fallback: sem Windows Terminal instalado, usa o console clássico
            Start-Process -FilePath "powershell.exe" -ArgumentList $PowerShellArgs -Verb RunAs
        }
    }
    catch {
        Write-Host ""
        Write-Host "Elevação cancelada ou falhou. Rode o PowerShell como Administrador manualmente." -ForegroundColor Red
    }
    exit
}

. "$Root\Scripts\Utils\Initialize.ps1"

$Global:BuildSummary = [ordered]@{}

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
    @{
        Name = "Inject Drivers"
        Path = "$Root\Scripts\Core\InjectDrivers.ps1"
    },
    @{
        Name = "Add Applications"
        Path = "$Root\Scripts\Core\AddApplications.ps1"
    },
    @{
        Name = "Unmount Image"
        Path = "$Root\Scripts\Core\UnmountImage.ps1"
    },
    @{
        Name = "Apply Unattend"
        Path = "$Root\Scripts\Core\ApplyUnattend.ps1"
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

if ($Global:BuildSummary.Count -gt 0) {
    Write-Host "Resumo:" -ForegroundColor Cyan
    foreach ($Key in $Global:BuildSummary.Keys) {
        Write-Host ("  {0,-10}: {1}" -f $Key, $Global:BuildSummary[$Key])
    }
    Write-Host ""
}

Write-Log "Output: $OutputPath"
Write-Log ("Tempo total: {0:hh\:mm\:ss}" -f $Duration) "SUCCESS"
