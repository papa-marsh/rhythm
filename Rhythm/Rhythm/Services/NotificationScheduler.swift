//
//  NotificationScheduler.swift
//  Rhythm
//
//  Applies the planner's output to UNUserNotificationCenter and keeps the
//  app icon badge current. Replanning runs after every store mutation, on
//  foreground, and on day rollover — cheap enough to be wholesale each
//  time (wipe pending, schedule the new set).
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class NotificationScheduler {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var replanTask: Task<Void, Never>?

    init(context: ModelContext, settings: AppSettings, calendar: Calendar = .current) {
        self.context = context
        self.settings = settings
        self.calendar = calendar
    }

    /// Ask once at startup; silently no-ops if already determined.
    func requestAuthorizationIfNeeded() async {
        #if DEBUG
            // Screenshot/dev automation: launch with -suppressNotificationPrompt
            // (e.g. `simctl launch <sim> marshallwarners.Rhythm -suppressNotificationPrompt`).
            if ProcessInfo.processInfo.arguments.contains("-suppressNotificationPrompt") {
                return
            }
        #endif
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Recompute and reschedule everything. Coalesces rapid successive
    /// calls (e.g. a burst of store mutations) into one pass.
    func replan() {
        replanTask?.cancel()
        let inputs = snapshotBeats()
        let showEmoji = settings.showEmoji
        let sound = settings.sound
        let calendar = calendar

        replanTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let plan = NotificationPlanner.plan(
                beats: inputs, now: .now, showEmoji: showEmoji, sound: sound,
                calendar: calendar)

            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            for notification in plan.notifications {
                try? await center.add(request(for: notification))
            }
            try? await center.setBadgeCount(plan.currentBadge)
        }
    }

    // MARK: Plumbing

    private func snapshotBeats() -> [NotificationPlanner.BeatInput] {
        let beats = (try? context.fetch(FetchDescriptor<Beat>())) ?? []
        let today = DayMath.startOfDay(.now, calendar: calendar)
        return beats.map { beat in
            NotificationPlanner.BeatInput(
                id: beat.id,
                name: beat.name,
                glyph: beat.glyph,
                effectiveDue: beat.effectiveDue(today: today, calendar: calendar),
                grace: beat.grace,
                notify: beat.resolvedNotify
            )
        }
    }

    private func request(for notification: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if let title = notification.title {
            content.title = title
        }
        if let body = notification.body {
            content.body = body
        }
        content.badge = NSNumber(value: notification.badge)
        if notification.kind == .badgeUpdate {
            // No alert content: delivered silently, updates the badge only.
            content.interruptionLevel = .passive
        } else if notification.sound {
            content.sound = .default
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: notification.fireDate)
        return UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }
}
