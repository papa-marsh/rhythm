# Rhythm

iOS app (SwiftUI + SwiftData + CloudKit): a self-populating to-do list for recurring tasks. Recurring definitions ("cadences") auto-generate their next occurrence ("beat") when one is completed or skipped — scheduled relative to completion or to a fixed due date — and beats only surface when they enter their "grace period" window before due.

## Source of truth

`design_handoff_rhythm/` is the **complete, locked design spec**:

- `README.md` — vocabulary, business logic (scheduling math, grace derivation, urgency tiers), every screen, exact design tokens, locked decisions. Read it before touching any feature.
- `design_files/` — a runnable React-in-browser prototype (open `Rhythm.html`). It is the reference for layout, copy, interaction, and logic — **not** code to port literally. The prototype contains dead alternates (Ring/Tint urgency styles, Wizard/Cards forms, action-sheet beat actions): ignore them; Bar urgency, Swipe actions, and the Single form are locked.

Where the spec's 2023-era chrome conflicts with iOS 26's native design language, native wins: keep the spec's structure, copy, colors, and semantics exact, but render with current native components. Don't recreate old chrome.

## Domain model (core invariants)

- **Cadence** → has at most **one active Beat** at any time (enforced in the store layer, not the schema). Completing/skipping a beat appends a history entry and generates the next beat: Relative (`schedule: relative`) → next due = today + interval; Fixed (`fixed`) → next due = previous due + interval.
- **Month/year intervals are anchor-day-preserving**: store the original `anchorDay` and clamp to target month length each cycle. Never derive from the previously-clamped date.
- **Beat** — may be standalone (no cadence). Identity fields (name/color/glyph) are *copied* from the cadence at generation; editing a beat never edits its cadence.
- **Grace** — days before due that a beat starts mattering. Derived `0.85·√freqDays` (see spec), user-editable. Drives Today-list visibility, notification timing, and snooze length.
- **Snooze** — sets `snoozedUntil`; while in the future, it *is* the effective due date for urgency, sorting, badge, and notifications. The beat stays visible.
- **Beats are due on a day, never a time.** All due-date math is day-granularity; notification time only controls reminder delivery.
- "Today" is live app state (re-evaluated at midnight/foreground), never cached.

## Architecture

- `Rhythm/Rhythm/Core/` — **RhythmCore**: pure logic (frequency, schedule math, grace, urgency tiers, relative-date formatting). No UI, no SwiftData imports. All spec math lives here and is unit-tested against the spec's examples.
- `Rhythm/Rhythm/Models/` + store — SwiftData models mirrored to CloudKit (private DB, container `iCloud.marshallwarners.RhythmData`). **CloudKit rules: every property has a default or is optional; relationships optional with explicit inverses; no unique constraints.** All writes go through the store, which triggers notification/badge replanning.
- Services — notification scheduler (reminders + silent midnight badge-only notifications, prioritized within iOS's 64-pending-notification cap; badge = count of beats with effective due ≤ today) and day-rollover ticking.
- UI — SwiftUI, 4 tabs (Today, Cadences, Discovery, Settings). Settings persist via `@AppStorage`, local-only by design.

## Commands

```bash
# Build (from repo root)
xcodebuild -project Rhythm/Rhythm.xcodeproj -scheme Rhythm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Unit tests (Swift Testing framework)
xcodebuild -project Rhythm/Rhythm.xcodeproj -scheme Rhythm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

- Xcode 26.5, iOS deployment target 26.5, team `UJFW53692H`, bundle `marshallwarners.Rhythm`.
- Seed/sample data is DEBUG/preview-only; production starts empty.
- Commit at stage/feature boundaries; the design handoff directory is read-only reference material.
