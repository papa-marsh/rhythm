//
//  Beat.swift
//  Rhythm
//
//  A single concrete occurrence — either the active beat of a cadence or a
//  standalone one-off. Identity fields (name/color/glyph/note) are *copied*
//  from the cadence at generation time: editing a beat never edits its
//  cadence, per spec.
//

import Foundation
import SwiftData

@Model
final class Beat {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var colorHex: String = "#0A84FF"
    var glyph: String = "🚩"
    var note: String = ""

    var due: Date = Date.now
    var grace: Int = 1
    /// While strictly in the future, this *is* the effective due date for
    /// urgency, sorting, badge, and notifications.
    var snoozedUntil: Date? = nil

    /// Per-beat notification overrides. nil → inherit (cadence settings for
    /// linked beats; standard defaults for standalone).
    var notifyAlmostOverride: Bool? = nil
    var notifyDueOverride: Bool? = nil
    var notifyOverdueOverride: Bool? = nil
    var notifyMinutesOverride: Int? = nil

    var cadence: Cadence? = nil

    init(
        name: String,
        colorHex: String,
        glyph: String,
        note: String = "",
        due: Date,
        grace: Int
    ) {
        self.name = name
        self.colorHex = colorHex
        self.glyph = glyph
        self.note = note
        self.due = due
        self.grace = grace
    }

    /// New active beat for a cadence, copying identity at generation time.
    convenience init(generatedFor cadence: Cadence, due: Date) {
        self.init(
            name: cadence.name,
            colorHex: cadence.colorHex,
            glyph: cadence.glyph,
            note: cadence.note,
            due: due,
            grace: cadence.grace
        )
    }

    // MARK: Derived state

    /// Resolved notification preferences: per-beat overrides on top of the
    /// cadence's settings (or standard defaults when standalone).
    var resolvedNotify: NotifyPreferences {
        let base = cadence?.notify ?? .standard
        return NotifyPreferences(
            almost: notifyAlmostOverride ?? base.almost,
            due: notifyDueOverride ?? base.due,
            overdue: notifyOverdueOverride ?? base.overdue,
            minutes: notifyMinutesOverride ?? base.minutes
        )
    }

    func urgency(today: Date, calendar: Calendar = .current) -> Urgency {
        Urgency.compute(
            due: due, snoozedUntil: snoozedUntil, grace: grace, today: today, calendar: calendar)
    }

    func effectiveDue(today: Date, calendar: Calendar = .current) -> Date {
        Urgency.effectiveDue(due: due, snoozedUntil: snoozedUntil, today: today, calendar: calendar)
    }
}
