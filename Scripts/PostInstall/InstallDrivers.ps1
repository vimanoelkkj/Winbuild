$Log = "C:\Windows-Mod\PostInstall.log"

function Log {
    param([string]$Message)
    "[$(Get-Date -Format 'HH:mm:ss')] $Message" | Tee-Object -FilePath $Log -Append
}

Log "PostInstall iniciado."

$AMD = Get-ChildItem "C:\Windows-Mod\Installers\AMD-Chipset" -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1

if ($AMD) {
    Log "Instalando AMD Chipset: $($AMD.Name)"
    Start-Process $AMD.FullName -ArgumentList "/S" -Wait
    Log "AMD Chipset finalizado."
}
else {
    Log "AMD Chipset nao encontrado."
}

Log "PostInstall finalizado."