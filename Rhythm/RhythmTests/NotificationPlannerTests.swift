//
//  NotificationPlannerTests.swift
//  RhythmTests
//
//  Protects the notification plan: reminder timing against effective due
//  dates, the midnight badge timeline, badge consistency between the two,
//  and chronological prioritization within the 64-slot budget.
//

import Foundation
import Testing

@testable import Rhythm

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

/// "Now" for all tests: Jun 9 2026, 8:00 AM.
private let now = date(2026, 6, 9, 8, 0)
private let today = date(2026, 6, 9)

private func beat(
    name: String = "Beat",
    dueOffset: Int,
    grace: Int = 3,
    almost: Bool = true,
    due: Bool = true,
    overdue: Bool = true,
    minutes: Int = 9 * 60
) -> NotificationPlanner.BeatInput {
    NotificationPlanner.BeatInput(
        id: UUID(), name: name, glyph: "🔁",
        effectiveDue: DayMath.addDays(dueOffset, to: today, calendar: cal),
        grace: grace,
        notify: NotifyPreferences(almost: almost, due: due, overdue: overdue, minutes: minutes))
}

private func plan(
    _ beats: [NotificationPlanner.BeatInput], limit: Int = 64,
    digest: Bool = false, digestMinutes: Int = 9 * 60
) -> NotificationPlanner.Plan {
    NotificationPlanner.plan(
        beats: beats, now: now, digestEnabled: digest, digestMinutes: digestMinutes,
        limit: limit, calendar: cal)
}

struct ReminderPlanningTests {

    @Test("a future beat schedules almost/due/overdue at the notify time")
    func allThreeReminders() {
        let result = plan([beat(dueOffset: 5, grace: 3)])
        let reminders = result.notifications.filter { $0.kind != .badgeUpdate }

        #expect(reminders.count == 3)
        // almost: grace days before due = Jun 11, 9:00 AM
        #expect(reminders.first { $0.kind == .almost }?.fireDate == date(2026, 6, 11, 9, 0))
        // due: Jun 14
        #expect(reminders.first { $0.kind == .due }?.fireDate == date(2026, 6, 14, 9, 0))
        // overdue: one grace after = Jun 17
        #expect(reminders.first { $0.kind == .overdue }?.fireDate == date(2026, 6, 17, 9, 0))
    }

    @Test("disabled toggles drop their reminders")
    func togglesRespected() {
        let result = plan([beat(dueOffset: 5, almost: false, overdue: false)])
        let reminders = result.notifications.filter { $0.kind != .badgeUpdate }
        #expect(reminders.count == 1)
        #expect(reminders[0].kind == .due)
    }

    @Test("past fire moments are skipped, not scheduled retroactively")
    func pastSkipped() {
        // Due 10 days ago with grace 3: every reminder moment has passed.
        let result = plan([beat(dueOffset: -10, grace: 3)])
        #expect(result.notifications.filter { $0.kind != .badgeUpdate }.isEmpty)
    }

    @Test("a due-today beat with a notify time later today still fires")
    func laterTodayFires() {
        // Now is 8:00 AM; notify time 9:00 AM; due today.
        let result = plan([beat(dueOffset: 0, grace: 1)])
        let due = result.notifications.first { $0.kind == .due }
        #expect(due?.fireDate == date(2026, 6, 9, 9, 0))
    }

    @Test("zero grace: no almost reminder, overdue pushed a day off due")
    func zeroGrace() {
        let result = plan([beat(dueOffset: 2, grace: 0)])
        let kinds = result.notifications.filter { $0.kind != .badgeUpdate }.map(\.kind)
        #expect(!kinds.contains(.almost))
        #expect(result.notifications.first { $0.kind == .overdue }?.fireDate
            == date(2026, 6, 12, 9, 0))
    }
}

struct BadgeTimelineTests {

    @Test("current badge counts beats due today or earlier")
    func currentBadge() {
        let result = plan([
            beat(dueOffset: -3), beat(dueOffset: 0), beat(dueOffset: 2),
        ])
        #expect(result.currentBadge == 2)
    }

    @Test("midnight badge updates carry cumulative absolute counts")
    func cumulativeCounts() {
        let result = plan([
            beat(dueOffset: -1),  // already due
            beat(dueOffset: 2),  // becomes due Jun 11
            beat(dueOffset: 4),  // becomes due Jun 13
        ])
        let badges = result.notifications.filter { $0.kind == .badgeUpdate }
            .sorted { $0.fireDate < $1.fireDate }

        #expect(badges.count == 2)
        #expect(badges[0].fireDate == date(2026, 6, 11))  // midnight
        #expect(badges[0].badge == 2)
        #expect(badges[1].fireDate == date(2026, 6, 13))
        #expect(badges[1].badge == 3)
    }

    @Test("two beats landing the same day produce one update with both counted")
    func sameDayMerged() {
        let result = plan([beat(dueOffset: 3), beat(dueOffset: 3)])
        let badges = result.notifications.filter { $0.kind == .badgeUpdate }
        #expect(badges.count == 1)
        #expect(badges[0].badge == 2)
    }

    @Test("reminders carry the badge value for their fire day")
    func remindersCarryBadge() {
        let result = plan([
            beat(dueOffset: -1, almost: false, overdue: false),  // due yesterday
            beat(dueOffset: 3, grace: 2, almost: false, overdue: false),
        ])
        // The Jun 12 due reminder fires when both beats count.
        let due = result.notifications
            .filter { $0.kind == .due }
            .sorted { $0.fireDate < $1.fireDate }
        #expect(due.last?.badge == 2)
    }
}

struct BudgetTests {

    @Test("the 64-slot budget keeps the chronologically nearest events")
    func chronologicalPriority() {
        // 40 beats due across consecutive future days → 40 badge updates
        // + 40 due reminders = 80 candidates for 64 slots.
        let beats = (1...40).map {
            beat(dueOffset: $0, grace: 0, almost: false, overdue: false)
        }
        let result = plan(beats)

        #expect(result.notifications.count == 64)
        // Everything kept must fire earlier than everything dropped: the
        // last kept event is no later than ~day 32; nothing from day 40
        // except its badge would fit. Verify ordering is intact and the
        // nearest reminders all survived.
        let fireDates = result.notifications.map(\.fireDate)
        #expect(fireDates == fireDates.sorted())
        let keptReminders = result.notifications.count { $0.kind == .due }
        let keptBadges = result.notifications.count { $0.kind == .badgeUpdate }
        #expect(keptReminders + keptBadges == 64)
        // The first week's reminders and badge updates are all present.
        for offset in 1...7 {
            let day = DayMath.addDays(offset, to: today, calendar: cal)
            #expect(result.notifications.contains { $0.kind == .badgeUpdate && $0.fireDate == day })
            #expect(
                result.notifications.contains {
                    $0.kind == .due && cal.isDate($0.fireDate, inSameDayAs: day)
                })
        }
    }

    @Test("identifiers are unique within a plan")
    func uniqueIdentifiers() {
        let beats = (1...20).map { beat(dueOffset: $0 % 5) }
        let result = plan(beats)
        let ids = result.notifications.map(\.identifier)
        #expect(Set(ids).count == ids.count)
    }
}

struct DigestPlanningTests {

    /// The digest scheduled for today (Jun 9), at the default 9:00 AM.
    private func todaysDigest(_ plan: NotificationPlanner.Plan) -> PlannedNotification? {
        plan.notifications.first { $0.kind == .digest && $0.fireDate == date(2026, 6, 9, 9, 0) }
    }

    @Test("no digest unless enabled")
    func disabledByDefault() {
        let result = plan([beat(dueOffset: 0)])
        #expect(!result.notifications.contains { $0.kind == .digest })
    }

    @Test("a due-today beat produces today's digest, named, with the badge")
    func dueTodayDigest() {
        let result = plan([beat(name: "Mow the Lawn", dueOffset: 0)], digest: true)
        let digest = todaysDigest(result)
        #expect(digest?.title == "Today's Rhythm")
        #expect(digest?.body == "Mow the Lawn is due today.")
        #expect(digest?.badge == 1)
    }

    @Test("an overdue beat reads with its day count")
    func overdueDigest() {
        let result = plan([beat(name: "Shave", dueOffset: -3)], digest: true)
        #expect(todaysDigest(result)?.body == "Shave is 3 days overdue.")
    }

    @Test("multiple beats on one day collapse per the digest rules")
    func combinedDigest() {
        let result = plan(
            [
                beat(name: "Mow the Lawn", dueOffset: 0),
                beat(name: "Water Plants", dueOffset: 0),
                beat(name: "Shave", dueOffset: -3),
            ], digest: true)
        let digest = todaysDigest(result)
        #expect(digest?.body == "2 beats due today and Shave is 3 days overdue.")
        #expect(digest?.badge == 3)
    }

    @Test("quiet days get no digest; the first one lands on the due day")
    func quietDaysSkipped() {
        // Nothing is due or overdue until Jun 14.
        let result = plan([beat(dueOffset: 5, grace: 0, almost: false, overdue: false)], digest: true)
        let digests = result.notifications
            .filter { $0.kind == .digest }
            .sorted { $0.fireDate < $1.fireDate }
        #expect(digests.allSatisfy { $0.fireDate >= date(2026, 6, 14, 9, 0) })
        #expect(digests.first?.fireDate == date(2026, 6, 14, 9, 0))
        #expect(digests.first?.body == "Beat is due today.")
    }

    @Test("digest fires at the configured time")
    func digestTimeRespected() {
        let result = plan([beat(dueOffset: 0)], digest: true, digestMinutes: 18 * 60)
        #expect(result.notifications.first { $0.kind == .digest }?.fireDate
            == date(2026, 6, 9, 18, 0))
    }
}
