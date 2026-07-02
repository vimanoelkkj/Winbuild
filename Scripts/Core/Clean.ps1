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

# ----------------------------------------------------------
# Limpar ISOs
# ----------------------------------------------------------

Write-Log "Removendo ISOs..."

Get-ChildItem $ISOPath -Filter *.iso -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ----------------------------------------------------------
# Limpar instaladores
# ----------------------------------------------------------

Write-Log "Removendo instaladores..."

Get-ChildItem $InstallersPath -Recurse -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Log "Limpeza concluida." "SUCCESS"