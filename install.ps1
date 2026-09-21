# Install enable_elmb.ps1 so it runs at every logon.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#
# The scripts are copied to %USERPROFILE%\Tools\elmb and launched at logon
# through a tiny wscript shim dropped in the user's Startup folder (no console
# window flashing, no admin rights, nothing registered machine-wide).

param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'

$TargetDir = Join-Path $env:USERPROFILE 'Tools\elmb'
$Startup   = [Environment]::GetFolderPath('Startup')
$VbsPath   = Join-Path $Startup 'elmb.vbs'

if ($Uninstall) {
    Remove-Item $VbsPath -Force -ErrorAction SilentlyContinue
    Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $VbsPath and $TargetDir"
    return
}

# Refuse to install where the monitor does not expose 0xEE at all.
Write-Host "Checking monitors..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probe.ps1')
if ($LASTEXITCODE -eq 2) {
    Write-Host ""
    Write-Host "Install aborted: no monitor implements VCP 0xEE." -ForegroundColor Yellow
    return
}

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
foreach ($f in 'enable_elmb.ps1', 'ddc.ps1', 'probe.ps1') {
    Copy-Item (Join-Path $PSScriptRoot $f) (Join-Path $TargetDir $f) -Force
}

$TargetPs1 = Join-Path $TargetDir 'enable_elmb.ps1'

# wscript shim: window style 0 = hidden, bWaitOnReturn = False.
$launcher = 'CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' +
            $TargetPs1 + '", 0, False'
Set-Content -Path $VbsPath -Value $launcher -Encoding ASCII

Write-Host ""
Write-Host "Installed:"
Write-Host "  scripts : $TargetDir"
Write-Host "  startup : $VbsPath"
Write-Host ""
Write-Host "Enabling ELMB now (first run, may take up to ~45 s)..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TargetPs1
Write-Host "Done. Log: $env:LOCALAPPDATA\elmb_boot.log"
