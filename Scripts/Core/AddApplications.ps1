# ==========================================================
# Windows Mod - Add Applications
# ==========================================================
#
# Copia os instaladores de $InstallersPath para dentro da imagem
# montada e gera um SetupComplete.cmd que os executa silenciosamente
# no fim da instalação (antes do primeiro logon).
#
# Estrutura esperada em $InstallersPath (a que já existe no projeto):
#
#   Installers\
#     Steam\
#       SteamSetup.exe
#     Firefox\
#       firefox_installer.exe
#       install.cmd          <- opcional, ver abaixo
#
# Por padrão o script tenta detectar o instalador (.exe ou .msi) e
# rodar com switches silenciosos genéricos (/S, /verysilent, /qn).
# Isso NÃO funciona para todo instalador. Se um app precisar de um
# switch específico, crie um "install.cmd" dentro da pasta dele — se
# esse arquivo existir, ele é chamado no lugar da detecção automática,
# com o diretório do próprio app como pasta de trabalho. Exemplo:
#
#   install.cmd:
#     SteamSetup.exe /S
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando adição de aplicativos..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-MountedImage)) {
    Write-Log "Nenhuma imagem montada. Rode MountImage.ps1 primeiro." "ERROR"
    exit 1
}

# ----------------------------------------------------------
# Listar apps (loop até achar algo ou usuário pular)
# ----------------------------------------------------------

while ($true) {
    $AppFolders = Get-ChildItem $InstallersPath -Directory -ErrorAction SilentlyContinue
    if ($AppFolders -and $AppFolders.Count -gt 0) {
        break
    }

    Write-Log "Nenhuma pasta de aplicativo encontrada em $InstallersPath" "WARNING"
    Write-Host ""
    Write-Host "Coloque as pastas de instaladores dentro de:" -ForegroundColor Yellow
    Write-Host "  $InstallersPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione [S] para pular esta etapa, ou qualquer outra tecla para tentar novamente..." -ForegroundColor Yellow
    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""

    if ($Key.Character -eq 's' -or $Key.Character -eq 'S') {
        Write-Log "Etapa de aplicativos pulada pelo usuário." "WARNING"
        Set-Summary "Apps" "Pulado"
        exit 0
    }
}

Write-Log "Aplicativos encontrados: $($AppFolders.Count)"

# ----------------------------------------------------------
# Preparar pastas de destino dentro da imagem
# ----------------------------------------------------------

$SetupScriptsPath = Join-Path $MountPath "Windows\Setup\Scripts"
$AppsDestPath      = Join-Path $SetupScriptsPath "Apps"
$SetupCompletePath = Join-Path $SetupScriptsPath "SetupComplete.cmd"
New-Item -ItemType Directory -Force -Path $AppsDestPath | Out-Null

# ----------------------------------------------------------
# Copiar cada app e montar o bloco de instalação
# ----------------------------------------------------------

$InstallBlocks = @()
$CopyFailCount = 0

foreach ($App in $AppFolders) {
    Write-Log "Copiando aplicativo: $($App.Name)"
    $Dest = Join-Path $AppsDestPath $App.Name
    $Result = robocopy $App.FullName $Dest /E
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ge 8) {
        Write-Log "Falha ao copiar '$($App.Name)' (robocopy $ExitCode)." "ERROR"
        $CopyFailCount++
        continue
    }

    $RelativeDest = "%~dp0Apps\$($App.Name)"
    $CustomInstall = Get-ChildItem $App.FullName -Filter "install.cmd" -ErrorAction SilentlyContinue

    if ($CustomInstall) {
        Write-Log "'$($App.Name)' usa install.cmd próprio."
        $InstallBlocks += "echo Instalando $($App.Name)...`r`ncd /d `"$RelativeDest`"`r`ncall install.cmd >> `"%~dp0Logs\$($App.Name).log`" 2>&1`r`n"
    }
    else {
        $Exe = Get-ChildItem $App.FullName -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        $Msi = Get-ChildItem $App.FullName -Filter *.msi -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($Msi) {
            Write-Log "'$($App.Name)' instalado via msiexec (/qn)."

            $InstallBlocks += "echo Instalando $($App.Name)...`r`nmsiexec /i `"$RelativeDest\$($Msi.Name)`" /qn /norestart >> `"%~dp0Logs\$($App.Name).log`" 2>&1`r`n"
        }
        elseif ($Exe) {
            Write-Log "'$($App.Name)' instalado via /S (switch genérico, pode não funcionar para todo instalador)." "WARNING"
            $InstallBlocks += "echo Instalando $($App.Name)...`r`n`"$RelativeDest\$($Exe.Name)`" /S >> `"%~dp0Logs\$($App.Name).log`" 2>&1`r`n"
        }
        else {
            Write-Log "Nenhum .exe/.msi encontrado em '$($App.Name)'. Pulando instalação (arquivos copiados mesmo assim)." "WARNING"
        }
    }
}

if ($CopyFailCount -gt 0) {
    Write-Log "$CopyFailCount aplicativo(s) falharam ao copiar." "ERROR"
    Set-Summary "Apps" "$CopyFailCount falharam ao copiar"
    exit 1
}

# ----------------------------------------------------------
# Gerar SetupComplete.cmd
# ----------------------------------------------------------

Write-Log "Gerando SetupComplete.cmd..."

New-Item -ItemType Directory -Force -Path (Join-Path $SetupScriptsPath "Logs") | Out-Null

$Header = "@echo off`r`n"

$Content = $Header + ($InstallBlocks -join "`r`n")

Set-Content -Path $SetupCompletePath -Value $Content -Encoding ASCII

Write-Log "SetupComplete.cmd gerado em $SetupCompletePath" "SUCCESS"
Write-Log "Aplicativos serão instalados automaticamente ao fim do setup (antes do primeiro logon)." "SUCCESS"

Set-Summary "Apps" "$($AppFolders.Count) app(s) adicionado(s)"

exit 0
