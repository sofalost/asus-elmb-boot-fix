# asus-elmb-boot-fix

Re-enable **ELMB** (Extreme Low Motion Blur) on ASUS monitors at every Windows logon, over DDC/CI.

## The problem

On many ASUS gaming monitors ELMB is reachable through DDC/CI as VCP code `0xEE` (`1` = on, `0` = off) — the same code ASUS DisplayWidget Center uses. The monitor does **not** persist it: after a cold boot, a switched-off power strip, or a long standby, ELMB is off again. Windows has no setting for it, and nothing re-applies it at logon.

## What this does

`enable_elmb.ps1` enumerates the physical monitors through `EnumDisplayMonitors` + `GetPhysicalMonitorsFromHMONITOR`, then writes VCP `0xEE = 1` to each monitor that answers DDC/CI and reads the value back to confirm.

- Pure `dxva2.dll` / `user32.dll` P/Invoke — no external tools, no driver, no admin rights.
- Retries for up to ~45 s, because monitors are usually not ready to answer DDC when logon scripts fire.
- Idempotent: monitors already at `1` are left alone, the loop exits early once every answering monitor reads back `1`.
- Logs each attempt to `%LOCALAPPDATA%\elmb_boot.log`.

## Compatibility — read this first

`0xEE` is **not** a standard code. VESA MCCS reserves the whole `0xE0`–`0xFF` range for manufacturer-specific controls, and warns that using them outside the vendor's own software can be unpredictable. So support is per model and per firmware, not universal across ASUS monitors:

- Verified working on **ASUS ROG Swift PG27AQWP-W** (this repo's origin machine).
- ASUS firmware updates have changed DDC/CI behaviour before — e.g. PG27AQDP `MCM103` reworked DDC/CI so DisplayWidget Center could read values back correctly.
- A monitor that does not implement `0xEE` simply does not answer the read. It is retried three times, then ignored; the other monitors are still fixed.

Run the read-only probe before installing anything:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1
```

```
Physical monitors: 2

  [ROG SWIFT PG27AQWP] ELMB=1  ELMB supported (0=off, 1=on)
  [Generic Non-PnP Monitor] ELMB=n/a  no answer (VCP 0xEE)

1 of 2 monitor(s) implement VCP 0xEE.
```

`install.ps1` runs this first and aborts if no monitor answers.

### Even when `0xEE` is supported

ASUS only lets ELMB actually be *on* in specific conditions, so a write can be accepted by DDC and still leave ELMB greyed out in the OSD:

- Plain **ELMB cannot be enabled at the same time as Adaptive-Sync / FreeSync** (use ELMB *Sync* for that, on models that have it).
- ELMB is unavailable while **HDR** is active.
- ELMB only works at **fixed refresh rates** (85/100/120 Hz depending on model).

If the log shows `readback=0` run after run, fix the mode in the OSD first, then re-run.

## Requirements

- Windows 10/11.
- DDC/CI **enabled in the monitor OSD** (on ASUS: *OSD Setup → DDC/CI → On*). Enabled by default on most ASUS gaming monitors.
- Windows PowerShell 5.1 (ships with Windows). No PowerShell modules required.

## Install

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

That copies the scripts to `%USERPROFILE%\Tools\elmb\`, drops `elmb.vbs` into your Startup folder, and runs the fix once so you can see it work.

### Verify

```powershell
Get-Content "$env:LOCALAPPDATA\elmb_boot.log"
```

A clean run ends with `exit success=True`, and every supported monitor shows `readback=1`.

### Alternative: Task Scheduler

Prefer a delayed, non-Startup launch? Skip `install.ps1` and register the script directly:

```
schtasks /Create /TN "ELMB Boot" /SC ONLOGON /DELAY 0000:30 /RL LIMITED ^
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File %USERPROFILE%\Tools\elmb\enable_elmb.ps1"
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `no physical monitor found` | DDC/CI disabled in the monitor OSD, or the display is still asleep/off. |
| `no answer (VCP 0xEE)` in the probe | That model does not implement ELMB over DDC/CI. Nothing this repo can do. |
| `readback=0` every run | ELMB is greyed out by the current mode (Adaptive-Sync/FreeSync on, HDR on, wrong refresh rate). |
| `read failed` for a few attempts, then success | Normal: DDC is unavailable while the display wakes up. That is what the retry loop is for. |
| Only one of two monitors fixed | Each monitor is reported separately in the log; panels behind a KVM, a DisplayLink dock, or a headless HDMI dummy cannot do DDC/CI at all. |

## Files

| File | Role |
| --- | --- |
| `ddc.ps1` | DDC/CI P/Invoke layer, shared by the two scripts below. |
| `probe.ps1` | Read-only: reports which monitors answer VCP `0xEE`. |
| `enable_elmb.ps1` | The fix: writes `0xEE = 1` with retries. |
| `install.ps1` | Copies the scripts, adds the Startup shim, `-Uninstall` to remove. |

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## License

MIT — see [LICENSE](LICENSE).
