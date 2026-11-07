# PSLink AutoAudioSwitcher

Automatic Windows playback-device switching for a **Sony PULSE Elite** connected with a **PlayStation Link USB adapter**.

Turn the headset **on** and Windows selects *PlayStation Link Adapter*. Turn it **off** and Windows switches back to your chosen speakers. The USB dongle can remain plugged in. No Bluetooth fallback, replacement USB driver, or third-party audio switcher is required.

> **Early community release / hardware-specific.** The detection logic was tested on **one** Sony USB adapter with USB ID **054C:0ECC** on Windows 11. Other adapter revisions (including **054C:0FA3**), headsets, Windows builds and audio configurations are **not tested or claimed to work**. The original monitor worked in an end-to-end manual test; the refactored public installer and configurable-device variant still need independent Windows testing. Review the code before enabling it.

## How it works

- Finds the Sony adapter's HID **COL04** interface using `setupapi.dll`.
- Reads **HID feature report `0x82`** with `HidD_GetFeature`, without replacing the Sony USB driver.
- Detects confirmed stable reports (three consecutive observations):

  | HID report prefix | Headset state |
  |---|---|
  | `82 01 10 0F` | Connected |
  | `82 01 20 0F` | Disconnected |
  | `82 00 00 00` | Disconnected (observed in a separate initial test) |

- **Unknown or failed reports do not trigger a switch.**
- Optionally changes the **default Windows playback endpoint** with the Windows PolicyConfig COM interface. This interface is undocumented and may change with Windows updates. It sets the Console, Multimedia and Communications playback roles; it never changes your microphone input device.
- Can run at sign-in through a **per-user scheduled task**. `wscript.exe` launches PowerShell without a visible console.

## Requirements

- Windows 10/11 64-bit, **Windows PowerShell 5.1 x64** (Windows 11 tested; Windows 10 unverified).
- Sony **PULSE Elite** connected via PlayStation Link USB adapter `VID_054C&PID_0ECC`.
- The official PlayStation Link Windows device/driver functioning normally.
- A separate, present Windows playback endpoint for speakers (Realtek by default, configurable).
- Normal user account, **not an elevated administrator console** for installation.

## 1. Inspect your playback endpoints

Run in regular Windows PowerShell:

```powershell
Get-PnpDevice -Class AudioEndpoint -PresentOnly |
  Where-Object { $_.InstanceId -like 'SWD\MMDEVAPI\{0.0.0.00000000}*' } |
  Select-Object FriendlyName, Status
```

Note a **unique identifying part** of each playback device name. The default values are `PlayStation Link Adapter` and `Realtek`. No localized prefix such as `Speakers` / `Lautsprecher` is required.

## 2. Safely test the monitor (no settings changed)

Download the source (GitHub **Code > Download ZIP**), extract it, inspect the `.ps1` files, then from a normal PowerShell window in the extracted folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\src\PSLink-AutoAudioSwitcher.ps1" -HeadsetNameContains 'PlayStation Link Adapter' -SpeakerNameContains 'Realtek'
```

Power on/off a few times, allowing the USB connection to settle between switches (about 15–30 seconds for initial testing). Stop with **Ctrl+C**. In this mode, the monitor **does not change audio settings**.

Only after successful testing, you may manually enable switching with `-Apply`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\src\PSLink-AutoAudioSwitcher.ps1" -Apply -HeadsetNameContains 'PlayStation Link Adapter' -SpeakerNameContains 'Realtek'
```

## 3. Optional: install invisible per-user autostart

**First close the manual monitor.** Do not run two different audio switchers at once.

Run from the extracted repository directory (non-elevated PowerShell):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -HeadsetNameContains 'PlayStation Link Adapter' -SpeakerNameContains 'Realtek'
```

The installer:

- Checks both playback endpoints are **present, ready and unambiguous**.
- Copies three local, inspected source files to `%LOCALAPPDATA%\PSLink-AutoAudioSwitcher`.
- Stores device-name preferences in a **local-only** `config.json`.
- Registers a non-elevated, **current-user** logon task called `PSLink AutoAudioSwitcher` and starts it immediately.
- Starts monitoring after roughly 12 seconds, without a visible console. No network access, downloads, new drivers, services, or admin privileges are needed.
- Refuses to overwrite unrelated tasks and refuses to run alongside an enabled task named `PSLink Audio Automatik` from the earlier experimental version.

**Important for the original tester:** If your old `PSLink Audio Automatik` task is still in use, keep it running until you are happy with this new version. To try the new installer, first stop and disable the old task, then run the new installer. Do **not** delete the original task until the replacement has passed a reboot test.

```powershell
Stop-ScheduledTask -TaskName 'PSLink Audio Automatik' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'PSLink Audio Automatik'
```

Check the new task and local logs:

```powershell
Get-ScheduledTask -TaskName 'PSLink AutoAudioSwitcher' | Select-Object TaskName, State
Get-Content "$env:LOCALAPPDATA\PSLink-AutoAudioSwitcher\last-run.log" -Tail 30
```

Test audio switching during playback, then **sign out/in or reboot** to verify autostart. The scheduled task is not a service and runs only in the signed-in user's session.

## Uninstall

Run from the extracted repository directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\uninstall.ps1"
```

This stops/removes only the task owned by this project; **local configuration and logs are kept**. If desired, you can manually remove the dedicated directory at `%LOCALAPPDATA%\PSLink-AutoAudioSwitcher` after checking its contents. The uninstaller deliberately does **not** recursively delete user files.

The project never alters the Sony USB drivers or audio-device drivers, so there is no driver rollback step.

## Security and privacy

- **No telemetry, analytics, network calls, cloud dependency, credentials, or tracking.**
- No account names, per-machine device instance IDs, serial numbers, or local user paths are stored in this repository.
- The monitor uses only the adapter's public USB vendor/product IDs (not an individual adapter serial number).
- HID access is a `GetFeature` read request. It does **not** use `SetFeature`, switch USB drivers, flash firmware, or install filter drivers.
- The automatic switching targets **only Windows playback endpoints**, never the microphone; ambiguous endpoint selection causes an error rather than guessing.
- The scheduled task runs with **least privilege** as the signed-in user, not as SYSTEM or administrator.
- PowerShell `-ExecutionPolicy Bypass` applies only to the started process, not to a machine-wide execution-policy setting. **Only use a verified copy that you have reviewed.**
- Logs and user-specific configuration remain under `%LOCALAPPDATA%` and are intentionally excluded from version control.
- The underlying PolicyConfig interface is **undocumented**, so compatibility is not guaranteed. See [SECURITY.md](SECURITY.md).

## Known limitations

- Tested with exactly one older PS Link adapter revision (`054C:0ECC`), and specifically **PULSE Elite**. Adapter `054C:0FA3` is not supported by this release.
- Fast repeated reconnection can temporarily produce unknown HID reports; the script intentionally waits for a stable known state rather than guessing.
- If the dongle is unplugged/replugged or the Sony software/USB connection changes, you may need to restart the task.
- At startup and after a state transition, the monitor *selects* its configured device even if the user manually chose another output. This is intended behavior of an automatic switcher.
- Exclusive-mode audio applications may ignore the Windows default-device change until restarted.
- Source code is not code-signed, and the public refactor/installer have not yet passed external Windows hardware tests. Review files before use.

## Development and credits

The original detection work for Sony PS Link USB interfaces by **João Rodrigues (Jprnp)** helped inform this project. See [pslink-libusb](https://github.com/Jprnp/pslink-libusb), distributed under the MIT license. Its project focuses on a different driver/companion approach; this repository keeps Sony's existing driver in place. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This project is independent, unofficial, and not affiliated with Sony Interactive Entertainment, PlayStation, or Microsoft. Trademarks belong to their respective owners.

Contributions and reproducible bug reports are welcome. Please do **not** post Windows usernames, full USB instance paths, serial numbers, access tokens, or unredacted logs in public issues.

## License

MIT; see [LICENSE](LICENSE).