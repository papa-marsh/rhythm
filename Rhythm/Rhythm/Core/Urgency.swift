//
//  Urgency.swift
//  Rhythm
//
//  The urgency model: given today, a beat's effective due date (snoozes
//  replace the due date while active), and its grace period, compute a
//  tier that drives the leading bar color, due chip, sort order, and the
//  Today/Later split.
//

import Foundation

enum UrgencyTier: Int, Comparable, CaseIterable, Sendable {
    /// Outside the grace window; not yet relevant. Lives in the "Later" section.
    case later = 0
    /// Within grace, coming up.
    case almost = 1
    /// Due today.
    case due = 2
    /// Past due, within one grace period.
    case overdue = 3
    /// Beyond one grace period past due.
    case late = 4

    static func < (lhs: UrgencyTier, rhs: UrgencyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whether the beat is inside its attention window (everything but `later`).
    var isUrgent: Bool { self != .later }
}

struct Urgency: Equatable, Sendable {
    let tier: UrgencyTier
    /// Days from today to the effective due date (positive = future).
    let daysUntilDue: Int
    /// Whether an active snooze is supplying the effective due date.
    let isSnoozed: Bool

    /// Compute urgency for a beat.
    ///
    /// While `snoozedUntil` is strictly in the future, it *is* the effective
    /// due date — the beat leaves the radar until then.
    static func compute(
        due: Date,
        snoozedUntil: Date?,
        grace: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Urgency {
        let snoozed = isActivelySnoozed(snoozedUntil: snoozedUntil, today: today, calendar: calendar)
        let effective = snoozed ? snoozedUntil! : due
        let off = DayMath.days(from: today, to: effective, calendar: calendar)

        let tier: UrgencyTier =
            if off > grace { .later }
            else if off > 0 { .almost }
            else if off == 0 { .due }
            else if off >= -grace { .overdue }
            else { .late }

        return Urgency(tier: tier, daysUntilDue: off, isSnoozed: snoozed)
    }

    static func isActivelySnoozed(
        snoozedUntil: Date?, today: Date, calendar: Calendar = .current
    ) -> Bool {
        guard let snoozedUntil else { return false }
        return DayMath.days(from: today, to: snoozedUntil, calendar: calendar) > 0
    }

    static func effectiveDue(
        due: Date, snoozedUntil: Date?, today: Date, calendar: Calendar = .current
    ) -> Date {
        isActivelySnoozed(snoozedUntil: snoozedUntil, today: today, calendar: calendar)
            ? snoozedUntil! : due
    }

    /// Chip copy per spec: relative date for later/almost, "Due today",
    /// "{n}d overdue" for overdue/late.
    var chipLabel: String {
        switch tier {
        case .later, .almost:
            switch daysUntilDue {
            case 1: "tomorrow"
            default: "in \(daysUntilDue) days"
            }
        case .due:
            "Due today"
        case .overdue, .late:
            "\(-daysUntilDue)d overdue"
        }
    }
}
