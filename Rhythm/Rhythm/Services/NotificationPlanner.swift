//
//  NotificationPlanner.swift
//  Rhythm
//
//  Pure planning logic for local notifications. Computes, from a snapshot
//  of active beats, the full desired set of pending notifications:
//
//  - Reminders per beat: almost (grace days before due), due (on the due
//    day), overdue (one grace after due) — at the beat's notify time,
//    against the *effective* due date (snoozes included).
//  - Badge timeline: a silent badge-only update at midnight for every
//    future day on which the count of due-or-overdue beats changes,
//    because iOS can't run code at midnight — each carries its absolute
//    pre-computed count.
//
//  Both kinds compete for iOS's 64-pending-notification budget; they're
//  interleaved chronologically so the near term is always fully covered
//  and accuracy degrades gracefully at the horizon. Reminders also carry
//  the badge value for their fire day so the two can never disagree.
//

import Foundation

struct PlannedNotification: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case almost, due, overdue, badgeUpdate
    }

    let identifier: String
    let fireDate: Date
    let kind: Kind
    let title: String?
    let body: String?
    let badge: Int
    let sound: Bool
}

enum NotificationPlanner {

    /// Snapshot of one active beat, decoupled from SwiftData.
    struct BeatInput: Sendable {
        let id: UUID
        let name: String
        let glyph: String
        /// Effective due date (snoozedUntil when actively snoozed).
        let effectiveDue: Date
        let grace: Int
        let notify: NotifyPreferences
    }

    struct Plan: Sendable {
        /// Badge value right now.
        let currentBadge: Int
        /// Notifications to schedule, chronological, within the limit.
        let notifications: [PlannedNotification]
    }

    static func plan(
        beats: [BeatInput],
        now: Date,
        showEmoji: Bool = true,
        sound: Bool = true,
        limit: Int = 64,
        horizonDays: Int = 400,
        calendar: Calendar = .current
    ) -> Plan {
        let today = DayMath.startOfDay(now, calendar: calendar)
        let dueDays = beats.map { DayMath.startOfDay($0.effectiveDue, calendar: calendar) }

        func badgeCount(onOrBefore day: Date) -> Int {
            dueDays.count { $0 <= day }
        }

        var planned: [PlannedNotification] = []

        // ── Reminders ──
        for beat in beats {
            let due = DayMath.startOfDay(beat.effectiveDue, calendar: calendar)
            var events: [(kind: PlannedNotification.Kind, day: Date)] = []
            if beat.notify.almost, beat.grace > 0 {
                events.append((.almost, DayMath.addDays(-beat.grace, to: due, calendar: calendar)))
            }
            if beat.notify.due {
                events.append((.due, due))
            }
            if beat.notify.overdue {
                // One grace after due; at least a day so it never collides
                // with the due reminder.
                let offset = max(1, beat.grace)
                events.append((.overdue, DayMath.addDays(offset, to: due, calendar: calendar)))
            }

            for event in events {
                guard
                    let fireDate = calendar.date(
                        bySettingHour: beat.notify.minutes / 60,
                        minute: beat.notify.minutes % 60,
                        second: 0, of: event.day),
                    fireDate > now
                else { continue }

                planned.append(
                    PlannedNotification(
                        identifier: "beat-\(beat.id.uuidString)-\(suffix(event.kind))",
                        fireDate: fireDate,
                        kind: event.kind,
                        title: showEmoji ? "\(beat.glyph) \(beat.name)" : beat.name,
                        body: body(for: event.kind, beat: beat, calendar: calendar),
                        badge: badgeCount(onOrBefore: event.day),
                        sound: sound
                    ))
            }
        }

        // ── Badge timeline: midnight updates on days the count changes ──
        let horizon = DayMath.addDays(horizonDays, to: today, calendar: calendar)
        let changeDays = Set(dueDays.filter { $0 > today && $0 <= horizon })
        for day in changeDays {
            planned.append(
                PlannedNotification(
                    identifier: "badge-\(dayKey(day, calendar: calendar))",
                    fireDate: day,  // midnight, start of day
                    kind: .badgeUpdate,
                    title: nil,
                    body: nil,
                    badge: badgeCount(onOrBefore: day),
                    sound: false
                ))
        }

        // Chronological priority into the 64-slot budget.
        let limited = planned
            .sorted { $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate }
            .prefix(limit)

        return Plan(
            currentBadge: badgeCount(onOrBefore: today),
            notifications: Array(limited)
        )
    }

    // MARK: Copy

    private static func body(
        for kind: PlannedNotification.Kind, beat: BeatInput, calendar: Calendar
    ) -> String? {
        switch kind {
        case .almost:
            beat.grace == 1 ? "Due tomorrow." : "Due in \(beat.grace) days."
        case .due:
            "Due today."
        case .overdue:
            max(1, beat.grace) == 1
                ? "1 day overdue." : "\(max(1, beat.grace)) days overdue."
        case .badgeUpdate:
            nil
        }
    }

    private static func suffix(_ kind: PlannedNotification.Kind) -> String {
        switch kind {
        case .almost: "almost"
        case .due: "due"
        case .overdue: "overdue"
        case .badgeUpdate: "badge"
        }
    }

    private static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
