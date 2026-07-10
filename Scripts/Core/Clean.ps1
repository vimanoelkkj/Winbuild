# ==========================================================
# Windows Mod - Clean
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando limpeza do projeto..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

# ----------------------------------------------------------
# Desmontar imagem caso exista
# ----------------------------------------------------------

if (Test-MountedImage) {

    Write-Log "Imagem montada encontrada. Descartando alterações..."

    & $DismPath /Unmount-Image `
        /MountDir:"$MountPath" `
        /Discard

}

# ----------------------------------------------------------
# Limpar pastas (só as que realmente têm algo dentro)
# ----------------------------------------------------------

$Folders = @(
    $ExtractPath,
    $MountPath,
    $OutputPath,
    "$RootPath\Temp",
    $LogsPath
)

foreach ($Folder in $Folders) {

    if (!(Test-Path $Folder)) {
        continue
    }

    $HasContent = [bool](Get-ChildItem $Folder -Force -ErrorAction SilentlyContinue)

    if (!$HasContent) {
        Write-Log "Nada para limpar: $Folder. Pulando..."
        continue
    }

    Write-Log "Limpando: $Folder"

    Clear-Folder $Folder

}

Write-Log "Limpeza concluída." "SUCCESS"

exit 0
