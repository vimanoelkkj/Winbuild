# ==========================================================
# Windows Mod - Inject Drivers
# ==========================================================
#
# Injeta drivers (pastas contendo .inf) na imagem offline montada.
#
# Estrutura esperada em $DriversPath:
#
#   Drivers\
#     NVIDIA\        <- só os arquivos do driver (.inf, .cat, .sys, .dll)
#     AMD-Chipset\
#     Intel-LAN\
#
# IMPORTANTE: não é a mesma coisa que Installers\NVIDIA (essa é para
# instaladores completos/apps, que rodam no primeiro logon). Aqui deve
# entrar SÓ a pasta do driver extraído (ex.: a subpasta "Display.Driver"
# de dentro do pacote da NVIDIA, ou o resultado de extrair o instalador
# com 7-Zip). Instalador completo aqui vai inchar o WIM.
#
# ==========================================================

. "$PSScriptRoot\..\Utils\Initialize.ps1"
. "$PSScriptRoot\..\Utils\Helpers.ps1"

Write-Log "Iniciando injeção de drivers..."

if (!(Test-Administrator)) {
    Write-Log "Execute este script como Administrador." "ERROR"
    exit 1
}

if (!(Test-MountedImage)) {
    Write-Log "Nenhuma imagem montada. Rode MountImage.ps1 primeiro." "ERROR"
    exit 1
}

# ----------------------------------------------------------
# Listar pastas de drivers (loop até achar algo ou usuário pular)
# ----------------------------------------------------------

while ($true) {

    $DriverFolders = Get-ChildItem $DriversPath -Directory -ErrorAction SilentlyContinue

    if ($DriverFolders -and $DriverFolders.Count -gt 0) {
        break
    }

    Write-Log "Nenhuma pasta de driver encontrada em $DriversPath" "WARNING"
    Write-Host ""
    Write-Host "Coloque as pastas de driver (com os .inf) dentro de:" -ForegroundColor Yellow
    Write-Host "  $DriversPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pressione [S] para pular esta etapa, ou qualquer outra tecla para tentar novamente..." -ForegroundColor Yellow

    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Write-Host ""

    if ($Key.Character -eq 's' -or $Key.Character -eq 'S') {
        Write-Log "Etapa de drivers pulada pelo usuário." "WARNING"
        Set-Summary "Drivers" "Pulado"
        $Global:StepSkipped = $true
        exit 0
    }

}

Write-Log "Pastas de driver encontradas: $($DriverFolders.Count)"

# ----------------------------------------------------------
# Extrai o mapa DEV_ID -> Nome de dentro de um conjunto de .inf
# (a seção [Strings] de cada .inf já documenta isso, ex:
#  NVIDIA_DEV.2204.01 = "NVIDIA GeForce RTX 3090")
# ----------------------------------------------------------

function Get-DeviceMapFromInfs {

    param([array]$InfFiles)

    $Map = @{}

    foreach ($Inf in $InfFiles) {

        $Lines = Get-Content $Inf.FullName -ErrorAction SilentlyContinue

        foreach ($Line in $Lines) {

            if ($Line -match '_DEV[_\.]([0-9A-Fa-f]{4})(\.\d+)?\s*=\s*"([^"]+)"') {

                $DevId = $Matches[1].ToUpper()
                $Name  = $Matches[3]

                if (!$Map.ContainsKey($DevId)) {
                    $Map[$DevId] = $Name
                }

            }

        }

    }

    return $Map

}

# ----------------------------------------------------------
# Filtra um conjunto de .inf (de UMA ÚNICA subpasta, ex: só
# Display.Driver) pelo modelo digitado pelo usuário
# ----------------------------------------------------------

function Invoke-InfFilterByModel {

    param(
        [array]$LeafInfs,
        [string]$LeafName
    )

    Write-Host ""
    Write-Host "'$LeafName' tem $($LeafInfs.Count) .inf - normalmente um pacote com várias famílias de hardware." -ForegroundColor Yellow
    Write-Host "Digite parte do modelo (ex: 3090, RTX 4070, GTX 1660) para manter só o necessário." -ForegroundColor Yellow
    Write-Host "Ou pressione ENTER sem digitar nada para manter todos os $($LeafInfs.Count) (mais compatível, porém maior)." -ForegroundColor Yellow
    Write-Host ""

    $GpuQuery = Read-Host "Modelo"

    if ([string]::IsNullOrWhiteSpace($GpuQuery)) {
        Write-Log "Nenhum filtro aplicado. Mantendo todos os $($LeafInfs.Count) .inf de '$LeafName'." "WARNING"
        return $LeafInfs
    }

    $DeviceMap = Get-DeviceMapFromInfs -InfFiles $LeafInfs

    $Found = @($DeviceMap.GetEnumerator() | Where-Object { $_.Value -like "*$GpuQuery*" })

    if ($Found.Count -eq 0) {
        Write-Log "Nenhum modelo contendo '$GpuQuery' encontrado em '$LeafName'. Mantendo todos os $($LeafInfs.Count)." "WARNING"
        return $LeafInfs
    }

    if ($Found.Count -gt 1) {

        Write-Host ""
        Write-Host "Mais de um modelo bateu com '$GpuQuery' em '$LeafName':" -ForegroundColor Yellow

        $Indexed = @{}
        $i = 1

        foreach ($Item in $Found) {
            Write-Host "  [$i] $($Item.Value)  (DEV_$($Item.Key))"
            $Indexed[$i] = $Item
            $i++
        }

        Write-Host ""

        do {
            $Choice = Read-Host "Número(s) do(s) modelo(s) correto(s), separados por vírgula"
            $ChoiceNums = @($Choice -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
            $Invalid = @($ChoiceNums | Where-Object { !$Indexed.ContainsKey($_) })
        } while ($ChoiceNums.Count -eq 0 -or $Invalid.Count -gt 0)

        $Found = @($ChoiceNums | ForEach-Object { $Indexed[$_] })

    }

    $SelectedNames  = ($Found | ForEach-Object { $_.Value }) -join ", "
    $SelectedDevIds = $Found | ForEach-Object { $_.Key }

    Write-Log "'$LeafName' - selecionado: $SelectedNames (DEV_$($SelectedDevIds -join ', DEV_'))" "SUCCESS"

    $Pattern = ($SelectedDevIds | ForEach-Object { "DEV_$_" }) -join "|"

    $MatchedInfs = @($LeafInfs | Where-Object {
        Select-String -Path $_.FullName -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue
    })

    if ($MatchedInfs.Count -eq 0) {
        Write-Log "Nenhum .inf de '$LeafName' contém o DEV_ID selecionado. Mantendo todos os $($LeafInfs.Count)." "WARNING"
        return $LeafInfs
    }

    Write-Log "'$LeafName': filtrado ($($MatchedInfs.Count) de $($LeafInfs.Count) .inf mantidos)." "SUCCESS"

    return $MatchedInfs

}

# ----------------------------------------------------------
# Injetar cada pasta de driver
# ----------------------------------------------------------

$FailCount = 0
$SuccessCount = 0

foreach ($Folder in $DriverFolders) {

    $InfFiles = Get-ChildItem $Folder.FullName -Filter *.inf -Recurse -ErrorAction SilentlyContinue

    if (!$InfFiles -or $InfFiles.Count -eq 0) {
        Write-Log "Nenhum .inf encontrado em '$($Folder.Name)'. Pulando." "WARNING"
        continue
    }

    # Copia pra uma pasta temporária antes de injetar, pra poder remover
    # arquivos sem mexer nos originais do usuário em Drivers\.
    $StagingFolder = Join-Path $RootPath "Temp\DriverStaging\$($Folder.Name)"

    if (Test-Path $StagingFolder) {
        Remove-Item $StagingFolder -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $StagingFolder | Out-Null

    robocopy $Folder.FullName $StagingFolder /E /NFL /NDL /NJH /NJS | Out-Null

    # ----------------------------------------------------------
    # Filtrar POR SUBPASTA, não pelo total combinado
    # ----------------------------------------------------------
    #
    # Uma pasta de driver (ex: "NVIDIA") pode ter várias subpastas
    # (Display.Driver, HDAudio, PhysX, NVI2...), cada uma com seus
    # PRÓPRIOS .inf e IDs de hardware completamente diferentes entre
    # si (o áudio HDMI não usa o mesmo DEV_ID da placa de vídeo). Se a
    # gente filtrasse pelo total combinado, o filtro do modelo de GPU
    # (ex: "3090") apagaria também os .inf de áudio/PhysX por engano,
    # já que eles nunca vão bater com o nome "3090" - eles são de
    # outro tipo de hardware. Por isso o filtro roda separado, uma vez
    # por subpasta que tenha .inf direto nela.

    if ($Global:TrimMode -ne "Off") {

        $Leaves = $InfFiles | Group-Object { $_.DirectoryName }

        foreach ($Leaf in $Leaves) {

            $LeafPathRelative = $Leaf.Name.Substring($Folder.FullName.Length).TrimStart('\')
            $LeafName = if ($LeafPathRelative) { $LeafPathRelative } else { $Folder.Name }

            $LeafStagingDir = Join-Path $StagingFolder $LeafPathRelative

            $LeafInfs = Get-ChildItem $LeafStagingDir -Filter *.inf -ErrorAction SilentlyContinue

            if (!$LeafInfs -or $LeafInfs.Count -le $Global:TrimThreshold) {
                continue
            }

            if ($Global:TrimMode -eq "Ask") {

                $Kept = Invoke-InfFilterByModel -LeafInfs $LeafInfs -LeafName $LeafName

            }
            elseif ($Global:TrimMode -eq "Auto") {

                $HostDeviceIds = (Get-CimInstance Win32_PNPEntity -ErrorAction SilentlyContinue).PNPDeviceID |
                    ForEach-Object { if ($_ -match "DEV_([0-9A-Fa-f]{4})") { $Matches[1] } } |
                    Select-Object -Unique

                if ($HostDeviceIds -and $HostDeviceIds.Count -gt 0) {

                    $Pattern = ($HostDeviceIds | ForEach-Object { "DEV_$_" }) -join "|"

                    $Kept = @($LeafInfs | Where-Object {
                        Select-String -Path $_.FullName -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue
                    })

                    if ($Kept.Count -eq 0) {
                        Write-Log "'$LeafName': nenhum .inf bate com o hardware desta máquina. Mantendo todos os $($LeafInfs.Count)." "WARNING"
                        $Kept = $LeafInfs
                    }
                    else {
                        Write-Log "'$LeafName': filtrado pro hardware desta máquina ($($Kept.Count) de $($LeafInfs.Count) .inf mantidos)." "SUCCESS"
                    }

                }
                else {
                    Write-Log "Não foi possível detectar IDs de hardware desta máquina. Mantendo todos os $($LeafInfs.Count) .inf de '$LeafName'." "WARNING"
                    $Kept = $LeafInfs
                }

            }
            else {
                $Kept = $LeafInfs
            }

            $ToRemove = $LeafInfs | Where-Object { $Kept.FullName -notcontains $_.FullName }

            foreach ($Rem in $ToRemove) {
                Remove-Item $Rem.FullName -Force
            }

        }

    }

    $StagingInfFiles = Get-ChildItem $StagingFolder -Filter *.inf -Recurse -ErrorAction SilentlyContinue

    Write-Log "Injetando driver: $($Folder.Name) ($($StagingInfFiles.Count) .inf encontrado(s))"

    & $DismPath /Image:"$MountPath" /Add-Driver /Driver:"$StagingFolder" /Recurse

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Driver '$($Folder.Name)' injetado com sucesso." "SUCCESS"
        $SuccessCount++
    }
    else {
        Write-Log "Falha ao injetar driver '$($Folder.Name)' (código $LASTEXITCODE)." "ERROR"
        $FailCount++
    }

    Remove-Item $StagingFolder -Recurse -Force -ErrorAction SilentlyContinue

}

if ($FailCount -gt 0) {
    Write-Log "$FailCount driver(s) falharam ao injetar." "ERROR"
    Set-Summary "Drivers" "$SuccessCount ok, $FailCount falharam"
    exit 1
}

Write-Log "Injeção de drivers concluída." "SUCCESS"
Set-Summary "Drivers" "$SuccessCount driver(s) injetado(s)"
exit 0
