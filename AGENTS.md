# Host development constraints

This laptop runs Pop!_OS 24.04 LTS with the COSMIC desktop. On October 30,
2026, the user reported loss of mouse pointing and desktop instability after
visible Android emulator testing. The emulator had warned of possible GPU
driver problems. Root cause is unconfirmed; compositor log errors alone do
not prove an emulator or driver defect.

- Do not launch or automatically restart an Android emulator on this host
  unless the user explicitly requests an emulator compatibility test after
  this incident. This includes headless emulators; they are not yet verified
  as safe following the incident.
- Use static analysis, unit/widget tests and APK builds for routine checks.
  Use an explicitly selected, user-connected physical Android device for
  device checks when available.
- Do not change GPU drivers, display settings or restart the desktop as part
  of app development. Investigate host compatibility separately with the user.
- Never leave a test emulator running after a compatibility test.
