# Dewby (native iOS) — Milestone 1

SwiftUI + SwiftData rebuild of the Hydrate web app. iOS 18+, bundle ID `com.mikejohnson.hydrate` (unchanged so users/reviews carry over), display name **Dewby**.

## Setup (Mac, Xcode 26, macOS Tahoe)
1. `brew install xcodegen`
2. `cd ios-native && xcodegen` → generates `Dewby.xcodeproj`
3. `open Dewby.xcodeproj`
4. Target **Dewby** → Signing & Capabilities → choose your Team (free Personal Team works for device testing).
5. Pick a simulator or your iPhone → Run (⌘R). Tests: ⌘U.

Re-run `xcodegen` after adding/removing files (the .xcodeproj is generated, not committed).

## What's in M1
- TabView: Today (basic total, profile switcher/goal, unit, import/export), History & Reminders (Reminders settings form; scheduling is M3).
- SwiftData: `Profile` (id, name, goalOz=108), `DrinkEntry` (amountOz, timestamp, type), `AppSettings` (unit oz/ml default oz; reminders every 2h 9:00–19:00, saved not scheduled; alert style; tone).
- `HydrateBackupCodec` (pure Foundation): imports `{active, list}` backups, the web Export button's single-profile file, and legacy `{goal, days}`; exports `{active, list}`.
- PrivacyInfo.xcprivacy: no tracking, no data collected, UserDefaults reason CA92.1.
- Fredoka (variable TTF, OFL — `Resources/Fonts/OFL.txt`) from github.com/google/fonts.

## Import notes
- The web app stores time as a display label (`"3:45 PM"`), not a timestamp. Dewby combines day key + label; unparseable labels → noon (order kept). The original label is preserved for export.
- Missing/unknown `type` → water. `oz` ≤ 0 dropped; numeric strings accepted. Profiles without `v2` get goal 108 (same as the web app does on load).
- Re-importing the same file is idempotent (duplicates skipped). Multi-profile files merge by profile id; single/legacy files merge by name.

## Reminder sounds
Alert style: **Sound**, **Vibrate only**, **Silent**; tone picker + Preview (plays tone in-app with a haptic). Default: Water drip.
iOS caveat: apps can't force a notification to vibrate. Vibration follows the user's Settings › Sounds & Haptics (and Focus/silent mode). "Vibrate only" can't be guaranteed for notifications; in-app it plays a haptic.

### Replacing tones
- All tones live in `Dewby/Resources/Sounds/` named `dewby_<name>.caf`. The current ones are synthesized placeholders (`tools/make_tones.py`), no licensing.
- The list comes from one enum, `ReminderTone` in `Dewby/Logic/ReminderSound.swift`. **To add a tone:** drop `dewby_rain.caf` in the folder and add `case rain = "dewby_rain"` plus a label. To replace one, overwrite the file with the same name.
- Notification sounds must be **.caf, .aiff, or .wav** (Linear PCM, MA4/IMA, µLaw, or aLaw) and **under 30 seconds**, or iOS plays the default sound. Keep them 1–5 s.
- Convert a Suno MP3 on a Mac:
  ```
  afconvert -f caff -d LEI16 input.mp3 dewby_drip.caf
  ```
- Trim first, e.g. keep the first 3 s with a 0.3 s fade (`brew install sox`):
  ```
  sox input.mp3 trimmed.wav trim 0 3 fade 0 3 0.3
  afconvert -f caff -d LEI16 trimmed.wav dewby_drip.caf
  ```
  (Or trim in QuickTime: Edit › Trim, then Export As Audio Only, then afconvert.) Check with `afinfo dewby_drip.caf`.
- Then run `xcodegen` again and rebuild. iOS caches notification sounds, so delete and reinstall the app if the old one still plays.

## Not yet (later milestones)
M2 Today ring/wave + log sheet, History charts; M3 notification scheduling; M4 polish/App Store.
