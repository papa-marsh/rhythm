// data.jsx — Rhythm sample data + date / grace / urgency logic
// Exports to window: RhythmData (helpers + seed)

const DAY = 86400000;

// Deterministic "today" for the prototype.
const TODAY = startOfDay(new Date(2026, 5, 9)); // Jun 9 2026 (Tue)

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}
function addDays(d, n) { return startOfDay(new Date(startOfDay(d).getTime() + n * DAY)); }
function daysBetween(a, b) { return Math.round((startOfDay(b) - startOfDay(a)) / DAY); }
function dateFromOffset(n) { return addDays(TODAY, n); }

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WK = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function fmtDate(d, opts = {}) {
  d = startOfDay(d);
  const off = daysBetween(TODAY, d);
  if (!opts.absolute) {
    if (off === 0) return 'Today';
    if (off === 1) return 'Tomorrow';
    if (off === -1) return 'Yesterday';
  }
  const base = `${MONTHS[d.getMonth()]} ${d.getDate()}`;
  return d.getFullYear() !== TODAY.getFullYear() ? `${base}, ${d.getFullYear()}` : base;
}
function fmtWeekday(d) { return WK[startOfDay(d).getDay()]; }

// ── Frequency units & calendar-aware date math ───────────────
const UNIT_DAYS = { days: 1, weeks: 7, months: 30, years: 365 };
function nuToDays(n, unit) { return n * UNIT_DAYS[unit]; }
function daysToNU(days) {
  if (days % 365 === 0 && days >= 365) return { n: days / 365, unit: 'years' };
  if (days % 30 === 0 && days >= 30) return { n: days / 30, unit: 'months' };
  if (days % 7 === 0 && days >= 7) return { n: days / 7, unit: 'weeks' };
  return { n: days, unit: 'days' };
}
function shortEvery(e) {
  if (!e) return '';
  const { n, unit } = e;
  if (n === 1) return { days: 'Daily', weeks: 'Weekly', months: 'Monthly', years: 'Yearly' }[unit];
  return `${n} ${unit}`;
}
function humanEvery(e) {
  if (!e) return '';
  const { n, unit } = e;
  if (unit === 'days') return n === 1 ? 'every day' : `every ${n} days`;
  const sing = { weeks: 'week', months: 'month', years: 'year' }[unit];
  return n === 1 ? `every ${sing}` : `every ${n} ${unit}`;
}
// Add months while preserving the original anchor day-of-month (clamped to the
// target month length). Years = +12 months, which keeps Feb 29 -> Feb 28/29.
function addMonthsAnchored(from, nMonths, anchorDay) {
  const d = startOfDay(from);
  const idx = d.getFullYear() * 12 + d.getMonth() + nMonths;
  const y = Math.floor(idx / 12), m = ((idx % 12) + 12) % 12;
  const dim = new Date(y, m + 1, 0).getDate();
  const day = Math.min(anchorDay || d.getDate(), dim);
  return startOfDay(new Date(y, m, day));
}
function addEvery(from, e, anchorDay) {
  const { n, unit } = e;
  if (unit === 'weeks') return addDays(from, n * 7);
  if (unit === 'months') return addMonthsAnchored(from, n, anchorDay);
  if (unit === 'years') return addMonthsAnchored(from, n * 12, anchorDay);
  return addDays(from, n);
}

// Relative phrasing for a due date ("in 3 days", "2 days ago")
function fmtRelative(d) {
  const off = daysBetween(TODAY, d);
  if (off === 0) return 'today';
  if (off === 1) return 'tomorrow';
  if (off === -1) return 'yesterday';
  if (off > 1) return `in ${off} days`;
  return `${-off} days ago`;
}

// Derive a grace period (in days) from a frequency (in days).
// Weekly (7) -> ~1 day. 6-week (42) -> ~5. Yearly (365) -> ~16. Sub-linear.
function graceFromFrequency(freq) {
  if (freq <= 2) return 0;
  if (freq <= 8) return 1;
  return Math.max(2, Math.round(0.85 * Math.sqrt(freq)));
}

// Snooze length === grace period (per spec). At least 1 day.
function snoozeForGrace(grace) { return Math.max(1, grace); }

// Urgency tiers, ordered by severity.
// later(0) outside grace window | almost(1) within grace before due |
// due(2) due today | overdue(3) past due within one grace | late(4) beyond one grace past due
const TIERS = ['later', 'almost', 'due', 'overdue', 'late'];

function isSnoozed(beat) { return !!(beat.snoozedUntil && daysBetween(TODAY, beat.snoozedUntil) > 0); }
function effectiveDue(beat) { return isSnoozed(beat) ? beat.snoozedUntil : beat.due; }

function urgencyOf(beat) {
  const snz = isSnoozed(beat);
  const due = snz ? beat.snoozedUntil : beat.due;
  const off = daysBetween(TODAY, due); // + future, - past
  const g = beat.grace;
  if (off > g) return { tier: 'later', rank: 0, off, snoozed: snz, label: fmtRelative(due) };
  if (off > 0) return { tier: 'almost', rank: 1, off, snoozed: snz, label: fmtRelative(due) };
  if (off === 0) return { tier: 'due', rank: 2, off, snoozed: snz, label: 'Due today' };
  if (off >= -g) return { tier: 'overdue', rank: 3, off, snoozed: snz, label: `${-off}d overdue` };
  return { tier: 'late', rank: 4, off, snoozed: snz, label: `${-off}d overdue` };
}

// ── Seed data ────────────────────────────────────────────────
let _id = 1;
const uid = (p) => `${p}_${_id++}`;

// History helper: builds completed beats spaced by ~freq going back in time.
function buildHistory(freq, count, jitter = 0.15) {
  const out = [];
  let acc = -Math.round(freq * 0.4); // most recent completion was a bit ago
  for (let i = 0; i < count; i++) {
    const wobble = Math.round(freq * jitter * (Math.random() - 0.5) * 2);
    out.push({ date: dateFromOffset(acc), action: 'completed' });
    acc -= (freq + wobble);
  }
  return out;
}

function cadence(o) {
  const every = o.every || daysToNU(o.freq || 7);
  const freq = nuToDays(every.n, every.unit);
  const grace = o.grace ?? graceFromFrequency(freq);
  const created = _id;
  const anchorBase = o.firstDue ? startOfDay(o.firstDue) : dateFromOffset(o.dueOff != null ? o.dueOff : freq);
  return {
    id: uid('cad'),
    created,
    kind: 'cadence',
    schedule: 'completion', // 'completion' | 'dueDate'
    notify: { almost: false, due: true, overdue: true, time: '9:00 AM' },
    desc: '',
    history: [],
    ...o,
    every,
    freq,
    grace,
    anchorDay: anchorBase.getDate(),
  };
}

// freq in days; dueOff = current beat's due date offset from today
const SEED_CADENCES = [
  cadence({ name: 'Mow the lawn', color: '#34C759', glyph: '🌿', schedule: 'completion', every: { n: 1, unit: 'weeks' }, dueOff: 0,
    desc: 'Front and back. Bag the clippings if it’s gotten tall.', history: buildHistory(7, 8) }),
  cadence({ name: 'Take out the trash', color: '#8E8E93', glyph: '🗑️', schedule: 'dueDate', every: { n: 1, unit: 'weeks' }, dueOff: -1,
    desc: 'To the curb Tuesday night. Recycling on alternate weeks.', notify: { almost: true, due: true, overdue: true, time: '6:30 PM' }, history: buildHistory(7, 10) }),
  cadence({ name: 'Replace HVAC filter', color: '#FF9500', glyph: '🌬️', schedule: 'dueDate', every: { n: 3, unit: 'months' }, dueOff: -11,
    desc: '20×25×1, MERV 11. Box is in the garage.', history: buildHistory(90, 4) }),
  cadence({ name: 'Pay electric bill', color: '#FFCC00', glyph: '⚡️', schedule: 'dueDate', every: { n: 1, unit: 'months' }, dueOff: 3,
    desc: '', notify: { almost: true, due: true, overdue: true, time: '9:00 AM' }, history: buildHistory(30, 6) }),
  cadence({ name: 'Haircut', color: '#5E5CE6', glyph: '✂️', schedule: 'completion', every: { n: 5, unit: 'weeks' }, dueOff: 1,
    desc: 'Ask for the usual — #3 on the sides.', history: buildHistory(35, 5) }),
  cadence({ name: 'Fertilize the lawn', color: '#30D158', glyph: '🌱', schedule: 'completion', every: { n: 4, unit: 'months' }, dueOff: 9,
    desc: 'Spring application. Don’t mow for 2 days after.', history: buildHistory(120, 3) }),
  cadence({ name: 'Water the ferns', color: '#32ADE6', glyph: '🪴', schedule: 'completion', every: { n: 3, unit: 'days' }, dueOff: 0,
    desc: '', history: buildHistory(3, 12) }),
  cadence({ name: 'Clean the gutters', color: '#A2845E', glyph: '🏠', schedule: 'completion', every: { n: 6, unit: 'months' }, dueOff: 41,
    desc: '', history: buildHistory(180, 2) }),
  cadence({ name: 'Replace toothbrush head', color: '#64D2FF', glyph: '🪥', schedule: 'dueDate', every: { n: 3, unit: 'months' }, dueOff: 26,
    desc: '', history: buildHistory(90, 3) }),
];

// Standalone beats (no cadence)
function beat(o) {
  const grace = o.grace ?? graceFromFrequency(Math.max(1, o.dueOff));
  return { id: uid('beat'), kind: 'beat', cadenceId: null, status: 'active', notify: null, desc: '', ...o, grace, due: dateFromOffset(o.dueOff) };
}
const SEED_STANDALONE = [
  beat({ name: 'Return library books', color: '#AF52DE', glyph: '📚', dueOff: -2, grace: 2,
    desc: '3 books — the tote by the door.' }),
  beat({ name: 'Call dentist to schedule', color: '#FF2D55', glyph: '🦷', dueOff: 2, grace: 3 }),
  beat({ name: 'Renew passport', color: '#0A84FF', glyph: '🛂', dueOff: 88 }),
];

// Build the active beat for each cadence from its dueOff
function activeBeatFor(cad) {
  return {
    id: uid('beat'), kind: 'beat', cadenceId: cad.id, name: cad.name, color: cad.color, glyph: cad.glyph,
    status: 'active', due: dateFromOffset(cad.dueOff), grace: cad.grace, desc: cad.desc,
    schedule: cad.schedule, notify: null,
  };
}

// Discoveries — frequency unknown, tracking occurrences
const SEED_DISCOVERIES = [
  { id: uid('disc'), kind: 'discovery', name: 'Change fridge water filter', color: '#64D2FF', glyph: '💧',
    logs: [dateFromOffset(-190)], desc: 'No idea how often. Tracking to find out.' },
  { id: uid('disc'), kind: 'discovery', name: 'Descale the espresso machine', color: '#A2845E', glyph: '☕️',
    logs: [dateFromOffset(-120), dateFromOffset(-48)], desc: '' }, // 2 logs -> ready to convert (~72d)
];

window.RhythmData = {
  DAY, TODAY, startOfDay, addDays, daysBetween, dateFromOffset,
  fmtDate, fmtWeekday, fmtRelative, MONTHS, WK,
  graceFromFrequency, snoozeForGrace, urgencyOf, isSnoozed, effectiveDue, TIERS,
  UNIT_DAYS, nuToDays, daysToNU, shortEvery, humanEvery, addMonthsAnchored, addEvery,
  cadence, beat, buildHistory, activeBeatFor, uid,
  SEED_CADENCES, SEED_STANDALONE, SEED_DISCOVERIES,
};
