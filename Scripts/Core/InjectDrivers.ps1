# ==========================================================
# Windows Mod - Inject Drivers
# ==========================================================
#
# Injeta drivers (pastas contendo .inf) na imagem offline montada.
#
# Estrutura esperada em $DriversPath:
#
#   Drivers\
#     NVIDIA\        <- só os arquivos do driver (.inf, .cat, .sys, .dll)
#     AMD-Chipset\
#     Intel-LAN\
#
# IMPORTANTE: não é a mesma coisa que Installers\NVIDIA (essa é para
# instaladores completos/apps, que rodam no primeiro logon). Aqui deve
# entrar SÓ a pasta do driver extraído (ex.: a subpasta "Display.Driver"
# de dentro do pacote da NVIDIA, ou o resultado de extrair o instalador
# com 7-Zip). Instalador completo aqui vai inchar o WIM.
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando injeção de drivers..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-MountedImage)) {
    Write-Log "Nenhuma imagem montada. Rode MountImage.ps1 primeiro." "ERROR"
    exit 1
}

# ----------------------------------------------------------
# Listar pastas de drivers (loop até achar algo ou usuário pular)
# ----------------------------------------------------------

while ($true) {

    $DriverFolders = Get-ChildItem $DriversPath -Directory -ErrorAction SilentlyContinue

    if ($DriverFolders -and $DriverFolders.Count -gt 0) {
        break
    }

    Write-Log "Nenhuma pasta de driver encontrada em $DriversPath" "WARNING"
    Write-Host ""
    Write-Host "Coloque as pastas de driver (com os .inf) dentro de:" -ForegroundColor Yellow
    Write-Host "  $DriversPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione [S] para pular esta etapa, ou qualquer outra tecla para tentar novamente..." -ForegroundColor Yellow

    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Write-Host ""

    if ($Key.Character -eq 's' -or $Key.Character -eq 'S') {
        Write-Log "Etapa de drivers pulada pelo usuário." "WARNING"
        Set-Summary "Drivers" "Pulado"
        $Global:StepSkipped = $true
        exit 0
    }

}

Write-Log "Pastas de driver encontradas: $($DriverFolders.Count)"

# ----------------------------------------------------------
# Injetar cada pasta
# ----------------------------------------------------------

$FailCount = 0
$SuccessCount = 0

foreach ($Folder in $DriverFolders) {

    $InfFiles = Get-ChildItem $Folder.FullName -Filter *.inf -Recurse -ErrorAction SilentlyContinue

    if (!$InfFiles -or $InfFiles.Count -eq 0) {
        Write-Log "Nenhum .inf encontrado em '$($Folder.Name)'. Pulando." "WARNING"
        continue
    }

    # Copia pra uma pasta temporária antes de injetar, pra poder remover
    # arquivos problemáticos sem mexer nos arquivos originais do usuário
    # em Drivers\.
    $StagingFolder = Join-Path $RootPath "Temp\DriverStaging\$($Folder.Name)"

    if (Test-Path $StagingFolder) {
        Remove-Item $StagingFolder -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $StagingFolder | Out-Null

    robocopy $Folder.FullName $StagingFolder /E /NFL /NDL /NJH /NJS | Out-Null

    Write-Log "Injetando driver: $($Folder.Name) ($($InfFiles.Count) .inf encontrado(s))"

    & $DismPath /Image:"$MountPath" /Add-Driver /Driver:"$StagingFolder" /Recurse

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Driver '$($Folder.Name)' injetado com sucesso." "SUCCESS"
        $SuccessCount++
    }
    else {
        Write-Log "Falha ao injetar driver '$($Folder.Name)' (código $LASTEXITCODE)." "ERROR"
        $FailCount++
    }

    Remove-Item $StagingFolder -Recurse -Force -ErrorAction SilentlyContinue

}

if ($FailCount -gt 0) {
    Write-Log "$FailCount driver(s) falharam ao injetar." "ERROR"
    Set-Summary "Drivers" "$SuccessCount ok, $FailCount falharam"
    exit 1
}

Write-Log "Injeção de drivers concluída." "SUCCESS"
Set-Summary "Drivers" "$SuccessCount driver(s) injetado(s)"
exit 0
