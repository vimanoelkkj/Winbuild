# ==========================================================
# Windows Mod - Extract ISO
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"

Write-Log "Iniciando extração da ISO..."

# ----------------------------------------------------------
# Verificar ISO
# ----------------------------------------------------------

$IsoFiles = Get-ChildItem $ISOPath -Filter *.iso

if ($IsoFiles.Count -eq 0) {
    Write-Log "Nenhuma ISO encontrada em $ISOPath" "ERROR"
    exit 1
}

if ($IsoFiles.Count -gt 1) {
    Write-Log "Mais de uma ISO encontrada em $ISOPath. Deixe apenas uma ISO na pasta." "ERROR"
    exit 1
}

$IsoFile = $IsoFiles[0].FullName

Write-Log "ISO encontrada: $(Split-Path $IsoFile -Leaf)"

# ----------------------------------------------------------
# Limpar pasta Extract
# ----------------------------------------------------------

if (Test-Path $ExtractPath) {

    Write-Log "Limpando pasta Extract..."

    Remove-Item "$ExtractPath\*" -Recurse -Force -ErrorAction SilentlyContinue

}

# ----------------------------------------------------------
# Montar ISO
# ----------------------------------------------------------

Write-Log "Montando ISO..."

$Image = Mount-DiskImage -ImagePath $IsoFile -PassThru

Start-Sleep -Seconds 2

# ----------------------------------------------------------
# Descobrir letra da unidade
# ----------------------------------------------------------

$DriveLetter = ($Image | Get-Volume).DriveLetter

if (!$DriveLetter) {

    Write-Log "Não foi possível descobrir a letra da unidade." "ERROR"

    Dismount-DiskImage -ImagePath $IsoFile

    exit 1

}

$Source = "$DriveLetter`:\" 

Write-Log "ISO montada em $Source"

# ----------------------------------------------------------
# Copiar arquivos
# ----------------------------------------------------------

Write-Log "Extraindo arquivos..."

$Result = robocopy $Source $ExtractPath /E

$ExitCode = $LASTEXITCODE

if ($ExitCode -ge 8) {

    Write-Log "Robocopy retornou erro ($ExitCode)." "ERROR"

    Dismount-DiskImage -ImagePath $IsoFile

    exit 1

}

Write-Log "Arquivos copiados."

# ----------------------------------------------------------
# Remover atributos somente leitura
# ----------------------------------------------------------

Write-Log "Removendo atributos somente leitura..."

Remove-ReadOnlyAttributes $ExtractPath

Write-Log "Atributos removidos."
# ----------------------------------------------------------
# Desmontar ISO
# ----------------------------------------------------------

Write-Log "Desmontando ISO..."

Dismount-DiskImage -ImagePath $IsoFile

Write-Log "Extração concluída com sucesso." "SUCCESS"