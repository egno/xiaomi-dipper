# Port status: Ubuntu Touch 20.04 (Focal) on Xiaomi Mi 8 (dipper)

Last checked: 2026-10-16, branch `focal/port-bootstrap`, local build flashed to `system`.

## Hardware

| Area | State |
|---|---|
| Display / Lomiri | Works. Lomiri is the only Mir compositor, runs as phablet in a logind session. UI scale correct (GridUnit 21, Mir output scale 2.625). |
| Touch | Works (`MIR_SERVER_CONSOLE_PROVIDER=none`, evdev opened directly). |
| Power button | Works through `dipper-lsc-shim`, a USC D-Bus stand-in for repowerd. |
| Wi-Fi | Works (connects to WPA networks). |
| Time | NTP sync via systemd-timesyncd. |
| Modem | Both RIL modems online and powered in ofono. Calls and SMS not yet tested. |
| Audio | PulseAudio up with `sink.primary_output` (droid card) as default. Playback not yet tested. |
| Bluetooth | `hci0` up. Pairing not yet tested. |
| Sensors | Android sensors HAL runs; rotation events reach qtmir. |
| ADB on booted system | Works (usb-moded with `extcon_tracking=0`, plus a `/userdata/.force-adb` marker). |
| **Suspend** | **Broken**: `systemd-suspend` fails with `Device or resource busy`. |

## Known issues

1. Suspend fails (EBUSY); the phone never sleeps.
2. repowerd floods the log with `NoSessionForPID` for the Lomiri processes.
3. upowerd: `energy_full_design` is 0.
4. Failed units: `systemd-backlight@backlight:panel0-backlight`; `usb-moded-ssh` gets killed during first-boot host-key generation.
5. usb-moded still runs with `-D` (debug).

## Build and flash

```bash
./build-in-podman.sh --flashable            # out/boot.img, recovery.img, system.img
./build-mir-android2-in-podman.sh --install # patched Mir android platform into the overlay
fastboot flash system out/system.img        # usual iteration: system only
```

- The UI size comes from the Mir output scale (GridUnit / 8), which needs the
  patched `graphics-android2.so.15` (`patches/mir-android2-initial-display-policy.patch`).
  Check the `qtmir.screens: PlatformScreen ... scale:` line in the journal before
  changing GridUnit.
- Device systemd units go in `overlay/system/lib/systemd/system` (overlay-merged,
  read-only). Don't mark `etc/systemd/system` for merging: that hides the writable
  userdata copy, so `systemctl enable`, `timedatectl set-ntp`, and first-boot units
  fail with "Read-only file system" (clock stuck in 1970, TLS failures).
- The kernel needs `CONFIG_OVERLAY_FS` (`kernel.config`); without it the device
  overlay in `/opt/halium-overlay` fails to mount and the boot ends on a black screen.
- If the system won't boot to a shell, RAM-boot TWRP to pull logs.
