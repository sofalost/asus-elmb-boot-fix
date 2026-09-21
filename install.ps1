# Install enable_elmb.ps1 so it runs at every logon.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#
# The script itself is copied to %USERPROFILE%\Tools\elmb and launched at logon
# through a tiny wscript shim dropped in the user's Startup folder (no console
# window flashing, no admin rights, nothing registered machine-wide).

param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'

$TargetDir = Join-Path $env:USERPROFILE 'Tools\elmb'
$TargetPs1 = Join-Path $TargetDir 'enable_elmb.ps1'
$Startup   = [Environment]::GetFolderPath('Startup')
$VbsPath   = Join-Path $Startup 'elmb.vbs'
$Source    = Join-Path $PSScriptRoot 'enable_elmb.ps1'

if ($Uninstall) {
    Remove-Item $VbsPath -Force -ErrorAction SilentlyContinue
    Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $VbsPath and $TargetDir"
    return
}

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
Copy-Item $Source $TargetPs1 -Force

# wscript shim: window style 0 = hidden, bWaitOnReturn = False.
$launcher = 'CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' +
            $TargetPs1 + '", 0, False'
Set-Content -Path $VbsPath -Value $launcher -Encoding ASCII

Write-Host "Installed:"
Write-Host "  script  : $TargetPs1"
Write-Host "  startup : $VbsPath"
Write-Host ""
Write-Host "Enabling ELMB now (first run, may take up to ~45 s)..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TargetPs1
Write-Host "Done. Log: $env:LOCALAPPDATA\elmb_boot.log"
