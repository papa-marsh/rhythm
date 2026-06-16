//
//  ScheduleType.swift
//  Rhythm
//
//  The two scheduling modes (spec: use the labels "Relative" and "Fixed"
//  in the UI), plus shared notification preference plumbing.
//

import Foundation

enum ScheduleType: String, CaseIterable, Codable, Sendable {
    /// Next beat is computed from the day you complete it. For things that
    /// drift: mowing, haircuts, watering.
    case relative
    /// Next beat is computed from the previous due date, regardless of when
    /// you actually did it. For hard schedules: bills, trash day.
    case fixed

    var displayName: String {
        switch self {
        case .relative: "Relative"
        case .fixed: "Fixed"
        }
    }
}

enum HistoryAction: String, Codable, Sendable {
    case completed
    case skipped
}

/// Resolved notification preferences for a cadence or beat. Times are
/// minutes-since-midnight (day-granularity due dates; the time only controls
/// when the reminder is delivered).
struct NotifyPreferences: Equatable, Codable, Sendable {
    var almost: Bool
    var due: Bool
    var overdue: Bool
    var minutes: Int

    static let standard = NotifyPreferences(almost: false, due: true, overdue: true, minutes: 9 * 60)

    /// Summary copy for detail rows: "Due, Overdue" or "Off".
    var summary: String {
        let parts = [almost ? "Upcoming" : nil, due ? "Due" : nil, overdue ? "Overdue" : nil]
            .compactMap(\.self)
        return parts.isEmpty ? "Off" : parts.joined(separator: ", ")
    }

    /// "9:00 AM" formatting for minutes-since-midnight.
    var timeLabel: String {
        let h24 = minutes / 60
        let m = minutes % 60
        let period = h24 < 12 ? "AM" : "PM"
        var h = h24 % 12
        if h == 0 { h = 12 }
        return String(format: "%d:%02d %@", h, m, period)
    }
}
