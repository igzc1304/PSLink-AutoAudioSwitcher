# Verification checklist

## Evidence from the original prototype

On one Windows 11 PC with Sony PULSE Elite and PS Link USB adapter VID_054C&PID_0ECC:

- The initial feature report 0x82 read returned 82-00-00-00 when off and 82-01-10-0F when on.
- A 45-sample test returned 15/15 ON (82-01-10-0F), 15/15 OFF (82-01-20-0F), and 15/15 ON.
- The original PowerShell monitor successfully switched between PlayStation Link and Realtek playback, including during YouTube playback.
- The original hidden scheduled task was reported Running and switched sound without an open console.

**These observations do not constitute a regression test of the refactored public code or installer.**

## Before a stable release

- [ ] Test the public monitor without -Apply for repeated connection changes.
- [ ] Verify the public -Apply mode during audio playback.
- [ ] Verify playback-device matching on other Windows languages.
- [ ] Verify ambiguous/unavailable devices are rejected.
- [ ] Install from a non-elevated, 64-bit Windows PowerShell 5.1 session.
- [ ] Check current-user task with limited privileges and hidden window.
- [ ] Reboot and confirm autostart still switches outputs correctly.
- [ ] Uninstall and verify only the project's task is removed.
- [ ] Test sleep/resume, USB unplug/replug, and rapid power toggles.
- [ ] Test other speaker outputs and another Windows PC.

Never post personal usernames, private logs, full USB instance paths, hardware serials, or secrets in public bug reports.
