# ==========================================================
# Windows Mod - Extract ISO
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"

Write-Log "Iniciando extração da ISO..."

# ----------------------------------------------------------
# Verificar ISO (loop até encontrar exatamente uma)
# ----------------------------------------------------------

while ($true) {

    $IsoFiles = Get-ChildItem $ISOPath -Filter *.iso -ErrorAction SilentlyContinue

    if ($IsoFiles.Count -eq 1) {
        break
    }

    if ($IsoFiles.Count -gt 1) {
        Write-Log "Mais de uma ISO encontrada em $ISOPath. Deixe apenas uma." "WARNING"
    }
    else {
        Write-Log "Nenhuma ISO encontrada em $ISOPath" "WARNING"
    }

    Write-Host ""
    Write-Host "Coloque APENAS o arquivo .iso do Windows dentro de:" -ForegroundColor Yellow
    Write-Host "  $ISOPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione qualquer tecla para tentar novamente (CTRL+C para cancelar)..." -ForegroundColor Yellow

    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Write-Host ""

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

exit 0