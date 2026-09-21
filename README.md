# asus-elmb-boot-fix

Re-enable **ELMB** (Extreme Low Motion Blur) on ASUS monitors at every Windows logon, over DDC/CI.

## The problem

ASUS monitors expose ELMB as DDC/CI VCP code `0xEE` (`1` = on, `0` = off). Turning it on from the OSD or from ASUS DisplayWidget only lasts until the monitor loses power — after a cold boot, a switched-off power strip, or a long standby, ELMB comes back **off**. Windows has no setting for it, and nothing re-applies it at logon.

## What this does

`enable_elmb.ps1` enumerates the physical monitors through `EnumDisplayMonitors` + `GetPhysicalMonitorsFromHMONITOR`, then writes VCP `0xEE = 1` to **every** monitor that answers DDC/CI and reads the value back to confirm.

- Pure `dxva2.dll` / `user32.dll` P/Invoke — no external tools, no driver, no admin rights.
- Retries for up to ~45 seconds, because monitors are usually not ready to answer DDC when logon scripts fire.
- Idempotent: monitors already at `1` are left alone; the loop exits early once every monitor reads back `1`.
- Logs each attempt to `%LOCALAPPDATA%\elmb_boot.log`.

## Requirements

- Windows 10/11 (any monitor brand works, as long as the monitor implements VCP `0xEE`).
- DDC/CI **enabled in the monitor OSD** (on ASUS: *OSD Setup → DDC/CI → On*). Most ASUS monitors ship with it enabled.
- Windows PowerShell 5.1 (ships with Windows). No PowerShell modules required.

## Install

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

That copies the script to `%USERPROFILE%\Tools\elmb\`, drops `elmb.vbs` into your Startup folder, and runs the fix once so you can see it work.

### Verify

```powershell
Get-Content "$env:LOCALAPPDATA\elmb_boot.log"
```

A working run ends with `exit success=True`, and every monitor line shows `readback=1`.

### Alternative: Task Scheduler

If you prefer a delayed, non-Startup launch, register the script directly and skip `install.ps1`:

```powershell
schtasks /Create /TN "ELMB Boot" /SC ONLOGON /DELAY 0000:30 /RL LIMITED ^
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File %USERPROFILE%\Tools\elmb\enable_elmb.ps1"
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `no physical monitor found` | DDC/CI disabled in the monitor OSD, or the display is still asleep/off. |
| `readback=0` again and again | Monitor rejected the write. On several ASUS models ELMB cannot be active while Adaptive-Sync / FreeSync is on — disable it in the OSD and re-run. |
| `read failed` for a few attempts, then success | Normal: DDC is unavailable while the display wakes up. That is what the retry loop is for. |
| `read failed` on the same monitor every run | That monitor does not implement VCP `0xEE` (non-ASUS panel, DDC/CI off, or behind a KVM). It is retried 3 times, then ignored — the other monitors are still fixed. |
| Only one of two monitors fixed | Check the log — each handle is reported separately; a monitor behind a KVM or a DisplayLink dock often cannot do DDC/CI at all. |

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## License

MIT — see [LICENSE](LICENSE).
