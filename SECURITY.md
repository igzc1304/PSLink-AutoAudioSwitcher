# Security and privacy

## Trust model

This project controls the *current user's default Windows playback device*.
It does not need administrator privileges. Do not run the installer elevated.
Do not run code copied from unofficial mirrors without examining it.

The monitor opens only the recognized Sony HID COL04 interface using the
public vendor/product IDs (`054C:0ECC`). It requests feature report `0x82`
with `HidD_GetFeature` and does not send commands that modify the adapter.

The local scheduled task runs with `RunLevel Limited`, starts only when its
user logs on, and operates entirely with local scripts. `wscript.exe` is used
only to hide a console window; it does not fetch remote code.

The project intentionally does not request secrets or upload logs. The local
`config.json` stores only audio device name fragments. The local text logs may
contain friendly names of peripherals; do not attach them to public issues
without reviewing/redacting them first.

## Boundary and limitations

- Microsoft PolicyConfig COM endpoint switching is undocumented. Unexpected
  Windows changes may break it; the project does not change Windows sound
  *input* or system drivers.
- A malformed, unreadable or unknown HID report is ignored; it must not be
  interpreted as disconnected.
- Playback targets must be unique, present Windows playback endpoint IDs.
- The monitor may continue to run after the dongle is unplugged; restart it
  after significant USB reconfiguration.
- The installer does not overwrite an unrelated scheduled task. It also
  refuses to install next to an enabled legacy `PSLink Audio Automatik` task.
- `-ExecutionPolicy Bypass` is process-scoped; it does not alter registry
  settings for the user or machine. Users should inspect the source first.
- This software has not had an independent security audit, code signing, or
  extensive cross-machine compatibility testing. Use at your own risk.

## Vulnerability reports

If you find a security issue, **do not post tokens, private logs, identifiers,
or exploit details publicly**. Contact the maintainer privately through their
GitHub profile or GitHub's private vulnerability reporting feature (if enabled).