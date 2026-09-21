# Report, for every physical monitor, whether it answers VCP 0xEE (ASUS ELMB).
#
# Run this before installing: it writes nothing, it only reads.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1
#
# Verdict per monitor:
#   ELMB supported        reads 0 or 1 -- enable_elmb.ps1 can drive it
#   no answer (VCP 0xEE)  does not implement 0xEE, or DDC/CI is off in its OSD

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ddc.ps1')

$ms = [DdcE]::GetMonitors()
Write-Host "Physical monitors: $($ms.Count)"
Write-Host ""

if ($ms.Count -eq 0) {
    Write-Host "No physical monitor found. Is DDC/CI enabled in the monitor OSD?"
    exit 1
}

$supported = 0
foreach ($m in $ms) {
    $cur = [DdcE]::ReadEe($m.handle)
    if ($cur -eq 9999) {
        Write-Host ("  [{0}] ELMB={1}  no answer (VCP 0xEE)" -f $m.desc, 'n/a')
    } else {
        $supported++
        Write-Host ("  [{0}] ELMB={1}  ELMB supported (0=off, 1=on)" -f $m.desc, $cur)
    }
}

Write-Host ""
Write-Host "$supported of $($ms.Count) monitor(s) implement VCP 0xEE."
if ($supported -eq 0) {
    Write-Host "This model does not expose ELMB over DDC/CI -- enable_elmb.ps1 cannot help."
    exit 2
}
