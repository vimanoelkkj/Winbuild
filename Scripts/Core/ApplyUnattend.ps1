# ==========================================================
# Windows Mod - Apply Unattend
# ==========================================================
#
# Copia o arquivo de resposta (autounattend.xml / unattend.xml) de
# $AutounattendPath para a raiz da mídia extraída ($ExtractPath), que
# é onde o Windows Setup procura por ele ao bootar da ISO/USB.
#
# Roda DEPOIS do Unmount (não mexe na imagem montada, só na pasta que
# depois vira a ISO) e ANTES do CreateISO.
#
# Coloque só UM arquivo .xml em $AutounattendPath.
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Aplicando arquivo de resposta (unattend)..."

if (!(Test-Path $ExtractPath)) {
    Write-Log "Pasta Extract não encontrada. Rode ExtractISO.ps1 primeiro." "ERROR"
    exit 1
}

# ----------------------------------------------------------
# Localizar o XML (loop até achar exatamente um ou usuário pular)
# ----------------------------------------------------------

while ($true) {

    $XmlFiles = Get-ChildItem $AutounattendPath -Filter *.xml -ErrorAction SilentlyContinue

    if ($XmlFiles.Count -eq 1) {
        break
    }

    if ($XmlFiles.Count -gt 1) {

        Write-Log "Mais de um .xml encontrado em $AutounattendPath" "WARNING"
        Write-Host ""
        Write-Host "Deixe só o autounattend.xml dentro de:" -ForegroundColor Yellow
        Write-Host "  $AutounattendPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Pressione qualquer tecla para tentar novamente..." -ForegroundColor Yellow

        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        Write-Host ""

        continue

    }

    Write-Log "Nenhum .xml encontrado em $AutounattendPath" "WARNING"
    Write-Host ""
    Write-Host "Coloque o autounattend.xml dentro de:" -ForegroundColor Yellow
    Write-Host "  $AutounattendPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione [S] para pular esta etapa (setup ficará interativo), ou qualquer outra tecla para tentar novamente..." -ForegroundColor Yellow

    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Write-Host ""

    if ($Key.Character -eq 's' -or $Key.Character -eq 'S') {
        Write-Log "Etapa de unattend pulada pelo usuário." "WARNING"
        Set-Summary "Unattend" "Pulado (setup interativo)"
        $Global:StepSkipped = $true
        exit 0
    }

}

$XmlFile = $XmlFiles[0]

Write-Log "Arquivo encontrado: $($XmlFile.Name)"

# ----------------------------------------------------------
# Validar XML
# ----------------------------------------------------------

try {

    [xml](Get-Content $XmlFile.FullName -Raw) | Out-Null

}
catch {

    Write-Log "O arquivo '$($XmlFile.Name)' não é um XML válido: $($_.Exception.Message)" "ERROR"
    exit 1

}

Write-Log "XML validado com sucesso."

# ----------------------------------------------------------
# Resumir o que o unattend vai fazer e pedir confirmação
# ----------------------------------------------------------

$Categories = Get-UnattendSummary -XmlPath $XmlFile.FullName

Write-Host ""
Write-Host "=== O que este autounattend.xml vai fazer ===" -ForegroundColor Cyan

$TotalItems = 0
$HasWarnings = $false

if ($Categories.Count -eq 0) {

    Write-Host ""
    Write-Host "Nada de impacto crítico detectado (sem apagar disco, sem contas automáticas, sem bypass)." -ForegroundColor Green
    Write-Log "Nenhum item encontrado no unattend."

}
else {

    foreach ($Category in $Categories.Keys) {

        Write-Host ""
        Write-Host "=== $Category ===" -ForegroundColor Cyan

        foreach ($Item in $Categories[$Category]) {

            $TotalItems++

            if ($Item.Level -eq "warn") {
                $HasWarnings = $true
                Write-Host "  ⚠ $($Item.Text)" -ForegroundColor Yellow
            }
            else {
                Write-Host "  ✔ $($Item.Text)" -ForegroundColor Gray
            }

        }

    }

    Write-Host ""

    if ($HasWarnings) {

        Write-Host "Itens marcados com ⚠ merecem atenção especial (perda de dados, segurança reduzida, etc.)." -ForegroundColor Yellow
        Write-Host "Digite SIM (maiúsculo) para confirmar que está ciente e continuar." -ForegroundColor Yellow
        Write-Host "Ou apenas ENTER para cancelar o build e revisar o arquivo." -ForegroundColor Yellow
        Write-Host ""

        $Confirm = Read-Host "Confirmação"

        if ($Confirm -cne "SIM") {

            Write-Log "Build cancelado - usuário não confirmou o conteúdo do unattend.xml." "ERROR"
            Set-Summary "Unattend" "Cancelado na confirmação"
            exit 1

        }

        Write-Log "Usuário confirmou ciência do conteúdo do unattend.xml ($TotalItems item(s), com avisos)." "SUCCESS"

    }
    else {

        Write-Log "$TotalItems item(s) detectado(s) no unattend, nenhum com nível de atenção especial." "SUCCESS"

    }

}

Write-Host ""

# ----------------------------------------------------------
# Copiar para a raiz da mídia
# ----------------------------------------------------------

$Destination = Join-Path $ExtractPath "autounattend.xml"

Copy-Item $XmlFile.FullName $Destination -Force

Write-Log "Arquivo copiado para: $Destination" "SUCCESS"
Write-Log "Aplicação do unattend concluída." "SUCCESS"

Set-Summary "Unattend" "Aplicado ($($XmlFile.Name))"

exit 0
