# StudyTime iOS

Native SwiftUI port of the Study Time Tracker. Data is stored on-device with **SwiftData** (replaces PostgreSQL). Timer and stats logic match the web/Django app: timestamp-based sessions and America/Chicago day allocation.

## Requirements

- Xcode 16+ (iOS 17.0 deployment target)
- macOS with Apple Silicon or Intel

## Open & run (Xcode)

1. Open the project:
   ```bash
   cd ios
   open StudyTime.xcodeproj
   ```
2. At the top of Xcode, click the device menu (next to **StudyTime**).
3. Choose a simulator, e.g. **iPhone 16 Pro**.
4. Press the **Play** button (or ⌘R).

The Simulator app should open and Study Time should appear.

### Run from Terminal (optional)

```bash
cd ios
xcodebuild -scheme StudyTime \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
  -derivedDataPath ./DerivedData build
xcrun simctl install booted ./DerivedData/Build/Products/Debug-iphonesimulator/StudyTime.app
xcrun simctl launch booted com.studytime.app
open -a Simulator
```

If you change `project.yml`, regenerate the Xcode project:

```bash
cd ios && xcodegen generate
```

## Features retained

- Study timer: Start / Pause / Resume / Stop
- Topic picker (locked while running), create, rename
- Lifetime Total + Today (Chicago timezone)
- Per-topic breakdown
- Monthly calendar with topic dots, minutes, ✓/✗ (>10 minutes)
- Week chart (last 7 days)
- Light / dark theme (UserDefaults)

## Storage mapping

| Web (PostgreSQL) | iOS |
|------------------|-----|
| `topics` table | SwiftData `Topic` |
| `study_sessions` table | SwiftData `StudySession` |
| `localStorage.theme` | `UserDefaults` key `theme` |

No backend or network required — fully offline.

## Project layout

```
ios/
  StudyTime.xcodeproj
  project.yml                 # xcodegen spec
  StudyTime/
    StudyTimeApp.swift
    Models/                   # Topic, StudySession
    Services/                 # Timer + statistics
    Utilities/                # Chicago time, formatting
    Views/                    # Timer, calendar, topics, chart
    Theme/
    Assets.xcassets/
```
