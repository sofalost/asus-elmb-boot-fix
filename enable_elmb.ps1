# Enable ELMB (Extreme Low Motion Blur) on every DDC/CI-capable monitor.
#
# ASUS monitors expose ELMB as VCP code 0xEE (1 = on, 0 = off). The setting is
# not persisted by the monitor across a power cycle / cold boot, so it has to be
# re-applied after every logon.
#
# This script talks DDC/CI directly through dxva2.dll (SetVCPFeature /
# GetVCPFeatureAndVCPFeatureReply) and retries for up to ~45 s, because monitors
# are often not ready to answer DDC when the logon scripts fire.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File enable_elmb.ps1

$ErrorActionPreference = 'Continue'

$LogFile = Join-Path $env:LOCALAPPDATA 'elmb_boot.log'

function Log($m) {
    try {
        if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 512KB)) {
            Remove-Item $LogFile -Force
        }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $LogFile -Append -Encoding utf8
    } catch { }
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DdcE {
  public struct RECT { public int left, top, right, bottom; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct PHYSICAL_MONITOR {
    public IntPtr hPhysicalMonitor;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string desc;
  }
  [UnmanagedFunctionPointerAttribute(CallingConvention.StdCall)] public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT r, IntPtr d);
  static System.Collections.Generic.List<IntPtr> _list = new System.Collections.Generic.List<IntPtr>();
  static bool Cb(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT r, IntPtr d) { _list.Add(hMonitor); return true; }
  [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);
  [DllImport("dxva2.dll")] static extern int GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint size, [Out] PHYSICAL_MONITOR[] arr);
  [DllImport("dxva2.dll")] public static extern bool SetVCPFeature(IntPtr h, byte code, uint value);
  [DllImport("dxva2.dll")] public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr h, byte code, ref uint type, ref uint cur, ref uint max);
  public static IntPtr[] GetHandles() {
    MonitorEnumProc p = new MonitorEnumProc(Cb);
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, p, IntPtr.Zero);
    var handles = new System.Collections.Generic.List<IntPtr>();
    foreach (var hm in _list) {
      var arr = new PHYSICAL_MONITOR[1];
      if (GetPhysicalMonitorsFromHMONITOR(hm, 1, arr) > 0) handles.Add(arr[0].hPhysicalMonitor);
    }
    return handles.ToArray();
  }
  public static bool WriteEe(IntPtr h, uint v) { return SetVCPFeature(h, 0xEE, v); }
  public static uint ReadEe(IntPtr h) { uint t=0,cur=0,max=0; if(!GetVCPFeatureAndVCPFeatureReply(h,0xEE,ref t,ref cur,ref max)) return 9999; return cur; }
}
"@

# Retry until EVERY monitor reads back 1 (or we run out of attempts). Handles
# whose ELMB value cannot be read yet are retried too: at logon the display is
# frequently still waking up and DDC calls fail for the first few seconds.
$succeeded = $false
for ($i = 1; $i -le 15 -and -not $succeeded; $i++) {
    try {
        $hs = [DdcE]::GetHandles()
        if ($hs.Count -eq 0) {
            Log "attempt $i no physical monitor found"
        } else {
            $pending = 0
            foreach ($h in $hs) {
                $cur = [DdcE]::ReadEe($h)
                if ($cur -eq 1) {
                    Log "attempt $i handle $h already 1"
                    continue
                }
                if ($cur -eq 9999) {
                    # A monitor that keeps refusing DDC reads simply does not
                    # implement 0xEE (non-ASUS panel, DDC/CI off in its OSD...).
                    # Give it three attempts, then stop waiting for it.
                    Log "attempt $i handle $h read failed"
                    if ($i -lt 4) { $pending++ }
                    continue
                }
                $ok = [DdcE]::WriteEe($h, 1)
                Start-Sleep -Milliseconds 500
                $after = [DdcE]::ReadEe($h)
                Log "attempt $i handle $h write=$ok readback=$after"
                if ($after -ne 1) { $pending++ }
            }
            if ($pending -eq 0) { $succeeded = $true }
        }
    } catch { Log "attempt $i error: $_" }
    if (-not $succeeded) { Start-Sleep -Seconds 3 }
}

Log "exit success=$succeeded"
