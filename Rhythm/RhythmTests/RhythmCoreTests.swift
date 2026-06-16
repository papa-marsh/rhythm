//
//  RhythmCoreTests.swift
//  RhythmTests
//
//  Pins RhythmCore to the design spec's scheduling, grace, and urgency
//  contracts (design_handoff_rhythm/README.md). The exact values asserted
//  here come from the spec — changing them changes app behavior.
//

import Foundation
import Testing

@testable import Rhythm

/// Deterministic calendar so results don't depend on the machine's locale.
/// America/New_York observes DST, which the day math must tolerate.
private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

// MARK: - Grace derivation

struct GraceTests {
    @Test("spec table: frequency days → grace days", arguments: [
        (1, 0), (2, 0),  // ≤ 2 days → no grace
        (3, 1), (7, 1), (8, 1),  // up to ~weekly → 1 day
        (30, 5), (90, 8), (120, 9), (365, 16),  // spec's exact examples
    ])
    func graceFromFrequency(freq: Int, expected: Int) {
        #expect(Grace.days(forFrequencyDays: freq) == expected)
    }

    @Test("grace never drops below 2 once past the weekly band")
    func graceFloor() {
        #expect(Grace.days(forFrequencyDays: 9) >= 2)
        #expect(Grace.days(forFrequencyDays: 10) >= 2)
    }

    @Test("snooze length matches grace but is at least one day")
    func snoozeLength() {
        #expect(Grace.snoozeDays(forGrace: 0) == 1)
        #expect(Grace.snoozeDays(forGrace: 1) == 1)
        #expect(Grace.snoozeDays(forGrace: 16) == 16)
    }
}

// MARK: - Frequency representation

struct FrequencyTests {
    @Test("day counts collapse to the largest clean unit")
    func unitInference() {
        #expect(Frequency(approximateDays: 365) == Frequency(n: 1, unit: .years))
        #expect(Frequency(approximateDays: 730) == Frequency(n: 2, unit: .years))
        #expect(Frequency(approximateDays: 90) == Frequency(n: 3, unit: .months))
        #expect(Frequency(approximateDays: 14) == Frequency(n: 2, unit: .weeks))
        #expect(Frequency(approximateDays: 72) == Frequency(n: 72, unit: .days))
        #expect(Frequency(approximateDays: 3) == Frequency(n: 3, unit: .days))
    }

    @Test("labels display as set, never normalized to days")
    func labels() {
        #expect(Frequency(n: 1, unit: .weeks).shortLabel == "Weekly")
        #expect(Frequency(n: 3, unit: .weeks).shortLabel == "3 weeks")
        #expect(Frequency(n: 1, unit: .days).longLabel == "every day")
        #expect(Frequency(n: 1, unit: .months).longLabel == "every month")
        #expect(Frequency(n: 4, unit: .months).longLabel == "every 4 months")
    }

    @Test("derived day count for grace math")
    func approximateDays() {
        #expect(Frequency(n: 5, unit: .weeks).approximateDays == 35)
        #expect(Frequency(n: 3, unit: .months).approximateDays == 90)
    }

    @Test("discovery suggestions round to friendly frequencies", arguments: [
        (72, 10, FrequencyUnit.weeks),  // 70d is 2.8% off — nicer than "72 days"
        (58, 2, FrequencyUnit.months),  // 60d is 3.4% off
        (190, 6, FrequencyUnit.months),  // 180d is 5.3% off
        (365, 1, FrequencyUnit.years),
        (350, 1, FrequencyUnit.years),  // 4.3% off
        (30, 1, FrequencyUnit.months),
        (13, 2, FrequencyUnit.weeks),  // 14d is 7.7% off
        (7, 1, FrequencyUnit.weeks),
        (9, 9, FrequencyUnit.days),  // 7d would be 22% off — keep exact days
        (3, 3, FrequencyUnit.days),
    ])
    func suggestedRounding(measured: Int, n: Int, unit: FrequencyUnit) {
        #expect(Frequency.suggested(forAverageDays: measured) == Frequency(n: n, unit: unit))
    }
}

// MARK: - Day math

struct DayMathTests {
    @Test("whole-day difference is DST-safe")
    func daysAcrossDST() {
        // US spring-forward 2026: Mar 8. A naive 86400s division breaks here.
        #expect(DayMath.days(from: date(2026, 3, 7), to: date(2026, 3, 9), calendar: cal) == 2)
        // Fall-back 2026: Nov 1.
        #expect(DayMath.days(from: date(2026, 10, 31), to: date(2026, 11, 2), calendar: cal) == 2)
    }

    @Test("adding days crosses month and year boundaries")
    func addDays() {
        #expect(DayMath.addDays(7, to: date(2026, 6, 28), calendar: cal) == date(2026, 7, 5))
        #expect(DayMath.addDays(1, to: date(2026, 12, 31), calendar: cal) == date(2027, 1, 1))
    }

    @Test("31st anchor clamps down but snaps back in 31-day months")
    func anchorSnapsBack() {
        // Anchored on the 31st: Jan 31 → Feb 28 → Mar 31 → Apr 30 → May 31.
        let jan31 = date(2026, 1, 31)
        let feb = DayMath.addMonthsAnchored(1, to: jan31, anchorDay: 31, calendar: cal)
        #expect(feb == date(2026, 2, 28))
        let mar = DayMath.addMonthsAnchored(1, to: feb, anchorDay: 31, calendar: cal)
        #expect(mar == date(2026, 3, 31))  // NOT Mar 28 — anchor preserved, not compounded
        let apr = DayMath.addMonthsAnchored(1, to: mar, anchorDay: 31, calendar: cal)
        #expect(apr == date(2026, 4, 30))
        let may = DayMath.addMonthsAnchored(1, to: apr, anchorDay: 31, calendar: cal)
        #expect(may == date(2026, 5, 31))
    }

    @Test("February anchor respects leap years")
    func leapYearAnchor() {
        // Feb 29 2028 (leap) + 12 months, anchor 29 → Feb 28 2029.
        let feb29 = date(2028, 2, 29)
        let next = DayMath.addMonthsAnchored(12, to: feb29, anchorDay: 29, calendar: cal)
        #expect(next == date(2029, 2, 28))
        // From the clamped Feb 28 2029, three more years lands back on Feb 29 2032.
        let leapAgain = DayMath.addMonthsAnchored(36, to: next, anchorDay: 29, calendar: cal)
        #expect(leapAgain == date(2032, 2, 29))
    }

    @Test("month addition crosses year boundaries")
    func monthsAcrossYears() {
        #expect(
            DayMath.addMonthsAnchored(3, to: date(2026, 11, 15), anchorDay: 15, calendar: cal)
                == date(2027, 2, 15))
    }

    @Test("anchor day of 1st always lands on the 1st")
    func firstOfMonthAnchor() {
        var d = date(2026, 1, 1)
        for _ in 0..<12 {
            d = DayMath.addMonthsAnchored(1, to: d, anchorDay: 1, calendar: cal)
            #expect(cal.component(.day, from: d) == 1)
        }
        #expect(d == date(2027, 1, 1))
    }

    @Test("frequency addition dispatches by unit")
    func addFrequency() {
        // days / weeks → plain day addition
        #expect(
            DayMath.add(Frequency(n: 3, unit: .days), to: date(2026, 6, 9), calendar: cal)
                == date(2026, 6, 12))
        #expect(
            DayMath.add(Frequency(n: 1, unit: .weeks), to: date(2026, 6, 10), calendar: cal)
                == date(2026, 6, 17))
        // months / years → anchored
        #expect(
            DayMath.add(
                Frequency(n: 1, unit: .months), to: date(2026, 1, 31), anchorDay: 31,
                calendar: cal)
                == date(2026, 2, 28))
        #expect(
            DayMath.add(
                Frequency(n: 1, unit: .years), to: date(2028, 2, 29), anchorDay: 29,
                calendar: cal)
                == date(2029, 2, 28))
    }

    @Test("relative phrasing")
    func relativePhrase() {
        let today = date(2026, 6, 9)
        #expect(DayMath.relativePhrase(for: date(2026, 6, 9), from: today, calendar: cal) == "today")
        #expect(DayMath.relativePhrase(for: date(2026, 6, 10), from: today, calendar: cal) == "tomorrow")
        #expect(DayMath.relativePhrase(for: date(2026, 6, 8), from: today, calendar: cal) == "yesterday")
        #expect(DayMath.relativePhrase(for: date(2026, 6, 21), from: today, calendar: cal) == "in 12 days")
        #expect(DayMath.relativePhrase(for: date(2026, 6, 4), from: today, calendar: cal) == "5 days ago")
    }

    @Test("absolute phrasing names adjacent days, dates everything else")
    func absolutePhrase() {
        let today = date(2026, 6, 9)
        #expect(DayMath.absolutePhrase(for: date(2026, 6, 9), from: today, calendar: cal) == "today")
        #expect(
            DayMath.absolutePhrase(for: date(2026, 6, 10), from: today, calendar: cal) == "tomorrow")
        #expect(
            DayMath.absolutePhrase(for: date(2026, 6, 8), from: today, calendar: cal) == "yesterday")
        // Beyond a day in either direction → the calendar date, abbreviated month.
        let far = date(2026, 6, 17)
        #expect(
            DayMath.absolutePhrase(for: far, from: today, calendar: cal)
                == far.formatted(.dateTime.month(.abbreviated).day()))
    }
}

// MARK: - Urgency

struct UrgencyTests {
    private let today = date(2026, 6, 9)

    private func urgency(dueOffset: Int, grace: Int, snoozedUntil: Date? = nil) -> Urgency {
        Urgency.compute(
            due: DayMath.addDays(dueOffset, to: today, calendar: cal),
            snoozedUntil: snoozedUntil, grace: grace, today: today, calendar: cal)
    }

    @Test("tier boundaries around the grace window (grace = 3)")
    func tierBoundaries() {
        #expect(urgency(dueOffset: 4, grace: 3).tier == .later)    // off > g
        #expect(urgency(dueOffset: 3, grace: 3).tier == .almost)   // off == g
        #expect(urgency(dueOffset: 1, grace: 3).tier == .almost)
        #expect(urgency(dueOffset: 0, grace: 3).tier == .due)
        #expect(urgency(dueOffset: -1, grace: 3).tier == .overdue)
        #expect(urgency(dueOffset: -3, grace: 3).tier == .overdue) // off == -g
        #expect(urgency(dueOffset: -4, grace: 3).tier == .late)    // off < -g
    }

    @Test("zero grace: only due/overdue-late, nothing is 'almost'")
    func zeroGrace() {
        #expect(urgency(dueOffset: 1, grace: 0).tier == .later)
        #expect(urgency(dueOffset: 0, grace: 0).tier == .due)
        #expect(urgency(dueOffset: -1, grace: 0).tier == .late)
    }

    @Test("active snooze replaces the due date for urgency")
    func snoozeReplacesDue() {
        // 5 days overdue but snoozed until tomorrow → almost, computed from snooze date.
        let u = urgency(dueOffset: -5, grace: 1, snoozedUntil: DayMath.addDays(1, to: today, calendar: cal))
        #expect(u.tier == .almost)
        #expect(u.isSnoozed)
        #expect(u.daysUntilDue == 1)
    }

    @Test("expired or same-day snooze is ignored")
    func expiredSnooze() {
        let expired = urgency(dueOffset: -2, grace: 1, snoozedUntil: DayMath.addDays(-1, to: today, calendar: cal))
        #expect(!expired.isSnoozed)
        #expect(expired.tier == .late)
        // Snoozed-until-today is no longer "snoozed" — the beat is back.
        let sameDay = urgency(dueOffset: -2, grace: 1, snoozedUntil: today)
        #expect(!sameDay.isSnoozed)
    }

    @Test("effective due date helper mirrors snooze semantics")
    func effectiveDue() {
        let due = date(2026, 6, 4)
        let snooze = date(2026, 6, 12)
        #expect(
            Urgency.effectiveDue(due: due, snoozedUntil: snooze, today: today, calendar: cal)
                == snooze)
        #expect(
            Urgency.effectiveDue(due: due, snoozedUntil: nil, today: today, calendar: cal) == due)
    }

    @Test("chip labels per spec")
    func chipLabels() {
        #expect(urgency(dueOffset: 12, grace: 3).chipLabel == "in 12 days")
        #expect(urgency(dueOffset: 1, grace: 3).chipLabel == "tomorrow")
        #expect(urgency(dueOffset: 0, grace: 3).chipLabel == "Due today")
        #expect(urgency(dueOffset: -2, grace: 3).chipLabel == "2d overdue")
        #expect(urgency(dueOffset: -9, grace: 3).chipLabel == "9d overdue")
    }

    @Test("tier severity ordering drives sort")
    func tierOrdering() {
        #expect(UrgencyTier.later < .almost)
        #expect(UrgencyTier.almost < .due)
        #expect(UrgencyTier.due < .overdue)
        #expect(UrgencyTier.overdue < .late)
    }
}

// MARK: - Daily digest copy

struct DigestCopyTests {
    private func overdue(_ name: String, _ days: Int) -> DigestCopy.OverdueBeat {
        DigestCopy.OverdueBeat(name: name, daysOverdue: days)
    }

    @Test("nothing due or overdue yields no digest")
    func empty() {
        #expect(DigestCopy.body(dueToday: [], overdue: []) == nil)
    }

    @Test("due-only: single is named, multiple is counted")
    func dueOnly() {
        #expect(
            DigestCopy.body(dueToday: ["Mow the Lawn"], overdue: [])
                == "Mow the Lawn is due today.")
        #expect(
            DigestCopy.body(dueToday: ["Mow the Lawn", "Water Plants"], overdue: [])
                == "2 beats due today.")
    }

    @Test("overdue-only: single names the beat and its day count")
    func overdueOnly() {
        #expect(
            DigestCopy.body(dueToday: [], overdue: [overdue("Shave", 3)])
                == "Shave is 3 days overdue.")
        #expect(
            DigestCopy.body(dueToday: [], overdue: [overdue("Shave", 1)])
                == "Shave is 1 day overdue.")
        #expect(
            DigestCopy.body(dueToday: [], overdue: [overdue("Shave", 3), overdue("Floss", 1)])
                == "2 beats overdue.")
    }

    @Test("combined phrasing across due/overdue cardinalities")
    func combined() {
        // 1 / 1
        #expect(
            DigestCopy.body(dueToday: ["Mow the Lawn"], overdue: [overdue("Shave", 3)])
                == "Mow the Lawn is due today and Shave is 3 days overdue.")
        // 2+ / 1
        #expect(
            DigestCopy.body(
                dueToday: ["Mow the Lawn", "Water Plants"], overdue: [overdue("Shave", 3)])
                == "2 beats due today and Shave is 3 days overdue.")
        // 1 / 2+  → "beats are overdue"
        #expect(
            DigestCopy.body(
                dueToday: ["Mow the Lawn"], overdue: [overdue("Shave", 3), overdue("Floss", 1)])
                == "Mow the Lawn is due today and 2 beats are overdue.")
        // 2+ / 2+ → "more are overdue"
        #expect(
            DigestCopy.body(
                dueToday: ["Mow the Lawn", "Water Plants"],
                overdue: [overdue("Shave", 3), overdue("Floss", 1)])
                == "2 beats due today and 2 more are overdue.")
    }
}
