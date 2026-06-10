//
//  RhythmStore.swift
//  Rhythm
//
//  The only write path to the model layer. Every mutation that changes
//  beats/cadences/discoveries goes through here so that (a) the
//  one-active-beat-per-cadence invariant holds and (b) notification/badge
//  replanning can hang off a single hook.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class RhythmStore {
    let context: ModelContext
    var calendar: Calendar

    /// Called after every mutation. Stage 8 hangs notification/badge
    /// replanning here.
    var onMutation: (() -> Void)?

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    private var today: Date { DayMath.startOfDay(.now, calendar: calendar) }

    private func mutated() {
        try? context.save()
        onMutation?()
    }

    // MARK: - Beat lifecycle

    /// Complete a beat: record history, generate the next beat (linked), or
    /// remove it (standalone).
    func complete(_ beat: Beat) {
        advance(beat, action: .completed, asOf: today)
    }

    /// Complete a beat retroactively. Relative schedules count the next beat
    /// from the backdated completion day.
    func complete(_ beat: Beat, on date: Date) {
        let day = min(DayMath.startOfDay(date, calendar: calendar), today)
        advance(beat, action: .completed, asOf: day)
    }

    /// Skip a beat: same generation rules as complete, recorded as skipped.
    func skip(_ beat: Beat) {
        advance(beat, action: .skipped, asOf: today)
    }

    private func advance(_ beat: Beat, action: HistoryAction, asOf day: Date) {
        if let cadence = beat.cadence {
            let entry = HistoryEntry(date: day, action: action)
            context.insert(entry)
            entry.cadence = cadence

            let nextDue: Date =
                switch cadence.scheduleType {
                case .relative:
                    // From the completion day; anchor = the day you completed.
                    DayMath.add(
                        cadence.frequency, to: day,
                        anchorDay: calendar.component(.day, from: day), calendar: calendar)
                case .fixed:
                    // From the previous due, regardless of completion date.
                    DayMath.add(
                        cadence.frequency, to: beat.due, anchorDay: cadence.anchorDay,
                        calendar: calendar)
                }

            context.delete(beat)
            insertActiveBeat(for: cadence, due: nextDue)
        } else {
            context.delete(beat)
        }
        mutated()
    }

    func snooze(_ beat: Beat, until date: Date) {
        beat.snoozedUntil = DayMath.startOfDay(date, calendar: calendar)
        mutated()
    }

    /// One-tap snooze: grace-period length, measured from today when the
    /// beat is due/overdue, or from the effective due date (including an
    /// existing snooze) when that's in the future — so repeated snoozes
    /// compound: due yesterday with grace 3 → +3 days, again → +6 days.
    @discardableResult
    func quickSnooze(_ beat: Beat) -> Date {
        let effective = Urgency.effectiveDue(
            due: beat.due, snoozedUntil: beat.snoozedUntil, today: today, calendar: calendar)
        let base = max(today, effective)
        let date = DayMath.addDays(
            Grace.snoozeDays(forGrace: beat.grace), to: base, calendar: calendar)
        snooze(beat, until: date)
        return date
    }

    func resumeSnooze(_ beat: Beat) {
        beat.snoozedUntil = nil
        mutated()
    }

    /// Delete a standalone beat. Linked beats are never deleted directly —
    /// they're replaced by advance() or removed with their cadence.
    func deleteStandalone(_ beat: Beat) {
        precondition(beat.cadence == nil, "Only standalone beats can be deleted directly")
        context.delete(beat)
        mutated()
    }

    func createStandaloneBeat(
        name: String, colorHex: String, glyph: String, due: Date, grace: Int
    ) -> Beat {
        let beat = Beat(
            name: name, colorHex: colorHex, glyph: glyph,
            due: DayMath.startOfDay(due, calendar: calendar), grace: grace)
        context.insert(beat)
        mutated()
        return beat
    }

    /// Persist edits from the beat detail editor. Affects only this beat.
    func saveEdits(_ beat: Beat) {
        mutated()
    }

    // MARK: - Cadences

    @discardableResult
    func createCadence(
        name: String,
        colorHex: String,
        glyph: String,
        note: String = "",
        scheduleType: ScheduleType,
        frequency: Frequency,
        grace: Int,
        firstDue: Date,
        notify: NotifyPreferences
    ) -> Cadence {
        let due = DayMath.startOfDay(firstDue, calendar: calendar)
        let cadence = Cadence(
            name: name, colorHex: colorHex, glyph: glyph, note: note,
            scheduleType: scheduleType, frequency: frequency, grace: grace,
            anchorDay: calendar.component(.day, from: due), notify: notify)
        context.insert(cadence)
        insertActiveBeat(for: cadence, due: due)
        mutated()
        return cadence
    }

    /// Edit a cadence definition. The active beat picks up identity, grace,
    /// and (optionally) a new due date; history is untouched.
    func updateCadence(
        _ cadence: Cadence,
        name: String,
        colorHex: String,
        glyph: String,
        note: String,
        scheduleType: ScheduleType,
        frequency: Frequency,
        grace: Int,
        due: Date?,
        notify: NotifyPreferences
    ) {
        cadence.name = name
        cadence.colorHex = colorHex
        cadence.glyph = glyph
        cadence.note = note
        cadence.scheduleType = scheduleType
        cadence.frequency = frequency
        cadence.grace = grace
        cadence.notify = notify

        if let beat = cadence.activeBeat {
            beat.name = name
            beat.colorHex = colorHex
            beat.glyph = glyph
            beat.note = note
            beat.grace = grace
            if let due {
                let day = DayMath.startOfDay(due, calendar: calendar)
                beat.due = day
                cadence.anchorDay = calendar.component(.day, from: day)
            }
        } else if let due {
            // Self-heal the invariant if the active beat ever went missing.
            let day = DayMath.startOfDay(due, calendar: calendar)
            insertActiveBeat(for: cadence, due: day)
            cadence.anchorDay = calendar.component(.day, from: day)
        }
        mutated()
    }

    func deleteCadence(_ cadence: Cadence) {
        context.delete(cadence)  // cascades to beats + history
        mutated()
    }

    /// Enforces the one-active-beat invariant: inserting the new beat clears
    /// any others first.
    private func insertActiveBeat(for cadence: Cadence, due: Date) {
        for stray in cadence.beats ?? [] {
            context.delete(stray)
        }
        let beat = Beat(generatedFor: cadence, due: due)
        context.insert(beat)
        beat.cadence = cadence
    }

    // MARK: - Discoveries

    @discardableResult
    func createDiscovery(
        name: String, colorHex: String, glyph: String, logFirstOccurrenceToday: Bool
    ) -> Discovery {
        let discovery = Discovery(name: name, colorHex: colorHex, glyph: glyph)
        context.insert(discovery)
        if logFirstOccurrenceToday {
            appendLog(to: discovery, date: today)
        }
        mutated()
        return discovery
    }

    func logOccurrence(_ discovery: Discovery) {
        appendLog(to: discovery, date: today)
        mutated()
    }

    func updateDiscovery(
        _ discovery: Discovery, name: String, colorHex: String, glyph: String, note: String
    ) {
        discovery.name = name
        discovery.colorHex = colorHex
        discovery.glyph = glyph
        discovery.note = note
        mutated()
    }

    func setLogDate(_ log: DiscoveryLog, to date: Date) {
        log.date = DayMath.startOfDay(date, calendar: calendar)
        mutated()
    }

    func deleteLog(_ log: DiscoveryLog) {
        context.delete(log)
        mutated()
    }

    private func appendLog(to discovery: Discovery, date: Date) {
        let log = DiscoveryLog(date: date)
        context.insert(log)
        log.discovery = discovery
    }

    func deleteDiscovery(_ discovery: Discovery) {
        context.delete(discovery)
        mutated()
    }

    /// Convert a discovery into a real cadence; the discovery is removed.
    @discardableResult
    func convertDiscovery(
        _ discovery: Discovery,
        scheduleType: ScheduleType,
        frequency: Frequency,
        grace: Int,
        firstDue: Date,
        notify: NotifyPreferences
    ) -> Cadence {
        let cadence = createCadence(
            name: discovery.name, colorHex: discovery.colorHex, glyph: discovery.glyph,
            note: discovery.note, scheduleType: scheduleType, frequency: frequency,
            grace: grace, firstDue: firstDue, notify: notify)
        context.delete(discovery)
        mutated()
        return cadence
    }
}
