# Minimal DDC/CI helper over dxva2.dll, dot-sourced by enable_elmb.ps1 and probe.ps1.
#
# Provides [DdcE]::GetHandles() -> IntPtr[] of physical monitor handles, plus
# ReadEe / WriteEe for VCP code 0xEE (ASUS ELMB). ReadEe returns 9999 when the
# monitor does not answer.

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
  [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);
  [DllImport("dxva2.dll")] static extern int GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint size, [Out] PHYSICAL_MONITOR[] arr);
  [DllImport("dxva2.dll")] public static extern bool SetVCPFeature(IntPtr h, byte code, uint value);
  [DllImport("dxva2.dll")] public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr h, byte code, ref uint type, ref uint cur, ref uint max);
  public struct Mon { public IntPtr handle; public string desc; }
  public static Mon[] GetMonitors() {
    MonitorEnumProc p = new MonitorEnumProc(Cb);
    var handles = new System.Collections.Generic.List<Mon>();
    _list.Clear();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, p, IntPtr.Zero);
    foreach (var hm in _list) {
      var arr = new PHYSICAL_MONITOR[1];
      if (GetPhysicalMonitorsFromHMONITOR(hm, 1, arr) > 0) {
        Mon m; m.handle = arr[0].hPhysicalMonitor; m.desc = arr[0].desc;
        handles.Add(m);
      }
    }
    return handles.ToArray();
  }
  static bool Cb(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT r, IntPtr d) { _list.Add(hMonitor); return true; }
  public static IntPtr[] GetHandles() {
    var ms = GetMonitors();
    var hs = new IntPtr[ms.Length];
    for (int i = 0; i < ms.Length; i++) hs[i] = ms[i].handle;
    return hs;
  }
  public static bool WriteEe(IntPtr h, uint v) { return SetVCPFeature(h, 0xEE, v); }
  public static uint ReadEe(IntPtr h) { uint t=0,cur=0,max=0; if(!GetVCPFeatureAndVCPFeatureReply(h,0xEE,ref t,ref cur,ref max)) return 9999; return cur; }
}
"@
