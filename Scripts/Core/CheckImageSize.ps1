# ==========================================================
# Windows Mod - Check Image Size
# ==========================================================
#
# Confere o tamanho do install.wim antes de empacotar a ISO final.
# Um WIM anormalmente grande geralmente indica lixo acumulado de
# ciclos de mount/commit repetidos, ou um driver/app grande demais
# injetado por engano.
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Verificando tamanho da imagem..."

$WimPath = Join-Path $ExtractPath "sources\install.wim"

if (!(Test-Path $WimPath)) {
    Write-Log "install.wim não encontrado em $WimPath" "ERROR"
    exit 1
}

$SizeGB = [math]::Round((Get-Item $WimPath).Length / 1GB, 2)

Write-Log "Tamanho do install.wim: $SizeGB GB (limite configurado: $MaxWimSizeGB GB)"

Set-Summary "Tamanho WIM" "$SizeGB GB"

if ($SizeGB -le $MaxWimSizeGB) {
    Write-Log "Tamanho dentro do esperado." "SUCCESS"
    exit 0
}

Write-Log "Imagem maior que o esperado ($SizeGB GB > $MaxWimSizeGB GB)." "WARNING"

Write-Host ""
Write-Host "Isso geralmente indica:" -ForegroundColor Yellow
Write-Host "  - Lixo acumulado de builds anteriores (rode Clean.ps1 e refaça do zero)" -ForegroundColor Yellow
Write-Host "  - Um driver/app grande demais foi injetado por engano" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pressione qualquer tecla para continuar mesmo assim, ou CTRL+C para cancelar..." -ForegroundColor Yellow

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""

exit 0
