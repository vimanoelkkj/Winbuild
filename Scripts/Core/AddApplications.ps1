# ==========================================================
# Windows Mod - Add Applications (via winget)
# ==========================================================
#
# Em vez de copiar instaladores pra dentro da imagem (o que inchava o
# WIM e deixava versões desatualizadas), esse script:
#
#   1. Lê a lista de IDs de pacote do winget em:
#        Installers\winget-apps.txt   (um ID por linha, # comenta)
#
#   2. Gera um InstallApps.ps1 e copia ele direto pra dentro da imagem
#      em C:\ProgramData\WinbuildApps\InstallApps.ps1
#
#   3. Configura uma chave RunOnce no registro (via SetupComplete.cmd,
#      que roda como SYSTEM no fim do setup) apontando pro script.
#
# O Windows executa entradas RunOnce automaticamente no PRÓXIMO logon
# de qualquer usuário, e a entrada se apaga sozinha depois de rodar -
# isso é necessário porque o winget não funciona corretamente rodando
# como SYSTEM (antes do primeiro logon); ele só fica realmente
# disponível depois que algum usuário loga pela primeira vez, já que o
# registro do App Installer pela Microsoft Store é assíncrono. Por
# isso o InstallApps.ps1 também espera/tenta de novo por um tempo
# antes de desistir.
#
# Exemplo de winget-apps.txt:
#
#   # Essenciais
#   Valve.Steam
#   Spotify.Spotify
#   RARLab.WinRAR
#   Vencord.Vesktop
#
# Pra descobrir o ID certo de um app: winget search "nome do app"
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando configuração de aplicativos (winget)..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-MountedImage)) {
    Write-Log "Nenhuma imagem montada. Rode MountImage.ps1 primeiro." "ERROR"
    exit 1
}

$AppsListPath = Join-Path $InstallersPath "winget-apps.txt"

# ----------------------------------------------------------
# Ler a lista (loop até ter algo válido ou usuário pular)
# ----------------------------------------------------------

while ($true) {

    $AppIds = @()

    if (Test-Path $AppsListPath) {

        $AppIds = @(
            Get-Content $AppsListPath |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*#' }
        )

    }

    if ($AppIds.Count -gt 0) {
        break
    }

    Write-Log "Nenhum ID de pacote encontrado em $AppsListPath" "WARNING"
    Write-Host ""
    Write-Host "Crie o arquivo com um ID de pacote do winget por linha:" -ForegroundColor Yellow
    Write-Host "  $AppsListPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Exemplo:" -ForegroundColor Yellow
    Write-Host "  Valve.Steam" -ForegroundColor Yellow
    Write-Host "  Spotify.Spotify" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione [S] para pular esta etapa, ou qualquer outra tecla para tentar novamente..." -ForegroundColor Yellow

    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Write-Host ""

    if ($Key.Character -eq 's' -or $Key.Character -eq 'S') {
        Write-Log "Etapa de aplicativos pulada pelo usuário." "WARNING"
        Set-Summary "Apps" "Pulado"
        $Global:StepSkipped = $true
        exit 0
    }

}

Write-Log "Apps na lista: $($AppIds.Count) ($($AppIds -join ', '))"

# ----------------------------------------------------------
# Gerar InstallApps.ps1 e copiar pra dentro da imagem
# ----------------------------------------------------------

$AppsInImagePath = Join-Path $MountPath "ProgramData\WinbuildApps"

New-Item -ItemType Directory -Force -Path $AppsInImagePath | Out-Null

$AppsArrayLiteral = ($AppIds | ForEach-Object { "    `"$_`"" }) -join "`r`n"

$InstallScript = @"
`$LogPath = "C:\ProgramData\WinbuildApps\install-log.txt"

"Iniciando instalação de apps via winget - `$(Get-Date)" | Out-File `$LogPath

# winget só fica disponível depois do primeiro logon (registro
# assíncrono pela Microsoft Store) - espera até 2 minutos.
`$Attempts = 0

while (!(Get-Command winget -ErrorAction SilentlyContinue) -and `$Attempts -lt 24) {
    Start-Sleep -Seconds 5
    `$Attempts++
}

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    "winget não ficou disponível a tempo. Abortando." | Out-File `$LogPath -Append
    exit 1
}

`$Apps = @(
$AppsArrayLiteral
)

foreach (`$App in `$Apps) {
    "Instalando `$App..." | Out-File `$LogPath -Append
    winget install --id `$App --silent --accept-package-agreements --accept-source-agreements *>> `$LogPath
}

"Concluído - `$(Get-Date)" | Out-File `$LogPath -Append
"@

$InstallScriptPath = Join-Path $AppsInImagePath "InstallApps.ps1"

Set-Content -Path $InstallScriptPath -Value $InstallScript -Encoding UTF8

Write-Log "InstallApps.ps1 gerado em $InstallScriptPath" "SUCCESS"

# ----------------------------------------------------------
# Agendar via RunOnce (SetupComplete.cmd roda como SYSTEM, só
# escreve a chave de registro - quem executa o winget de fato é
# o próprio Windows, no próximo logon, no contexto do usuário)
# ----------------------------------------------------------

$SetupScriptsPath = Join-Path $MountPath "Windows\Setup\Scripts"
$SetupCompletePath = Join-Path $SetupScriptsPath "SetupComplete.cmd"

New-Item -ItemType Directory -Force -Path $SetupScriptsPath | Out-Null

$SetupCompleteContent = @"
@echo off
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v WinbuildInstallApps /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\ProgramData\WinbuildApps\InstallApps.ps1" /f
"@

Set-Content -Path $SetupCompletePath -Value $SetupCompleteContent -Encoding ASCII

Write-Log "SetupComplete.cmd configurado para agendar a instalação via RunOnce." "SUCCESS"
Write-Log "Apps serão instalados via winget no primeiro logon do usuário." "SUCCESS"

Set-Summary "Apps" "$($AppIds.Count) app(s) via winget"

exit 0
