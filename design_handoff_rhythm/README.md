# Handoff: Rhythm — Recurring To-Do iOS App

## Overview

**Rhythm** is an iOS-first mobile app: a *self-populating* to-do list for recurring tasks. Unlike a calendar (which falls out of sync the moment you skip a week) or a plain to-do list (which never re-adds the task), Rhythm auto-generates the next occurrence of a recurring task **based on how it's actually scheduled** — relative to completion, or relative to a fixed due date — and only surfaces it when it's genuinely worth your attention (the "grace period").

This package is a complete spec for building the real app. The design is **locked** (see Locked Decisions). The bundled HTML is a working, high-fidelity prototype of every screen and interaction.

### Core vocabulary (use these names in code)
- **Cadence** — a recurring item definition (e.g. "Mow the lawn", every 1 week). Has a name, emoji, color, schedule type, frequency, grace period, notification settings, and a history.
- **Beat** — a single concrete occurrence of a cadence (one to-do instance with a due date). Beats can also exist **standalone** (a one-off to-do not tied to any cadence).
- **Grace period** — how far ahead of its due date a beat starts mattering (and the basis for snooze length and notification timing). Scales with frequency. *This is the key concept — see Scheduling & Grace.*
- **Discovery** — a way to create a cadence when you don't yet know the frequency: log two occurrences, get a suggested frequency, convert to a cadence.

---

## About the Design Files

The files in `design_files/` are a **design reference created in HTML/React-in-the-browser** (Babel-transpiled JSX, no build step). They are a **prototype showing intended look and behavior — not production code to copy directly.**

The task is to **recreate this design in a real app environment.** This project has no existing codebase yet, so the implementer should choose the most appropriate stack. Recommended:

- **Native iOS — SwiftUI + SwiftData** (best fidelity; the design is pure iOS HIG and maps almost 1:1 to SwiftUI `List`, `.swipeActions`, `.sheet`, `Menu`, searchable lists, and `DatePicker`). Local notifications via `UNUserNotificationCenter`.
- **Alternative — React Native / Expo** if cross-platform is required (reuses the most logic from this prototype, since it's already React).

The HTML is the source of truth for **layout, copy, interaction, and the business logic** (scheduling math, grace derivation, urgency tiers). Reimplement that logic faithfully; restyle using the platform's native components.

## Fidelity

**High-fidelity.** Final colors, typography, spacing, iconography, copy, and interactions. Recreate the UI faithfully using native components. All values below are exact.

---

## Information Architecture

A bottom **tab bar** with four tabs:

1. **Today** — the main list of beats that currently matter, smart-sorted by urgency.
2. **Cadences** — the library of all recurring definitions; tap one for detail + history.
3. **Discovery** — track unknown-frequency tasks until they can become cadences.
4. **Settings** — defaults and preferences.

Navigation patterns:
- **Pushed screens** (slide in from right): Cadence Detail.
- **Modal sheets** (slide up from bottom, ~94% height, rounded top corners, drag-to-dismiss feel): Create/Edit Cadence, Quick Beat, Start Discovery, Convert Discovery, Beat Detail, Snooze.
- **Action sheets** (floating bottom card + Cancel): the "+" add menu, the per-beat action menu (only used in alternate interaction modes — see Locked Decisions), the cadence sort menu.

---

## Scheduling & Grace (the non-obvious core logic)

### Schedule types
Every cadence is one of two types. **Use the labels "Relative" and "Fixed" in the UI.**

- **Relative (to completion)** — `schedule: 'completion'`. The next beat's due date is computed **from the day you complete it**. Use for things that drift: mowing, haircuts, watering. Example: complete a weekly mow on Jun 10 → next beat due Jun 17.
- **Fixed (to due date)** — `schedule: 'dueDate'`. The next beat's due date is computed **from the previous due date**, regardless of when you actually did it. Use for hard schedules: bills, trash day. Example: trash due Tue Jun 9, you do it late on Jun 11 → next beat still due Jun 16 (next Tue).

### Frequency representation
Store frequency as a **unit-based value**, not just days: `{ n: number, unit: 'days'|'weeks'|'months'|'years' }`. Display it as set ("every 4 months", "5 weeks", "Weekly"), never normalized to days. A derived day-count (`freq`) is kept only for grace math and stats.

- Approx days per unit: `{ days:1, weeks:7, months:30, years:365 }` → `freqDays = n * unitDays`.
- Short label (used in the Cadences list bubble): n===1 → `Daily/Weekly/Monthly/Yearly`; else `"{n} {unit}"` (e.g. "3 weeks").
- Long label (used in detail): n===1 → `"every {singular-unit}"`; else `"every {n} {unit}"`.

### Calendar-aware date math (important — not naive day addition)
Adding an interval must respect the calendar, not just add `n*unitDays`:

- **days / weeks** → add `n` or `n*7` calendar days.
- **months** → add `n` months **preserving the original anchor day-of-month, clamped to the target month's length.** A monthly cadence anchored on the **1st** always lands on the 1st. Anchored on the **31st** → lands on the 30th in 30-day months, the 28th in February (29th in leap years), and **snaps back to the 31st** in months that have 31 days. This requires storing the **original anchor day** (`anchorDay`) and clamping each time — NOT deriving from the previously-clamped date.
- **years** → add `n*12` months (preserves month + applies the same day clamping; e.g. a Feb 29 anchor → Feb 28, or Feb 29 in leap years).

Reference implementation (from the prototype, `design_files/app/data.jsx`):
```js
function addMonthsAnchored(from, nMonths, anchorDay) {
  const d = startOfDay(from);
  const idx = d.getFullYear() * 12 + d.getMonth() + nMonths;
  const y = Math.floor(idx / 12), m = ((idx % 12) + 12) % 12;
  const dim = new Date(y, m + 1, 0).getDate();          // days in target month
  const day = Math.min(anchorDay || d.getDate(), dim);   // clamp, keep anchor
  return startOfDay(new Date(y, m, day));
}
function addEvery(from, { n, unit }, anchorDay) {
  if (unit === 'weeks')  return addDays(from, n * 7);
  if (unit === 'months') return addMonthsAnchored(from, n, anchorDay);
  if (unit === 'years')  return addMonthsAnchored(from, n * 12, anchorDay);
  return addDays(from, n); // days
}
```
- For **Relative** cadences, the next due is `addEvery(completionDate, every, completionDate.getDate())` (anchor = the day you completed).
- For **Fixed** cadences, the next due is `addEvery(previousDue, every, cadence.anchorDay)` where `anchorDay` is the original due date's day-of-month (preserved across cycles).

### Grace period
Grace is **how many days before the due date a beat starts appearing/mattering**, and it scales sub-linearly with frequency. Default derivation:
```js
function graceFromFrequency(freqDays) {
  if (freqDays <= 2) return 0;
  if (freqDays <= 8) return 1;                          // weekly → 1 day
  return Math.max(2, Math.round(0.85 * Math.sqrt(freqDays)));
}
// 30d→5, 90d→8, 120d→9, 365d→16
```
- Grace is **auto-suggested** from frequency but **user-editable** per cadence and per beat.
- For a **standalone beat**, there's no frequency to inherit from, so grace defaults from the distance to its due date: `graceFromFrequency(daysUntilDue)`. Still user-editable.
- Grace drives three things, surfaced in the beat-detail copy: **"Used for the main beat view, notification timing, and snooze length."**

---

## Urgency model (visual escalation)

Given today, a beat's effective due date, and its grace `g`, compute a tier. `off = daysBetween(today, due)` (positive = future):

| Tier | Condition | Meaning | Color | Chip label |
|---|---|---|---|---|
| `later` | `off > g` | Outside grace, not yet relevant | neutral gray | relative date ("in 12 days") |
| `almost` | `0 < off ≤ g` | Within grace, coming up | **accent blue** | relative ("in 2 days", "tomorrow") |
| `due` | `off === 0` | Due today | **accent blue** (filled) | "Due today" |
| `overdue` | `-g ≤ off < 0` | Past due, within one grace | **amber** | "{n}d overdue" |
| `late` | `off < -g` | Beyond one grace past due | **red** | "{n}d overdue" |

**Locked visual language = "Bar":** a colored vertical bar on the leading (left) edge of each beat row, colored by tier (no bar for `later`). Plus a colored **due chip** on the trailing edge. `due` and `late` chips are **filled** (white text on solid color); `almost`/`overdue` chips are **tinted** (colored text on a faint colored background); `later` chip is gray.

Today screen sorting: a single smart-sorted list — by tier severity descending, then by `off` ascending. Beats in the `later` tier are split into a separate **"Later"** section below the main list.

---

## Beats: actions & lifecycle

**Complete** is the primary action; **Skip** and **Snooze** are secondary. Locked interaction = **swipe** (iOS `.swipeActions`):
- **Leading swipe (drag right)** → full swipe completes (green, ✓ "Complete"). A short drag shows the green affordance sized to the drag distance only.
- **Trailing swipe (drag left)** reveals two buttons, in this order from inner→outer: **Skip** (gray, ⏭ skip-to-next icon) then **Snooze** (amber, 💤). Over-swiping past them extends the **inner** button's (Skip's) color — never reveals the leading green.
- **Tapping the row** opens **Beat Detail** (full editor).

### What each action does
- **Complete** → records a `completed` entry in the cadence's history dated today; generates the next beat (via the scheduling rules above). Standalone beats are simply removed (done). Shows a toast ("Completed · next beat scheduled").
- **Skip** → records a `skipped` history entry; generates the next beat the same way (Relative → from today; Fixed → from previous due). Standalone → removed. Toast "Skipped".
- **Snooze** → see below. Toast "Snoozed until {date}".

### Snooze model (non-obvious)
- Default snooze length **equals the grace period** (so a weekly cadence snoozes ~1 day; a yearly one ~2 weeks). Snooze sheet offers: Tomorrow, "{grace}d — matches grace" (the default/recommended), In 3 days, Next week, and Pick a date (calendar).
- Snoozing sets `snoozedUntil`. While `snoozedUntil` is in the future, the beat's **effective due date becomes `snoozedUntil`** (so urgency is recomputed from the snooze date — it leaves your radar until then).
- A snoozed beat **stays visible in the list** with: a 💤 icon prepended in its due chip, and a second subtitle line **"Originally due {relative date}"** (amber). It re-sorts by its new effective date.
- Beat Detail shows a "Snoozed — Back {date} · originally due {date}" row with a **Resume** button (clears `snoozedUntil`).

### Beat Detail (editor sheet)
Top-to-bottom: a status banner (e.g. "2 days overdue", "Due today", "Upcoming · in 2 days", "Snoozed · back tomorrow"); emoji + editable name; "Part of cadence" row (if linked, tap → cadence detail); **Schedule**: Due date (tap → inline month calendar), Grace period (stepper); **Notifications**: Almost due / Due / Overdue toggles + editable Time (tap → inline time picker); **Notes**; bottom action buttons (Complete primary; Snooze + Skip; Delete for standalone). Editing a linked beat's fields affects only that beat, not the cadence.

---

## Discovery flow

For tasks with unknown frequency. A discovery has a name, emoji, color, and a list of logged occurrence dates.
- **< 2 logs**: shows "{n} of 2 logged", the logged dates, and a "Log occurrence" button (logs today).
- **≥ 2 logs**: computes a **suggested frequency** = average interval between logged dates, shows "Suggested frequency: about every {n} days", and a **"Convert to cadence"** button.
- **Convert** opens a sheet pre-filled with the suggested frequency (and name/emoji/color), where the user adjusts schedule type and frequency, then creates a real cadence. The discovery is removed.

---

## Notifications

- Configurable at the **cadence level**, overridable per **beat**.
- Three toggles tied to grace: **Almost due** (one grace period before due), **Due** (on the due date), **Overdue** (one grace period after due).
- **Beats are due on a *day*, not a time.** Due dates have date-level fidelity only. A notification **time** (e.g. "9:00 AM") controls *when the reminder is delivered* on that day — surfaced in the Settings About footer: *"Beats are due on a day, never a time. Notification time only controls when the reminder is delivered."*

---

## Settings

- **Appearance**: Light / Dark / System segmented control (actually switches the theme).
- **Show emojis** toggle — "Display emojis next to beats and cadences." When off, the emoji tiles are hidden everywhere.
- **New cadence defaults → Scheduling**: Relative / Fixed (default for newly created cadences).
- **Default notifications**: Almost due / Due / Overdue toggles + Default time (editable picker). Applied to new cadences; each cadence/beat can override.
- **Alerts**: Sound, Vibrate toggles.
- **About**: footer explaining day-vs-time; Version row.

---

## Screens / Views

> Recreate using native components. Measurements below describe the prototype (logical px at iPhone width 402). Map spacing/typography to the platform's scale; keep proportions and hierarchy.

### Today
- **Purpose**: see what currently needs doing.
- **Layout**: large-title nav ("Today", subtitle = weekday + date, e.g. "Tuesday, Jun 9"); trailing "+" button; a **search bar that starts tucked off-screen above the title** (pull down to reveal — see Interactions); a summary strip ("3 overdue · 6 upcoming" with colored dots); then the smart-sorted beat list in an inset grouped card; a "Later" section for non-urgent beats; empty state "All caught up" when nothing is within grace.
- **Beat row**: leading urgency bar (4px, tier color) · emoji tile (31px, rounded ~9px, on the cadence color) · name (17px, 600) + optional description line (13px secondary) + optional snooze line · trailing due chip. Row height 56 (no subtitle) / 64 (with subtitle).

### Cadences
- **Purpose**: manage recurring definitions.
- **Layout**: large title "Cadences" (subtitle "{n} recurring"); trailing **sort** button (up/down-arrows icon) + "+"; search bar (tucked); a single inset list (no relative/fixed grouping).
- **Row**: emoji tile · name (17px, 600) + description subtitle · trailing chip showing the frequency short-label with a small **schedule icon** (a repeat/↻ glyph for Relative, an **anchor** for Fixed) · chevron.
- **Sort** (action sheet, "SORT CADENCES"): Name (A–Z) / Frequency / Recently added, with a checkmark on the active option. Default A–Z.

### Cadence Detail (pushed)
- **Purpose**: inspect one cadence, act on its next beat, review history.
- **No large title** (the back button "Cadences" + "Edit" sit in the nav; the title appears in the nav bar only when scrolled). Content: centered hero (62px emoji tile, name, description) → **Next beat** card (date, weekday, relative, due chip; Complete + Snooze buttons) → **stat cards** (Target interval e.g. "Weekly", Actual average e.g. "7d" — amber if it deviates from target by more than grace, Grace period "1d") → **Schedule** group (Scheduling: Relative/Fixed; Frequency: "Every week"; Notifications summary) → **History** list (each past beat: date, weekday, completed/skipped marker, interval since previous) → **Delete cadence**.

### Discovery
- Large title "Discovery", subtitle **"Find your rhythm"**, trailing "+". An explainer card; then discovery cards (see Discovery flow). Empty state when none.

### Settings
- See Settings section. Grouped inset lists with segmented controls, toggles, and inline pickers.

### Create / Edit Cadence (sheet) — locked form style: **Single**
- One scrolling grouped form: emoji + color picker (tap the colored tile to open the keyboard and type any emoji — **no preset emoji grid**) + name; Scheduling (two selectable cards: Relative / Fixed with descriptions); Frequency (presets Daily/Weekly/Monthly/Yearly + stepper + unit segmented days/wks/mos/yrs, with live "Suggested grace period: {n} days"); Grace period (stepper); First beat due (inline calendar); Notifications toggles.
- **Edit mode pre-populates all fields** (name, emoji, color, schedule, frequency, grace, due, notifications) from the existing cadence.

### Quick Beat (sheet)
- Standalone beat: emoji/color + name; Due date (calendar); Grace period (stepper, defaults from distance-to-due). Footer notes that standalone beats set grace manually.

---

## Interactions & Behavior

- **Search reveal**: the search bar is rendered *above* the title and the list starts scrolled down by the search bar's height, so it's hidden behind the (opaque) nav by default; pulling down (scroll to top) reveals it. It does not occupy space unless wanted. (Native equivalent: `.searchable` with `automatic`/hide-on-scroll behavior.)
- **Large-title nav collapse**: large title in flow; on scroll it gives way to a centered inline title in the nav bar with a hairline/blur. The collapse threshold is offset by the tucked search height so the title shows at rest.
- **Swipe rows**: as described in Beats. Tap vs swipe is disambiguated — a horizontal drag suppresses the subsequent tap so peeking the actions doesn't open the row.
- **Sheets**: slide up ~0.34s `cubic-bezier(.32,.72,0,1)`, dimmed backdrop, drag/tap-out to dismiss; comfortable bottom padding so the last field isn't jammed against the edge.
- **Pushed screen**: slides in from the right with a left-edge shadow.
- **Toasts**: brief centered pill above the tab bar for complete/skip/snooze/create/delete, ~2.2s.
- **Switch toggles, steppers, segmented controls**: standard iOS feel.
- **Light/Dark/System**: full theming; the prototype shows light + dark side by side, and Settings switches it live.

## State Management

Top-level app state (per the prototype):
- `cadences[]` — each: `{ id, created, name, color, glyph(emoji), schedule, every:{n,unit}, freq, grace, anchorDay, notify:{almost,due,overdue,time}, desc, history[], beat }`. `beat` is the current active beat.
- `standalone[]` — beats not tied to a cadence: `{ id, name, color, glyph, due, grace, status, notify, desc, snoozedUntil? }`.
- `discoveries[]` — `{ id, name, color, glyph, logs:[dates], desc }`.
- `settings` — `{ defaultSchedule, notify:{almost,due,overdue,time}, sound, vibrate, showEmoji }`.
- Transient UI: current tab, pushed cadence id, which sheet/action-sheet is open + its payload, toast, cadence sort key.

A **beat** (active or standalone): `{ id, cadenceId|null, name, color, glyph, due(date), grace, status:'active'|'done', schedule, notify, desc, snoozedUntil? }`.

**The real app must add persistence** (SwiftData/Core Data/local DB) and **local notification scheduling** — the prototype is in-memory and resets on reload. The grace/scheduling functions above are the spec for the notification fire-times and next-beat generation.

---

## Design Tokens (locked)

### Color — accent
- **Accent (primary tint): `#0A84FF`** (iOS system blue). Used for actions, the `almost`/`due` urgency tiers, selection, links.

### Color — urgency tiers
| Tier | Light | Dark |
|---|---|---|
| later (neutral) | `rgba(60,60,67,0.45)` | `rgba(235,235,245,0.4)` |
| almost / due | `#0A84FF` | lightened `#0A84FF` (~+16%) |
| overdue | `#FF9500` | `#FF9F0A` |
| late | `#FF3B30` | `#FF453A` |
| green (complete) | `#34C759` | `#30D158` |

### Color — surfaces (iOS system)
| Token | Light | Dark |
|---|---|---|
| Background (grouped) | `#F2F2F7` | `#000000` |
| Card / elevated | `#FFFFFF` | `#1C1C1E` |
| Secondary fill | `rgba(118,118,128,0.12)` | `rgba(118,118,128,0.24)` |
| Label | `#000000` | `#FFFFFF` |
| Secondary label | `rgba(60,60,67,0.6)` | `rgba(235,235,245,0.6)` |
| Tertiary label | `rgba(60,60,67,0.3)` | `rgba(235,235,245,0.3)` |
| Separator | `rgba(60,60,67,0.16)` | `rgba(84,84,88,0.6)` |
| Nav blur bg | `rgba(249,249,251,0.8)` | `rgba(20,20,22,0.72)` |

Cadence emoji-tile colors come from a curated palette: `#5E5CE6 #34C759 #FF9500 #FF2D55 #0A84FF #AF52DE #FFCC00 #30D158 #64D2FF #A2845E #FF6B35 #8E8E93`.

### Typography
- Family: **SF Pro / system font** (`-apple-system, system-ui`). On native iOS this is the system font automatically.
- Large title: 34px / 800. Section title in sheets: 17px / 600. Row title: 17px (or 16.5/600 for beat rows). Subtitle/secondary: 13–13.5px. Chips: 12.5px / 600. Tab labels: 10.5px. Letter-spacing roughly -0.2 to -0.4 on titles.

### Radius / spacing
- Grouped list cards: radius 12; discovery cards 16; sheets 14 (top corners only). Emoji tiles: ~29% of size. Device screen content uses 16px side gutters; section headers 32px gutter.
- Tab bar height ~86 (incl. home-indicator inset); nav area ~100 (status bar + 44 bar).

### Icons
- Simple line icons (1.8–2px stroke, round caps) for chrome: tabs (Today calendar, Cadences repeat, Discovery compass/explore, **Settings gear**), plus, check, chevrons, bell, clock, **snooze (💤/zzz)**, **skip (⏭ skip-to-next)**, search, **sort (up/down arrows)**, **anchor (Fixed schedule)**, repeat (Relative schedule), etc. Map to **SF Symbols** in the native build (e.g. `calendar`, `arrow.triangle.2.circlepath`, `safari`/`scope`, `gearshape`, `forward.end`, `zzz`, `anchor`, `arrow.up.arrow.down`, `magnifyingglass`).
- **Cadence/beat identity = emoji** (user-typed), shown on a colored rounded tile. Toggleable off in Settings.

---

## Assets
No external image assets. All iconography is line icons / SF Symbols equivalents; identity glyphs are user-entered emoji. App accent is iOS system blue. No third-party brand assets.

## Files (in `design_files/`)
- `Rhythm.html` — entry point; loads React 18 + Babel and the app modules; contains the two-phone "studio" presentation and the (now minimal) preview panel.
- `app/data.jsx` — **the logic spec**: date math, `addEvery`/`addMonthsAnchored`, `graceFromFrequency`, urgency tiers, frequency labels, seed sample data.
- `app/ui.jsx` — theme tokens, scaffold (collapsing nav + tucked search), tab bar, grouped list/rows, segmented control, switch, sheets, action sheet, time picker.
- `app/beat.jsx` — beat row (urgency bar + chip), swipe mechanics.
- `app/sheets.jsx` — beat detail, snooze, beat action sheet.
- `app/screens.jsx` — Today, Cadences, Cadence Detail.
- `app/screens2.jsx` — Discovery, Settings.
- `app/create.jsx` — create/edit cadence (single form), quick beat, create/convert discovery, add menu.
- `app/app.jsx` — app state, navigation, scheduling wiring, the two-phone Root.
- `app/icons.jsx` — line-icon set.
- `app/calendar.jsx` — inline month picker.

To run the prototype: open `Rhythm.html` in a browser (no build needed).

---

## Locked Decisions
- **Urgency visual = Bar** (leading colored bar + due chip). *(The prototype's code also contains "Ring" and "Tint" alternates — ignore them; Bar is final.)*
- **Beat actions = Swipe.** *(Alternate "Buttons" and "Sheet" modes exist in code — ignore; Swipe is final.)*
- **Create form = Single** scrolling form. *(Alternate "Wizard" and "Cards" exist in code — ignore.)*
- **Accent = `#0A84FF`.**
- **Both Light and Dark** themes are required, plus System.
