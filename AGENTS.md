# Rhythm

Native iOS app (SwiftUI + SwiftData + CloudKit): a self-populating to-do list for recurring tasks. Recurring definitions (**cadences**) auto-generate their next occurrence (**beat**) when one is completed or skipped, and beats only surface when they enter their **grace period** — the window before due in which a task starts mattering. Unlike a calendar, the schedule never falls out of sync when you skip or drift; unlike a plain to-do list, the next occurrence always reappears on its own.

## Design authority

Three sources of truth, in precedence order:

1. **Product decisions made after the handoff** (visible in the current code) — e.g. anchored toolbar menus instead of action sheets, no frequency presets, instant compounding snooze, display density. Don't "fix" the app back toward the spec where they differ.
2. **Native iOS design language** — where the handoff's 2023-era chrome conflicts with current native components, native wins. Keep the spec's structure, copy, colors, and semantics; render with stock components. The only fully custom chrome is the toast pill and the beat-row urgency bar/chip.
3. **`design_handoff_rhythm/`** — the original spec. `README.md` defines the vocabulary, business logic, screens, and design tokens; `design_files/` is a runnable React prototype (open `Rhythm.html`). It remains the reference for scheduling math, urgency semantics, and copy. It contains dead alternates (Ring/Tint urgency, Wizard/Cards forms, action-sheet beat actions) — ignore them: Bar urgency, swipe actions, and the single-page create form are locked. The handoff directory is read-only reference material.

## Domain model — the rules that make Rhythm Rhythm

These invariants are the product. Most of them are pinned by unit tests; violating any of them is a regression even if nothing crashes.

- **One active beat per cadence, ever.** Completing or skipping appends a `HistoryEntry` and *replaces* the beat with the next one. Enforced in `RhythmStore.insertActiveBeat` (CloudKit forbids schema-level uniqueness). Beats are never marked "done" — they're deleted and regenerated (linked) or just deleted (standalone).
- **Two schedule types** (`ScheduleType`): **relative** — next due = completion day + interval (for things that drift: mowing, haircuts); **fixed** — next due = previous due + interval, *regardless of when you completed it* (bills, trash day). A fixed cadence completed very late intentionally produces an already-overdue next beat — that's two missed trash days, not a bug.
- **Month/year intervals are anchor-day-preserving.** The cadence stores `anchorDay` (the original due day-of-month) and `DayMath.addMonthsAnchored` clamps to each target month's length. A 31st-anchored monthly cadence goes Jan 31 → Feb 28 → **Mar 31**. Never derive the next date from the previously-clamped one; that compounds the clamp and loses the anchor.
- **Grace** scales sub-linearly with frequency: `Grace.days(forFrequencyDays:)` = 0 for ≤2d, 1 for ≤8d, else `max(2, round(0.85·√days))`. Auto-suggested everywhere but user-editable; standalone beats derive it from distance-to-due instead. Grace drives three things: Today-list visibility (the urgency tiers), notification timing (almost = due − grace, overdue = due + grace), and snooze length.
- **Urgency tiers** (`UrgencyTier`, ordered): `later` (outside grace) → `almost` → `due` → `overdue` (within one grace past due) → `late`. Tier + days-until-due drive row bar color, chip styling (filled for due/late, tinted for almost/overdue, neutral for later), Today's sort (severity desc, closeness asc), and the Today/Later split.
- **Snooze replaces the due date.** While `snoozedUntil` is strictly in the future it *is* the effective due date for urgency, sorting, badge, and notifications — including visual tier colors. The original `due` is preserved for the amber "Originally due…" line, which is the sole snooze indicator on a row. Quick snooze (the default everywhere) = grace-length from `max(today, effectiveDue)`, so repeated snoozes compound; the explicit date picker lives behind "Snooze until…" in beat detail.
- **Beats are due on a *day*, never a time.** All scheduling math is day-granularity (`DayMath` start-of-day everywhere); notification *time* (minutes-since-midnight) only controls when reminders are delivered. Never compare raw `Date`s or divide intervals by 86400 — DST breaks that; use `DayMath.days(from:to:)`.
- **"Today" is live state** (`DayTicker`), refreshed at foreground, midnight, and timezone changes. Never cache a "today" in a model or compute urgency from `Date.now` directly in a view — read `ticker.today` so rows re-render at rollover.
- **Beat identity is copied, not referenced.** A generated beat copies name/color/glyph/note from its cadence at generation time. Editing a beat never edits its cadence; editing a cadence pushes identity changes onto the *current* active beat only. Per-beat notification settings are nullable overrides resolved against the cadence (or `.standard` for standalone) — persist an override only where it differs from the inherited value (`BeatDetailSheet.save`).
- **Discovery** = unknown-frequency tracker: log occurrences (editable, deletable child `DiscoveryLog` records), and once ≥2 exist, the average interval feeds `Frequency.suggested(forAverageDays:)`, which rounds to the largest unit within ~10% (72d → 10 weeks, 58d → 2 months). Conversion creates a cadence and deletes the discovery.

## Architecture

Strict layering; dependencies point downward only.

```
UI (SwiftUI views, sheets)          reads models, calls RhythmStore
  └─ Services (planner/scheduler, DayTicker, ToastCenter)
       └─ Store (RhythmStore — the only write path)
            └─ Models (SwiftData @Model, CloudKit-mirrored)
                 └─ Core (pure Swift: DayMath, Frequency, Grace, Urgency, ScheduleType)
```

### `Core/` — pure logic

No SwiftData, no UIKit/SwiftUI imports. All spec math lives here and every function takes an explicit `calendar:` (defaulting to `.current`) so tests can pin a fixed gregorian calendar. If you're writing date arithmetic, a label string ("every 3 weeks", "2d overdue"), or a tier decision anywhere else — stop and put it here.

### `Models/` — SwiftData under CloudKit rules

The schema mirrors to the user's private CloudKit database (`iCloud.marshallwarners.RhythmData`), which constrains every model: **all properties need defaults or optionality, all relationships are optional with explicit inverses, no unique constraints.** Enums and structured values are stored as raw scalars (`scheduleTypeRaw: String`, `everyN` + `everyUnitRaw`) with typed computed accessors on top — follow that pattern for new fields. Lists of domain events are child models with cascade deletes (`HistoryEntry`, `DiscoveryLog`), never encoded arrays.

Schema changes must be **additive** (new optional/defaulted properties). Renames or type changes break CloudKit mirror compatibility for existing installs.

History is append-only events; stats (actual average interval) are computed on read, never stored.

### `Store/RhythmStore.swift` — the single write path

Every mutation goes through the store, for two reasons: it enforces the one-active-beat invariant, and its `mutated()` → `onMutation` hook is what triggers notification/badge replanning. **A mutation added anywhere else silently breaks notifications and the badge.** New mutations follow the shape: mutate models → `mutated()` (which saves and fires the hook).

### `Services/` — the notification engine and app-state observables

`NotificationPlanner` is pure and synchronous: beats-snapshot in, full desired notification set out. `NotificationScheduler` is the thin impure shell: snapshots SwiftData, debounces (200ms, coalescing mutation bursts), wipes and reschedules `UNUserNotificationCenter`, sets the badge. Keep this split — planner changes get unit tests, scheduler changes stay trivial.

Why the design is what it is: iOS cannot run app code at midnight, and local notifications are static pre-scheduled payloads with *absolute* badge numbers. So future badge values are pre-computed (they're deterministic — data only changes through user action, which replans) and delivered as silent `.passive` badge-only notifications at midnight on each day the count changes. Reminders carry the badge value for their own fire day so the two systems can't disagree. Both kinds compete for **iOS's 64-pending-notification cap**, interleaved chronologically: near-term coverage is complete, horizon accuracy degrades gracefully. Replan triggers: every store mutation, app foreground, midnight/timezone tick, and changes to settings baked into content (sound, show-emojis).

`DayTicker` and `ToastCenter` are `@MainActor @Observable` singletons injected via `.environment` from `RhythmApp`, alongside `RhythmStore`, `AppSettings`, `Navigator`, and the scheduler.

### `UI/` — patterns

- **No view models.** Views read `@Environment` observables + `@Query`, derive presentation in computed properties, and call store methods directly. Derivations that get reused or have any subtlety belong in Core or as model computed properties.
- **Editor sheets use a local draft** (`@State` struct loaded in `onAppear`, written back on Done) so Cancel/swipe-dismiss discards cleanly — see `BeatDetailSheet`. Simple create sheets just hold `@State` fields.
- **"Touched" bindings**: values that auto-derive until the user edits them (grace from frequency, grace from due-distance) use a `Binding` wrapper that flips a `graceTouched` flag on set. Edit mode initializes touched = true so user values are never silently overwritten.
- **Navigation**: each tab owns a `NavigationStack`; cross-tab jumps (e.g. Beat Detail → its cadence) go through `Navigator` (tab selection + the Cadences push path). Menus anchored to toolbar buttons, not `confirmationDialog` (which floats mid-screen on iOS 26).
- **Theme**: structural styling is native; `Theme` only carries what the spec locks — accent, tier colors (light/dark pairs via dynamic `UIColor` providers), the identity palette. Use `Theme.tierColor(_:)` for anything urgency-colored; never hardcode hex in views.
- **Settings that change rendering globally** (`showEmoji`, `density`) are read inside the leaf components (`GlyphTile` hides itself; `BeatRowView`/cadence rows re-layout for Comfortable) so callers stay ignorant of them.
- Two UI annoyances to know about: complex inline expressions (tuple chains, `Text` concatenation in builders) hit Swift's type-checker timeout — break them into explicitly-typed helpers; and copy uses the spec's exact strings, so don't "improve" wording casually.

## Extension anatomy

- **New beat/cadence action** → method on `RhythmStore` ending in `mutated()` (replanning is then free) → UI calls it and shows a `ToastCenter` toast (every mutation has one; ~2.2s, icon + tint).
- **New model field** → defaulted/optional property, raw-scalar storage + typed accessor if structured, then thread it through: store mutation signatures, `SeedData`, and `NotificationPlanner.BeatInput` if it affects scheduling.
- **New setting** → property on `AppSettings` (UserDefaults-backed, `didSet` persistence, default in `init`), UI in `SettingsScreen`; add a `RootView` `.onChange` replan hook if it affects notification content. Settings are deliberately local-only (device preferences, not synced data).
- **New screen/sheet** → follow an existing sibling; sheets get their own file under `UI/Sheets/`.

## Testing

Swift Testing (`@Test`/`#expect`), all in `RhythmTests`, runnable headless. Tests pin a **fixed gregorian calendar in America/New_York** (DST-observing on purpose) so results are machine-independent — follow that pattern, never test against `Calendar.current`.

What earns tests: Core math (grace table, anchor clamping, tier boundaries, frequency rounding — many asserted values come *from the spec*, so changing them changes product behavior), store lifecycle (generation rules, invariants, cascades, snooze semantics), and the notification planner (timing, badge timeline, budget). UI and the scheduler shell don't get tests; they're verified in the simulator.

Store tests use an in-memory `ModelContainer` with `cloudKitDatabase: .none` — see `makeStore()` in `RhythmStoreTests`.

## Operations

```bash
# Build / test, from repo root (requires an iOS 26.5 simulator — iPhone 17 line)
xcodebuild -project Rhythm/Rhythm.xcodeproj -scheme Rhythm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Rhythm/Rhythm.xcodeproj -scheme Rhythm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:RhythmTests
```

- The project uses Xcode 16+ synchronized folder groups: files added on disk under `Rhythm/Rhythm/` join the target automatically — no pbxproj editing.
- `xcodebuild test` tends to shut the simulator down afterward; `xcrun simctl boot "iPhone 17 Pro"` before reinstalling. A one-off "System Failures: encountered an error" test result usually means the sim died mid-run, not a real failure — re-run before investigating.
- DEBUG builds auto-seed the prototype's sample data on first launch into an empty store (`SeedData`); production starts empty. Simulator data persists across reinstalls.
- CloudKit doesn't sync in the simulator (no signed-in account) — local persistence works, sync errors in the console are expected noise. Real sync, notification delivery, and midnight badge rollover are device-only verifications.
- Signing: automatic, team `UJFW53692H`, bundle `marshallwarners.Rhythm`.
- Commit at feature/fix boundaries with concise imperative messages (match `git log` style).
