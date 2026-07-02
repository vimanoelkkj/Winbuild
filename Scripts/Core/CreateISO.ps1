# ==========================================================
# Windows Mod - Create ISO
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando criacao da ISO..."

$Oscdimg = Get-ChildItem "C:\Program Files (x86)\Windows Kits" -Recurse -Filter oscdimg.exe |
    Where-Object { $_.FullName -like "*amd64*Oscdimg*" } |
    Select-Object -First 1

if (!$Oscdimg) {
    Write-Log "oscdimg.exe nao encontrado. Instale o Windows ADK com Deployment Tools." "ERROR"
    exit 1
}

if (!(Test-Path "$ExtractPath\sources\install.wim")) {
    Write-Log "install.wim nao encontrado. Rode ExtractISO.ps1 primeiro." "ERROR"
    exit 1
}

$IsoName = "Windows-Mod-v$($Config.Project.Version).iso"
$IsoPath = Join-Path $OutputPath $IsoName

$BootData = "2#p0,e,b$ExtractPath\boot\etfsboot.com#pEF,e,b$ExtractPath\efi\microsoft\boot\efisys.bin"

Write-Log "Oscdimg: $($Oscdimg.FullName)"
Write-Log "Origem: $ExtractPath"
Write-Log "Destino: $IsoPath"

& $Oscdimg.FullName `
    -m `
    -o `
    -u2 `
    -udfver102 `
    -bootdata:$BootData `
    $ExtractPath `
    $IsoPath

if ($LASTEXITCODE -eq 0) {
    Write-Log "ISO criada com sucesso: $IsoPath" "SUCCESS"

    $Hash = Get-FileHash $IsoPath -Algorithm SHA256
    Write-Log "SHA256: $($Hash.Hash)"
}
else {
    Write-Log "Falha ao criar ISO." "ERROR"
    exit 1
}