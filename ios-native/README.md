# Dewby (native iOS) — Milestones 1–2

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
- Fredoka (OFL — `Resources/Fonts/OFL.txt`) from github.com/google/fonts.

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

## M2 (UI per Jim's kit)
- Today: animated wave ring (ink ring, aqua wave, bubbles, slosh per log; honors Reduce Motion), coral→pink log pill (squash, sparkle burst, light haptic), quick chips + "More" → Log drink sheet (type grid + slider), streak card (only when streak ≥ 1), today's drinks (long-press to delete). Gear → Settings.
- History: month calendar (progress shading, ✓ when goal met, tap a day), 30-day stacked bar chart by drink with goal line, stats (7/30-day avg, streak, best day, goals met, all-time), drink mix.
- Settings sheet: profiles (tap circle = active, row = edit name/goal/delete), units, import/export.
- Onboarding: first launch only (`AppSettings.hasOnboarded`), name + unit + goal, or restore a Hydrate backup.
- Fredoka: static Bold/SemiBold instances generated from the OFL variable font (fontTools) because SwiftUI can't pick weights from a variable font by name. Nav titles use it via UINavigationBarAppearance.

## M2.1 (Mike's feedback)
- Today: ring, drink-type picker (Hydrating: Water, Soda, Juice, Energy drink, Smoothie, Other · Dehydrating: Coffee, Espresso, Latte, Tea, Alcohol), amount slider 4–40 oz in 4 oz steps (default 8; ml mode shows converted values), "Log N oz" pill. Drink list moved to History (top, today/selected day, long-press to delete).
- Net hydration: `DrinkType.hydrationFactor` in `Logic/HydrateBackup.swift` is the ONE table. **All values are placeholders pending research**: hydrating 1.0, coffee −0.5, espresso −1.5, latte −0.25, tea −0.25, alcohol −1.0. Ring, calendar, streak and stats use daily net (clamped at 0); entry rows, chart and drink mix show raw amounts.
- Legacy `sports` (web app / M1 data) reads as Energy drink and is written back as `sports` so the web app can show it. Espresso/latte/tea/alcohol/other are new types the web app doesn't know (it would fail to label them).

## Launch
- `Dewby/App/LaunchScreen.storyboard` (Info.plist `UILaunchStoryboardName` = LaunchScreen) shows **IntroBackground** (Jim's `launch_static`, gradient + glow, no text) full-bleed with aspect-fill, on a coral fallback. Jim's notes recommend this because `UILaunchScreen` can't scale an image to fill the screen.
- `Views/IntroView.swift` follows Jim's MOTION_NOTES timeline: icon spring at 0.10 s, ripples at 0.30/0.45 s, sparkles at 0.55–0.79 s, "Dewby" (Fredoka Bold 64) at 0.65 s, tagline "Make every sip count" (Fredoka Medium 20) at 0.85 s, a soft haptic at 0.45 s, then a 0.3 s crossfade with scale 1.04 at 1.5 s. Reduce Motion: everything fades in over 250 ms, holds to 0.8 s, then a 0.2 s fade. Turn the tagline off with `IntroView.showTagline`.
- Still seeing an old launch screen? Delete the app, then Clean Build Folder (iOS caches launch screens).

## Not yet (later milestones)
M3 notification scheduling; M4 polish/App Store.
