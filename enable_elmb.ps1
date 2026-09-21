# Enable ELMB (Extreme Low Motion Blur) on every DDC/CI-capable monitor.
#
# ASUS monitors expose ELMB as the manufacturer-specific VCP code 0xEE
# (1 = on, 0 = off). That value is not part of the VESA MCCS standard, so it is
# only guaranteed to work on models whose firmware implements it -- run
# probe.ps1 first to check yours. The setting is also not persisted by the
# monitor across a power cycle / cold boot, hence the logon task.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File enable_elmb.ps1

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'ddc.ps1')

$LogFile = Join-Path $env:LOCALAPPDATA 'elmb_boot.log'

function Log($m) {
    try {
        if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 512KB)) {
            Remove-Item $LogFile -Force
        }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $LogFile -Append -Encoding utf8
    } catch { }
}

# Retry until EVERY answering monitor reads back 1 (or we run out of attempts).
# Monitors that refuse DDC reads are retried a few times too: at logon the
# display is frequently still waking up and DDC calls fail for a few seconds.
$succeeded = $false
for ($i = 1; $i -le 15 -and -not $succeeded; $i++) {
    try {
        $ms = [DdcE]::GetMonitors()
        if ($ms.Count -eq 0) {
            Log "attempt $i no physical monitor found"
        } else {
            $pending = 0
            foreach ($m in $ms) {
                $cur = [DdcE]::ReadEe($m.handle)
                if ($cur -eq 1) {
                    Log "attempt $i [$($m.desc)] already 1"
                    continue
                }
                if ($cur -eq 9999) {
                    # A monitor that keeps refusing DDC reads does not implement
                    # 0xEE (non-ASUS panel, DDC/CI off in its OSD...). Give it
                    # three attempts, then stop waiting for it.
                    Log "attempt $i [$($m.desc)] read failed"
                    if ($i -lt 4) { $pending++ }
                    continue
                }
                $ok = [DdcE]::WriteEe($m.handle, 1)
                Start-Sleep -Milliseconds 500
                $after = [DdcE]::ReadEe($m.handle)
                Log "attempt $i [$($m.desc)] write=$ok readback=$after"
                if ($after -ne 1) { $pending++ }
            }
            if ($pending -eq 0) { $succeeded = $true }
        }
    } catch { Log "attempt $i error: $_" }
    if (-not $succeeded) { Start-Sleep -Seconds 3 }
}

Log "exit success=$succeeded"
