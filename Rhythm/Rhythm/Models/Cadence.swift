//
//  Cadence.swift
//  Rhythm
//
//  A recurring item definition. Owns at most one active Beat at a time
//  (enforced by RhythmStore — CloudKit forbids schema-level uniqueness)
//  and an append-only history of completed/skipped events.
//
//  CloudKit rules shape this schema: every property has a default,
//  relationships are optional with explicit inverses, no unique constraints.
//

import Foundation
import SwiftData

@Model
final class Cadence {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var colorHex: String = "#5E5CE6"
    var glyph: String = "🔁"
    var note: String = ""

    var scheduleTypeRaw: String = ScheduleType.relative.rawValue
    var everyN: Int = 1
    var everyUnitRaw: String = FrequencyUnit.weeks.rawValue
    var grace: Int = 1
    /// Original due day-of-month, preserved across cycles so month/year
    /// intervals clamp without compounding (31st → Feb 28 → Mar 31).
    var anchorDay: Int = 1

    var notifyAlmost: Bool = false
    var notifyDue: Bool = true
    var notifyOverdue: Bool = true
    var notifyMinutes: Int = 540  // 9:00 AM

    @Relationship(deleteRule: .cascade, inverse: \Beat.cadence)
    var beats: [Beat]? = []

    @Relationship(deleteRule: .cascade, inverse: \HistoryEntry.cadence)
    var history: [HistoryEntry]? = []

    init(
        name: String,
        colorHex: String,
        glyph: String,
        note: String = "",
        scheduleType: ScheduleType,
        frequency: Frequency,
        grace: Int,
        anchorDay: Int,
        notify: NotifyPreferences = .standard
    ) {
        self.name = name
        self.colorHex = colorHex
        self.glyph = glyph
        self.note = note
        self.scheduleTypeRaw = scheduleType.rawValue
        self.everyN = frequency.n
        self.everyUnitRaw = frequency.unit.rawValue
        self.grace = grace
        self.anchorDay = anchorDay
        self.notifyAlmost = notify.almost
        self.notifyDue = notify.due
        self.notifyOverdue = notify.overdue
        self.notifyMinutes = notify.minutes
    }

    // MARK: Typed accessors over CloudKit-safe raw storage

    var scheduleType: ScheduleType {
        get { ScheduleType(rawValue: scheduleTypeRaw) ?? .relative }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    var frequency: Frequency {
        get { Frequency(n: everyN, unit: FrequencyUnit(rawValue: everyUnitRaw) ?? .weeks) }
        set {
            everyN = newValue.n
            everyUnitRaw = newValue.unit.rawValue
        }
    }

    var notify: NotifyPreferences {
        get {
            NotifyPreferences(
                almost: notifyAlmost, due: notifyDue, overdue: notifyOverdue,
                minutes: notifyMinutes)
        }
        set {
            notifyAlmost = newValue.almost
            notifyDue = newValue.due
            notifyOverdue = newValue.overdue
            notifyMinutes = newValue.minutes
        }
    }

    /// The single active beat (invariant: never more than one).
    var activeBeat: Beat? { beats?.first }

    /// History sorted most-recent-first (relationship order is unspecified).
    var sortedHistory: [HistoryEntry] {
        (history ?? []).sorted { $0.date > $1.date }
    }

    /// Average actual interval in days between history events, or nil with
    /// fewer than two events. Compared against the target to surface drift.
    var actualAverageDays: Int? {
        let dates = sortedHistory.map(\.date)
        guard dates.count >= 2 else { return nil }
        let total = DayMath.days(from: dates[dates.count - 1], to: dates[0])
        return Int((Double(total) / Double(dates.count - 1)).rounded())
    }
}

@Model
final class HistoryEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var actionRaw: String = HistoryAction.completed.rawValue
    var cadence: Cadence? = nil

    init(date: Date, action: HistoryAction) {
        self.date = date
        self.actionRaw = action.rawValue
    }

    var action: HistoryAction {
        get { HistoryAction(rawValue: actionRaw) ?? .completed }
        set { actionRaw = newValue.rawValue }
    }
}
