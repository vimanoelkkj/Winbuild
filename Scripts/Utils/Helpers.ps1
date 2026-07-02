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