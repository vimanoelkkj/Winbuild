# ==========================================================
# Windows Mod - Extract ISO
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

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

# ----------------------------------------------------------
# Detectar edição real dentro da ISO (não confiar só no texto
# fixo do BuildConfig.json) e persistir o que foi detectado
# ----------------------------------------------------------

Write-Log "Detectando edição do Windows na imagem..."

$WimPath = Join-Path $ExtractPath "sources\install.wim"

try {

    $Images = Get-WindowsImage -ImagePath $WimPath -ErrorAction Stop

}
catch {

    Write-Log "Não foi possível ler informações do install.wim: $($_.Exception.Message)" "ERROR"

    exit 1

}

if ($Images.Count -eq 1) {

    # ISO com uma edição só (a maioria das ISOs "consumer" de hoje em
    # dia é assim) - usa ela direto, não importa o que estava configurado
    $Selected = $Images[0]

}
else {

    # ISO multi-edição (ex: Windows com Home/Pro/Education juntos)
    $Selected = $Images | Where-Object { $_.ImageIndex -eq $Index }

    if (!$Selected) {

        Write-Log "O índice $Index (configurado em Windows.Index) não existe nesta ISO." "WARNING"

        Write-Host ""
        Write-Host "Esta ISO tem mais de uma edição. Escolha uma:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($Img in $Images) {
            Write-Host ("  [{0}] {1}" -f $Img.ImageIndex, $Img.ImageName)
        }

        Write-Host ""

        do {
            $Choice = Read-Host "Digite o número do índice desejado"
        } while ($Images.ImageIndex -notcontains [int]$Choice)

        $Selected = $Images | Where-Object { $_.ImageIndex -eq [int]$Choice }

    }

}

Write-Log "Edição detectada: [$($Selected.ImageIndex)] $($Selected.ImageName)" "SUCCESS"

# ----------------------------------------------------------
# Atualizar BuildConfig.json com o que foi realmente detectado
# ----------------------------------------------------------

if ($Config.Windows.Edition -ne $Selected.ImageName -or $Config.Windows.Index -ne $Selected.ImageIndex) {

    $Config.Windows.Edition = $Selected.ImageName
    $Config.Windows.Index   = $Selected.ImageIndex

    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8

    Write-Log "BuildConfig.json atualizado com a edição detectada." "SUCCESS"

    $Global:Edition = $Selected.ImageName
    $Global:Index   = $Selected.ImageIndex

}

Set-Summary "Windows detectado" "$($Selected.ImageName) (índice $($Selected.ImageIndex))"

Write-Log "Extração concluída com sucesso." "SUCCESS"

exit 0