# Sixty

A private 60-day training log for iPhone: a daily checklist, a few questions, a
note and a progress photo, with streaks, reminders and export. SwiftUI and
SwiftData, iOS 17+, no server and no third-party packages.

## Getting started

You need a Mac with Xcode 16 or later.

```sh
brew install xcodegen   # once
xcodegen                # generates Sixty.xcodeproj from project.yml
open Sixty.xcodeproj
```

The Xcode project is generated, so it isn't committed. Run `xcodegen` again
after pulling changes that add or move files.

To run on your phone with a free Apple ID: in Xcode, open the Sixty target, go
to **Signing & Capabilities**, choose your Personal Team, and change the bundle
identifier if Xcode says it's taken. A free account's build stops opening after
7 days. Plug the phone in and press Run again to re-sign it; your data stays.

Tests: **Product → Test** (⌘U) runs the `SixtyCore` tests. To run them from the
command line: `cd SixtyCore && swift test`.

## Layout

```
project.yml           XcodeGen spec
Sixty/
  App/                App entry, root view, the shared "today" value
  Features/Setup/     Three-step plan setup
  Features/Today/     Today tab: countdown, bib and ring, checklist, questions, note
  Features/Photo/     Progress-photo camera (Day 1 ghost, volume shutter) and photo slot
  Features/Progress/  Stats, the plan grid and day detail
  Features/Photos/    Photos tab: comparison (side by side or slider), timeline, viewer
  Models/             SwiftData models: Plan, Activity, Question, DayEntry
  Services/           EntryStore, PhotoStore (Documents/Photos JPEGs), NotificationScheduler; export to come
  Design/             DesignTokens.swift (colours, spacing, radii, type, motion) and shared components
  Preview/            Sample "Autumn reset" plan for SwiftUI previews
  Resources/          Assets, Barlow Condensed (SIL Open Font License)
SixtyCore/            Foundation-only logic, unit-tested:
                      DayKey, PlanCalendar, DayProgress/DayStatus, Streak,
                      PlanStats, ReminderPlanner, CSVWriter, NotificationCopy
```

## How days work

- Every entry is keyed by its **local calendar day** (`"2026-10-13"`), not by a
  timestamp. Day numbers are counted in calendar days, so month ends and the
  March/October clock changes can't shift them. `PlanCalendarTests` covers
  these.
- A day is **complete** when every activity is ticked and every non-optional
  question is answered. The photo and note are optional.
- Activities and questions are **archived, never deleted**. Each entry records
  which activities and questions were in the plan that day, so editing the
  plan later doesn't change past days.

## Reminders

The app keeps the next 14 days of reminders scheduled (iOS allows 64
pending), and rebuilds them on every open, after every save and at
midnight. Tonight's check-in is removed the moment today is complete,
and its wording follows what's still open ("Mobility and Read are still
open"). Tapping a reminder opens that day. `ReminderPlannerTests` covers
the window, completed days and clock-change days.

## Build progress

1. ✅ Project setup, models, sample data, design tokens
2. ✅ Plan setup flow
3. ✅ Today screen with checklist, questions, journal, auto-save
4. ✅ Photo capture and storage
5. ✅ Day navigation and Progress grid with streak
6. ✅ Photos timeline, Day 1 vs latest comparison and the final-day summary
7. ✅ Notifications and deep links
8. Settings, CSV and photo export
9. Light/dark and Dynamic Type polish
