# ==========================================================
# Windows Mod - Mount Image
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando montagem da imagem..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-ExtractedISO)) {
    Write-Log "ISO ainda não foi extraída. Rode ExtractISO.ps1 primeiro." "ERROR"
    exit 1
}

if (Test-MountedImage) {
    Write-Log "Já existe uma imagem montada. Desmonte antes de continuar." "WARNING"
    exit 1
}

$InstallWim = Get-InstallWim

Write-Log "Imagem: $InstallWim"
Write-Log "Índice: $Index"
Write-Log "Mount: $MountPath"
Write-Log "DISM: $DismSource"

& $DismPath /Mount-Image /ImageFile:"$InstallWim" /Index:$Index /MountDir:"$MountPath"

if ($LASTEXITCODE -eq 0) {
    Write-Log "Imagem montada com sucesso." "SUCCESS"
}
else {
    Write-Log "Falha ao montar imagem." "ERROR"
    exit 1
}