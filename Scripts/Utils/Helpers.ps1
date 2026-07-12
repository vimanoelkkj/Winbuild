# ==========================================================
# Windows Mod - Helpers
# ==========================================================

# ----------------------------------------------------------
# Verifica se o PowerShell está como Administrador
# ----------------------------------------------------------

function Test-Administrator {

    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

}

# ----------------------------------------------------------
# Limpa uma pasta
# ----------------------------------------------------------

function Clear-Folder {

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        return
    }

    Get-ChildItem $Path -Force |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

}

function Remove-ReadOnlyAttributes {

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    attrib -R "$Path\*" /S /D

}

# ----------------------------------------------------------
# Caminho do install.wim
# ----------------------------------------------------------

function Get-InstallWim {

    return Join-Path $ExtractPath "sources\install.wim"

}

# ----------------------------------------------------------
# Caminho do boot.wim
# ----------------------------------------------------------

function Get-BootWim {

    return Join-Path $ExtractPath "sources\boot.wim"

}

# ----------------------------------------------------------
# Verifica se a ISO já foi extraída
# ----------------------------------------------------------

function Test-ExtractedISO {

    return (Test-Path (Get-InstallWim))

}

# ----------------------------------------------------------
# Verifica se existe imagem montada
# ----------------------------------------------------------

function Test-MountedImage {

    $Result = & $DismPath /Get-MountedImageInfo 2>$null

    return ($Result -match [regex]::Escape($MountPath))

}

# ----------------------------------------------------------
# Registra o resultado de uma etapa pro resumo final do Build.ps1
# (usa $Global: pra sobreviver entre as chamadas "& $ScriptPath",
# já que todas rodam no mesmo processo/sessão do PowerShell)
# ----------------------------------------------------------

function Set-Summary {

    param(
        [Parameter(Mandatory)]
        [string]$Step,

        [Parameter(Mandatory)]
        [string]$Result
    )

    if (!$Global:BuildSummary) {
        $Global:BuildSummary = [ordered]@{}
    }

    $Global:BuildSummary[$Step] = $Result

}

# ----------------------------------------------------------
# Lê um autounattend.xml e devolve os achados organizados por
# categoria (Disco, Conta, Instalação, Segurança, Privacidade,
# Microsoft Edge, Aplicativos, Sistema). Cada item tem um nível:
# "warn" (✔ ⚠ - merece atenção) ou "ok" (✔ - normal/esperado).
#
# Retorna um [ordered] hashtable: Categoria -> array de
# @{ Text = "..."; Level = "ok"|"warn" }
# ----------------------------------------------------------

function Get-UnattendSummary {

    param(
        [Parameter(Mandatory)]
        [string]$XmlPath
    )

    $Content = Get-Content $XmlPath -Raw

    $Categories = [ordered]@{}

    function Add-Finding {
        param([string]$Category, [string]$Text, [string]$Level = "ok")
        if (!$Categories.Contains($Category)) {
            $Categories[$Category] = @()
        }
        $Categories[$Category] += [PSCustomObject]@{ Text = $Text; Level = $Level }
    }

    function Get-NodeTexts {
        param([string]$Name)
        $Result = Select-Xml -Content $Content -XPath "//*[local-name()='$Name']" -ErrorAction SilentlyContinue
        if ($Result) {
            return @($Result | ForEach-Object { $_.Node.InnerText })
        }
        return @()
    }

    # ----- Disco -----

    if ((Get-NodeTexts "WillWipeDisk") -contains "true") {
        Add-Finding "Disco" "Apaga o disco por completo - todos os dados existentes serão perdidos" "warn"
    }

    # ----- Conta -----

    $ComputerName = Get-NodeTexts "ComputerName"
    if ($ComputerName.Count -gt 0 -and $ComputerName[0]) {
        Add-Finding "Conta" "Nome do computador: $($ComputerName[0])" "ok"
    }

    $Accounts = Select-Xml -Content $Content -XPath "//*[local-name()='LocalAccount']" -ErrorAction SilentlyContinue
    foreach ($Acc in $Accounts) {

        $Name  = ($Acc.Node.ChildNodes | Where-Object { $_.LocalName -eq 'Name' }).InnerText
        $Group = ($Acc.Node.ChildNodes | Where-Object { $_.LocalName -eq 'Group' }).InnerText

        if ($Name) {
            Add-Finding "Conta" "Cria a conta local '$Name' (grupo: $Group)" "ok"
        }

        $PasswordValueNode = $Acc.Node.SelectNodes(".//*[local-name()='Password']/*[local-name()='Value']") | Select-Object -First 1

        if ($PasswordValueNode -and [string]::IsNullOrEmpty($PasswordValueNode.InnerText)) {
            Add-Finding "Conta" "Conta '$Name' será criada SEM SENHA" "warn"
        }

    }

    $AutoLogonNode = Select-Xml -Content $Content -XPath "//*[local-name()='AutoLogon']" -ErrorAction SilentlyContinue
    if ($AutoLogonNode) {
        $Enabled = ($AutoLogonNode.Node.ChildNodes | Where-Object { $_.LocalName -eq 'Enabled' }).InnerText
        $User    = ($AutoLogonNode.Node.ChildNodes | Where-Object { $_.LocalName -eq 'Username' }).InnerText
        if ($Enabled -eq "true") {
            Add-Finding "Conta" "AutoLogon: $User (entra sem pedir senha no boot)" "warn"
        }
    }

    # ----- Instalação -----

    if ((Get-NodeTexts "ProductKey").Count -gt 0) {
        Add-Finding "Instalação" "Aplica uma chave de produto automaticamente" "ok"
    }

    if ((Get-NodeTexts "HideEULAPage") -contains "true") {
        Add-Finding "Instalação" "Aceita EULA automaticamente" "ok"
    }

    if ((Get-NodeTexts "HideOnlineAccountScreens") -contains "true") {
        Add-Finding "Instalação" "Pula tela de login com conta Microsoft (força conta local)" "ok"
    }

    if ((Get-NodeTexts "HideWirelessSetupInOOBE") -contains "true") {
        Add-Finding "Instalação" "Pula configuração de Wi-Fi" "ok"
    }

    $FirstLogon = Select-Xml -Content $Content -XPath "//*[local-name()='FirstLogonCommands']//*[local-name()='CommandLine']" -ErrorAction SilentlyContinue
    if ($FirstLogon) {
        Add-Finding "Instalação" "Executa $(@($FirstLogon).Count) comando(s) automático(s) no primeiro logon" "ok"
    }

    # ----- Segurança -----

    $RunSync = Select-Xml -Content $Content -XPath "//*[local-name()='RunSynchronousCommand']" -ErrorAction SilentlyContinue
    if ($RunSync) {
        $Paths = $RunSync | ForEach-Object { ($_.Node.ChildNodes | Where-Object { $_.LocalName -eq 'Path' }).InnerText }
        if ($Paths -match "BypassTPMCheck|BypassSecureBootCheck|BypassRAMCheck|LabConfig") {
            Add-Finding "Segurança" "Pula verificação de TPM/Secure Boot/RAM (Windows 11 em hardware não suportado)" "warn"
        }
    }

    # ----------------------------------------------------------
    # unattend-generator (schneegans.de) - o site guarda TODAS as
    # opções marcadas dentro de um comentário no topo do arquivo,
    # como parâmetros de URL. Cobre a maioria das ações reais, que
    # de outro jeito ficariam escondidas dentro de scripts
    # PowerShell embutidos (não em tags XML padrão).
    # ----------------------------------------------------------

    if ($Content -match 'unattend-generator/\?([^\r\n]*?)-->') {

        $QueryString = $Matches[1]

        $Options = @{}

        foreach ($Pair in ($QueryString -split '&')) {

            if (!$Pair) { continue }

            $Parts = $Pair -split '=', 2
            $Key   = $Parts[0]
            $Value = if ($Parts.Count -gt 1) { [System.Net.WebUtility]::UrlDecode($Parts[1]) } else { "" }

            if ($Key) {
                $Options[$Key] = $Value
            }

        }

        function Test-Opt {
            param([string]$Key, [string]$ExpectedValue = "true")
            return ($Options.ContainsKey($Key) -and $Options[$Key] -eq $ExpectedValue)
        }

        $KnownKeys = @()

        # Segurança
        if (Test-Opt "DisableSystemRestore") {
            Add-Finding "Segurança" "Desativa a Restauração do Sistema (System Restore)" "warn"
        }
        $KnownKeys += "DisableSystemRestore"

        if (Test-Opt "PreventDeviceEncryption") {
            Add-Finding "Segurança" "Desativa BitLocker / criptografia de dispositivo" "warn"
        }
        $KnownKeys += "PreventDeviceEncryption"

        if (Test-Opt "DisableSmartScreen") {
            Add-Finding "Segurança" "Desativa o Windows SmartScreen" "warn"
        }
        $KnownKeys += "DisableSmartScreen"

        if ($Options.ContainsKey("CoreIsolationMode") -and $Options["CoreIsolationMode"] -eq "Enabled") {
            Add-Finding "Segurança" "Ativa Isolamento de Núcleo / Integridade de Memória" "ok"
        }
        elseif ($Options.ContainsKey("CoreIsolationMode") -and $Options["CoreIsolationMode"] -eq "Disabled") {
            Add-Finding "Segurança" "Desativa Isolamento de Núcleo / Integridade de Memória" "warn"
        }
        $KnownKeys += "CoreIsolationMode"

        if (Test-Opt "PasswordExpirationMode" "Unlimited") {
            Add-Finding "Segurança" "Senha da conta configurada para nunca expirar" "warn"
        }
        $KnownKeys += "PasswordExpirationMode"

        if (Test-Opt "LockoutMode" "Disabled") {
            Add-Finding "Segurança" "Desativa bloqueio de conta por tentativas de senha erradas" "warn"
        }
        $KnownKeys += "LockoutMode"

        # Privacidade
        if (Test-Opt "DisableBingResults") {
            Add-Finding "Privacidade" "Desativa resultados do Bing na busca do Windows" "ok"
        }
        $KnownKeys += "DisableBingResults"

        if (Test-Opt "DisableAppSuggestions") {
            Add-Finding "Privacidade" "Desativa sugestões de apps" "ok"
        }
        $KnownKeys += "DisableAppSuggestions"

        if (Test-Opt "ExpressSettings" "DisableAll") {
            Add-Finding "Privacidade" "Desativa todas as configurações expressas de telemetria/privacidade" "ok"
        }
        $KnownKeys += "ExpressSettings"

        # Microsoft Edge
        if (Test-Opt "MakeEdgeUninstallable") {
            Add-Finding "Microsoft Edge" "Torna o Edge desinstalável" "ok"
        }
        $KnownKeys += "MakeEdgeUninstallable"

        if (Test-Opt "HideEdgeFre") {
            Add-Finding "Microsoft Edge" "Pula tela de boas-vindas do Edge (primeiro boot)" "ok"
        }
        $KnownKeys += "HideEdgeFre"

        if (Test-Opt "DisableEdgeStartupBoost") {
            Add-Finding "Microsoft Edge" "Desativa inicialização em segundo plano do Edge" "ok"
        }
        $KnownKeys += "DisableEdgeStartupBoost"

        if (Test-Opt "DeleteEdgeDesktopIcon") {
            Add-Finding "Microsoft Edge" "Remove atalho do Edge da área de trabalho" "ok"
        }
        $KnownKeys += "DeleteEdgeDesktopIcon"

        # Sistema
        if (Test-Opt "EnableLongPaths") {
            Add-Finding "Sistema" "Ativa suporte a caminhos de arquivo longos (>260 caracteres)" "ok"
        }
        $KnownKeys += "EnableLongPaths"

        if (Test-Opt "DeleteWindowsOld") {
            Add-Finding "Sistema" "Apaga a pasta Windows.old (sem opção de reverter depois)" "warn"
        }
        $KnownKeys += "DeleteWindowsOld"

        if (Test-Opt "DisablePointerPrecision") {
            Add-Finding "Sistema" "Desativa a precisão de ponteiro do mouse" "ok"
        }
        $KnownKeys += "DisablePointerPrecision"

        # Aplicativos - todas as chaves RemoveXxx=true, agrupadas
        $RemovedKeys = @($Options.Keys | Where-Object { $_ -like "Remove*" -and $Options[$_] -eq "true" })

        if ($RemovedKeys.Count -gt 0) {
            $RemovedNames = $RemovedKeys | ForEach-Object { $_ -replace '^Remove', '' }
            Add-Finding "Aplicativos" "Remove $($RemovedKeys.Count) componentes nativos: $($RemovedNames -join ', ')" "ok"
        }

        $KnownKeys += $RemovedKeys

        # Qualquer opção "=true" que não foi classificada acima
        $OtherTrue = @($Options.Keys | Where-Object { $Options[$_] -eq "true" -and $KnownKeys -notcontains $_ })

        if ($OtherTrue.Count -gt 0) {
            Add-Finding "Outros" "Opções adicionais ativadas: $($OtherTrue -join ', ')" "ok"
        }

    }

    return $Categories

}