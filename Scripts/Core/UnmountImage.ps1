# ==========================================================
# Windows Mod - Unmount Image
# ==========================================================

param(
    [switch]$Discard
)

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando desmontagem da imagem..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-MountedImage)) {
    Write-Log "Nenhuma imagem montada." "WARNING"
    exit 0
}

if ($Discard) {

    Write-Log "Descartando alteracoes..."

    & $DismPath /Unmount-Image `
        /MountDir:"$MountPath" `
        /Discard

}
else {

    Write-Log "Salvando alteracoes..."

    & $DismPath /Unmount-Image `
        /MountDir:"$MountPath" `
        /Commit

}

if ($LASTEXITCODE -eq 0) {

    Write-Log "Imagem desmontada com sucesso." "SUCCESS"

}
else {

    Write-Log "Falha ao desmontar a imagem." "ERROR"
    exit 1

}