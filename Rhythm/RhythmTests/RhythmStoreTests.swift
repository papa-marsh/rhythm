//
//  RhythmStoreTests.swift
//  RhythmTests
//
//  Protects the beat lifecycle: next-beat generation for Relative vs Fixed
//  schedules, history recording, snooze semantics, the one-active-beat
//  invariant, and discovery conversion.
//

import Foundation
import SwiftData
import Testing

@testable import Rhythm

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

@MainActor
private func makeStore() throws -> RhythmStore {
    let schema = Schema([
        Cadence.self, Beat.self, HistoryEntry.self, Discovery.self, DiscoveryLog.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    return RhythmStore(context: ModelContext(container), calendar: cal)
}

private var today: Date { DayMath.startOfDay(.now, calendar: cal) }

@MainActor
struct BeatLifecycleTests {

    @Test("completing a relative cadence schedules the next beat from today")
    func completeRelative() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Mow", colorHex: "#34C759", glyph: "🌿",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: DayMath.addDays(-3, to: today, calendar: cal),
            notify: .standard)

        store.complete(try #require(cadence.activeBeat))

        // Completed 3 days late, but the next beat counts from *today*.
        let next = try #require(cadence.activeBeat)
        #expect(next.due == DayMath.addDays(7, to: today, calendar: cal))
        #expect(cadence.sortedHistory.count == 1)
        #expect(cadence.sortedHistory[0].action == .completed)
        #expect(cadence.sortedHistory[0].date == today)
    }

    @Test("completing a fixed cadence schedules from the previous due date")
    func completeFixed() throws {
        let store = try makeStore()
        // Trash was due 2 days ago; doing it late must not drift the schedule.
        let previousDue = DayMath.addDays(-2, to: today, calendar: cal)
        let cadence = store.createCadence(
            name: "Trash", colorHex: "#8E8E93", glyph: "🗑️",
            scheduleType: .fixed, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: previousDue, notify: .standard)

        store.complete(try #require(cadence.activeBeat))

        let next = try #require(cadence.activeBeat)
        #expect(next.due == DayMath.addDays(7, to: previousDue, calendar: cal))
    }

    @Test("fixed monthly cadences preserve the original anchor day")
    func fixedMonthlyAnchor() throws {
        let store = try makeStore()
        // Anchor on the 31st: regardless of clamped intermediate months, the
        // anchor day persists on the cadence and re-applies each cycle.
        let firstDue = date(2026, 1, 31)
        let cadence = store.createCadence(
            name: "Bill", colorHex: "#FFCC00", glyph: "⚡️",
            scheduleType: .fixed, frequency: Frequency(n: 1, unit: .months),
            grace: 5, firstDue: firstDue, notify: .standard)
        #expect(cadence.anchorDay == 31)

        store.complete(try #require(cadence.activeBeat))  // Jan 31 → Feb 28
        #expect(try #require(cadence.activeBeat).due == date(2026, 2, 28))

        store.complete(try #require(cadence.activeBeat))  // Feb 28 → Mar 31 (anchor!)
        #expect(try #require(cadence.activeBeat).due == date(2026, 3, 31))
    }

    @Test("backdated completion counts relative schedules from that day")
    func backdatedComplete() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Mow", colorHex: "#34C759", glyph: "🌿",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: today, notify: .standard)

        let threeDaysAgo = DayMath.addDays(-3, to: today, calendar: cal)
        store.complete(try #require(cadence.activeBeat), on: threeDaysAgo)

        #expect(cadence.sortedHistory.first?.date == threeDaysAgo)
        #expect(
            try #require(cadence.activeBeat).due
                == DayMath.addDays(7, to: threeDaysAgo, calendar: cal))
    }

    @Test("backdated completion in the future clamps to today")
    func backdatedFutureClamps() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Mow", colorHex: "#34C759", glyph: "🌿",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: today, notify: .standard)

        store.complete(
            try #require(cadence.activeBeat), on: DayMath.addDays(5, to: today, calendar: cal))

        #expect(cadence.sortedHistory.first?.date == today)
        #expect(try #require(cadence.activeBeat).due == DayMath.addDays(7, to: today, calendar: cal))
    }

    @Test(
        "skips date history and advance according to schedule type and due day",
        arguments: [
            (ScheduleType.fixed, -14, -14, -7),
            (.relative, -14, 0, 7),
            (.fixed, 0, 0, 7),
            (.relative, 0, 0, 7),
            (.fixed, 3, 0, 10),
            (.relative, 3, 0, 10),
        ])
    func skip(schedule: ScheduleType, dueOffset: Int, historyOffset: Int, nextOffset: Int) throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Water ferns", colorHex: "#32ADE6", glyph: "🪴",
            scheduleType: schedule, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: DayMath.addDays(dueOffset, to: today, calendar: cal),
            notify: .standard)

        store.skip(try #require(cadence.activeBeat))

        #expect(cadence.sortedHistory.count == 1)
        #expect(cadence.sortedHistory.first?.action == .skipped)
        #expect(
            cadence.sortedHistory.first?.date == DayMath.addDays(historyOffset, to: today, calendar: cal))
        #expect(
            try #require(cadence.activeBeat).due == DayMath.addDays(nextOffset, to: today, calendar: cal))
        #expect((cadence.beats ?? []).count == 1)
    }

    @Test("an overdue fixed skip allows backdating completion of the next occurrence")
    func completeAfterOverdueFixedSkip() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Trash", colorHex: "#8E8E93", glyph: "🗑️",
            scheduleType: .fixed, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: DayMath.addDays(-14, to: today, calendar: cal),
            notify: .standard)

        store.skip(try #require(cadence.activeBeat))

        let next = try #require(cadence.activeBeat)
        let completionDay = DayMath.addDays(-5, to: today, calendar: cal)
        let range = next.completionDateRange(today: today, calendar: cal)
        #expect(range.lowerBound == .distantPast)
        #expect(range.contains(completionDay))
        #expect(range.upperBound == today)

        store.complete(next, on: completionDay)

        #expect(cadence.sortedHistory.count == 2)
        #expect(cadence.sortedHistory.first?.action == .completed)
        #expect(cadence.sortedHistory.first?.date == completionDay)
        #expect(try #require(cadence.activeBeat).due == today)
        #expect((cadence.beats ?? []).count == 1)
    }

    @Test(
        "only actual completions bound backdating across skips",
        arguments: [ScheduleType.fixed, .relative])
    func completionRangeIgnoresSkips(schedule: ScheduleType) throws {
        let store = try makeStore()
        let priorCompletion = DayMath.addDays(-21, to: today, calendar: cal)
        let cadence = store.createCadence(
            name: "Water ferns", colorHex: "#32ADE6", glyph: "🪴",
            scheduleType: schedule, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: priorCompletion, notify: .standard)
        store.complete(try #require(cadence.activeBeat), on: priorCompletion)
        store.skip(try #require(cadence.activeBeat))

        let next = try #require(cadence.activeBeat)
        let completionDay = DayMath.addDays(-16, to: today, calendar: cal)
        let range = next.completionDateRange(today: today, calendar: cal)
        #expect(range.lowerBound == priorCompletion)
        #expect(range.contains(priorCompletion))
        #expect(range.contains(completionDay))
        #expect(!range.contains(DayMath.addDays(-1, to: priorCompletion, calendar: cal)))
        #expect(!range.contains(DayMath.addDays(1, to: today, calendar: cal)))

        store.complete(next, on: completionDay)

        let following = try #require(cadence.activeBeat)
        #expect(following.completionDateRange(today: today, calendar: cal).lowerBound == completionDay)
        let expectedDue = schedule == .fixed ? today : DayMath.addDays(-9, to: today, calendar: cal)
        #expect(following.due == expectedDue)
        #expect(cadence.sortedHistory.count == 3)
        #expect((cadence.beats ?? []).count == 1)
    }

    @Test("early relative monthly skips anchor the next interval to the due day")
    func earlyRelativeMonthlySkip() throws {
        let store = try makeStore()
        let year = cal.component(.year, from: today) + 1
        let cadence = store.createCadence(
            name: "Filter", colorHex: "#32ADE6", glyph: "💧",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .months),
            grace: 5, firstDue: date(year, 1, 31), notify: .standard)

        store.skip(try #require(cadence.activeBeat))

        let februaryEnd = cal.range(of: .day, in: .month, for: date(year, 2, 1))!.count
        #expect(try #require(cadence.activeBeat).due == date(year, 2, februaryEnd))
        #expect(cadence.sortedHistory.first?.date == today)
    }

    @Test("fixed monthly skips preserve the original anchor across clamped months")
    func fixedMonthlySkips() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Bill", colorHex: "#FFCC00", glyph: "⚡️",
            scheduleType: .fixed, frequency: Frequency(n: 1, unit: .months),
            grace: 5, firstDue: date(2026, 1, 31), notify: .standard)

        store.skip(try #require(cadence.activeBeat))
        #expect(try #require(cadence.activeBeat).due == date(2026, 2, 28))
        store.skip(try #require(cadence.activeBeat))
        #expect(try #require(cadence.activeBeat).due == date(2026, 3, 31))
    }

    @Test("standalone completion dates have no history boundary")
    func standaloneCompletionRange() throws {
        let store = try makeStore()
        let beat = store.createStandaloneBeat(
            name: "Books", colorHex: "#AF52DE", glyph: "📚", due: today, grace: 2)

        #expect(beat.completionDateRange(today: today, calendar: cal) == Date.distantPast...today)
    }

    @Test("the one-active-beat invariant survives every advance")
    func oneActiveBeat() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Mow", colorHex: "#34C759", glyph: "🌿",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: today, notify: .standard)

        for _ in 0..<5 {
            store.complete(try #require(cadence.activeBeat))
            #expect((cadence.beats ?? []).count == 1)
        }
        #expect(cadence.sortedHistory.count == 5)
    }

    @Test("completing a standalone beat removes it without history")
    func standaloneComplete() throws {
        let store = try makeStore()
        let beat = store.createStandaloneBeat(
            name: "Return books", colorHex: "#AF52DE", glyph: "📚", due: today, grace: 2)

        store.complete(beat)

        let remaining = try store.context.fetch(FetchDescriptor<Beat>())
        #expect(remaining.isEmpty)
        let history = try store.context.fetch(FetchDescriptor<HistoryEntry>())
        #expect(history.isEmpty)
    }

    @Test("snooze sets the effective due date; resume clears it")
    func snoozeRoundTrip() throws {
        let store = try makeStore()
        let beat = store.createStandaloneBeat(
            name: "Call dentist", colorHex: "#FF2D55", glyph: "🦷",
            due: DayMath.addDays(-4, to: today, calendar: cal), grace: 2)

        let snoozeDate = DayMath.addDays(2, to: today, calendar: cal)
        store.snooze(beat, until: snoozeDate)
        #expect(beat.urgency(today: today, calendar: cal).isSnoozed)
        #expect(beat.effectiveDue(today: today, calendar: cal) == snoozeDate)
        // Original due is preserved for the "Originally due …" line.
        #expect(beat.due == DayMath.addDays(-4, to: today, calendar: cal))

        store.resumeSnooze(beat)
        #expect(!beat.urgency(today: today, calendar: cal).isSnoozed)
        #expect(beat.effectiveDue(today: today, calendar: cal) == beat.due)
    }

    @Test("quick snooze compounds from the effective due date")
    func quickSnoozeCompounds() throws {
        let store = try makeStore()
        // Due yesterday, grace 3: first snooze lands 3 days from today.
        let beat = store.createStandaloneBeat(
            name: "Books", colorHex: "#AF52DE", glyph: "📚",
            due: DayMath.addDays(-1, to: today, calendar: cal), grace: 3)

        let first = store.quickSnooze(beat)
        #expect(first == DayMath.addDays(3, to: today, calendar: cal))

        // Second snooze counts from the existing snooze date: 6 days out.
        let second = store.quickSnooze(beat)
        #expect(second == DayMath.addDays(6, to: today, calendar: cal))
    }

    @Test("quick snooze on a future beat counts from its due date")
    func quickSnoozeFutureBase() throws {
        let store = try makeStore()
        let due = DayMath.addDays(2, to: today, calendar: cal)
        let beat = store.createStandaloneBeat(
            name: "Dentist", colorHex: "#FF2D55", glyph: "🦷", due: due, grace: 3)

        // Due in 2 days, grace 3 → snoozed until 5 days from today.
        #expect(store.quickSnooze(beat) == DayMath.addDays(3, to: due, calendar: cal))
    }

    @Test("deleting a cadence cascades to its beat and history")
    func deleteCascades() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Haircut", colorHex: "#5E5CE6", glyph: "✂️",
            scheduleType: .relative, frequency: Frequency(n: 5, unit: .weeks),
            grace: 5, firstDue: today, notify: .standard)
        store.complete(try #require(cadence.activeBeat))

        store.deleteCadence(cadence)
        try store.context.save()

        #expect(try store.context.fetch(FetchDescriptor<Beat>()).isEmpty)
        #expect(try store.context.fetch(FetchDescriptor<HistoryEntry>()).isEmpty)
    }

    @Test("editing a cadence updates its active beat but not history")
    func editCadence() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Mow", colorHex: "#34C759", glyph: "🌿",
            scheduleType: .relative, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: today, notify: .standard)
        store.complete(try #require(cadence.activeBeat))

        let newDue = DayMath.addDays(10, to: today, calendar: cal)
        store.updateCadence(
            cadence, name: "Mow + edge", colorHex: "#30D158", glyph: "🌱", note: "Edges too",
            scheduleType: .fixed, frequency: Frequency(n: 2, unit: .weeks), grace: 2,
            due: newDue, notify: .standard)

        let beat = try #require(cadence.activeBeat)
        #expect(beat.name == "Mow + edge")
        #expect(beat.grace == 2)
        #expect(beat.due == newDue)
        #expect(cadence.anchorDay == cal.component(.day, from: newDue))
        #expect(cadence.sortedHistory.count == 1)  // untouched
    }
}

@MainActor
struct DiscoveryTests {

    @Test("suggested frequency is the average interval between logs")
    func suggestedFrequency() throws {
        let store = try makeStore()
        let discovery = makeDiscovery(
            in: store, name: "Descale", logOffsets: [-120, -48])

        #expect(discovery.isReadyToConvert)
        #expect(discovery.suggestedFrequencyDays == 72)
    }

    @Test("fewer than two logs is not convertible")
    func notReady() throws {
        let store = try makeStore()
        let discovery = store.createDiscovery(
            name: "Filter", colorHex: "#64D2FF", glyph: "💧", logFirstOccurrenceToday: true)
        #expect(discovery.logCount == 1)
        #expect(!discovery.isReadyToConvert)
        #expect(discovery.suggestedFrequencyDays == nil)

        store.logOccurrence(discovery)
        #expect(discovery.isReadyToConvert)
    }

    @Test("conversion creates a cadence with a beat and removes the discovery and its logs")
    func convert() throws {
        let store = try makeStore()
        let discovery = makeDiscovery(
            in: store, name: "Descale", logOffsets: [-144, -72])
        let days = try #require(discovery.suggestedFrequencyDays)

        let cadence = store.convertDiscovery(
            discovery,
            scheduleType: .relative,
            frequency: Frequency(approximateDays: days),
            grace: Grace.days(forFrequencyDays: days),
            firstDue: DayMath.addDays(days, to: today, calendar: cal),
            notify: .standard)

        #expect(cadence.name == "Descale")
        #expect(cadence.frequency.approximateDays == 72)
        #expect(cadence.activeBeat != nil)
        #expect(try store.context.fetch(FetchDescriptor<Discovery>()).isEmpty)
        #expect(try store.context.fetch(FetchDescriptor<DiscoveryLog>()).isEmpty)  // cascade
    }
}

@MainActor
private func makeDiscovery(in store: RhythmStore, name: String, logOffsets: [Int]) -> Discovery {
    let discovery = Discovery(name: name, colorHex: "#A2845E", glyph: "☕️")
    store.context.insert(discovery)
    for offset in logOffsets {
        let log = DiscoveryLog(date: DayMath.addDays(offset, to: today, calendar: cal))
        store.context.insert(log)
        log.discovery = discovery
    }
    return discovery
}

@MainActor
struct NotifyResolutionTests {

    @Test("beat overrides layer on top of cadence notification settings")
    func overrideResolution() throws {
        let store = try makeStore()
        let cadence = store.createCadence(
            name: "Trash", colorHex: "#8E8E93", glyph: "🗑️",
            scheduleType: .fixed, frequency: Frequency(n: 1, unit: .weeks),
            grace: 1, firstDue: today,
            notify: NotifyPreferences(almost: true, due: true, overdue: true, minutes: 18 * 60))
        let beat = try #require(cadence.activeBeat)

        // No overrides → inherits the cadence's settings.
        #expect(beat.resolvedNotify.almost)
        #expect(beat.resolvedNotify.minutes == 18 * 60)

        // Partial override changes only the overridden field.
        beat.notifyAlmostOverride = false
        beat.notifyMinutesOverride = 9 * 60
        #expect(!beat.resolvedNotify.almost)
        #expect(beat.resolvedNotify.due)
        #expect(beat.resolvedNotify.minutes == 9 * 60)
    }

    @Test("standalone beats fall back to standard defaults")
    func standaloneDefaults() throws {
        let store = try makeStore()
        let beat = store.createStandaloneBeat(
            name: "Renew passport", colorHex: "#0A84FF", glyph: "🛂", due: today, grace: 8)
        #expect(beat.resolvedNotify == .standard)
    }
}
