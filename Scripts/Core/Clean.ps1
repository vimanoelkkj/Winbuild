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

    Write-Log "Imagem montada encontrada. Descartando alteracoes..."

    & $DismPath /Unmount-Image `
        /MountDir:"$MountPath" `
        /Discard

}

Write-Log "Limpando Mount..."

Clear-Folder $MountPath

# ----------------------------------------------------------
# Limpar pastas
# ----------------------------------------------------------

$Folders = @(
    $ExtractPath,
    $MountPath,
    $OutputPath,
    "$RootPath\Temp",
    $LogsPath
)

foreach ($Folder in $Folders) {

    Write-Log "Limpando: $Folder"

    Clear-Folder $Folder

}

Write-Log "Limpeza concluida." "SUCCESS"