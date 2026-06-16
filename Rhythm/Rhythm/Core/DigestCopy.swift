//
//  DigestCopy.swift
//  Rhythm
//
//  Copy for the daily digest notification: one line summarizing what's due
//  today and what's overdue. A single beat in a category is named; two or
//  more collapse to a count. Returns nil when nothing is due or overdue, so
//  the planner skips the digest entirely on quiet days.
//

import Foundation

enum DigestCopy {
    /// Title shown above the digest body.
    static let title = "Today's Rhythm"

    /// One overdue beat as the digest sees it on a given day: its name and
    /// how many days past due it is.
    struct OverdueBeat: Equatable, Sendable {
        let name: String
        let daysOverdue: Int
    }

    /// The digest body for a day, or nil when nothing is due or overdue.
    static func body(dueToday: [String], overdue: [OverdueBeat]) -> String? {
        let due = dueClause(dueToday)
        let over = overdueClause(overdue, dueCount: dueToday.count)

        let sentence: String? =
            switch (due, over) {
            case let (due?, over?): "\(due) and \(over)"
            case let (due?, nil): due
            case let (nil, over?): over
            case (nil, nil): nil
            }
        return sentence.map { "\($0)." }
    }

    private static func dueClause(_ names: [String]) -> String? {
        switch names.count {
        case 0: nil
        case 1: "\(names[0]) is due today"
        default: "\(names.count) beats due today"
        }
    }

    private static func overdueClause(_ overdue: [OverdueBeat], dueCount: Int) -> String? {
        switch overdue.count {
        case 0:
            return nil
        case 1:
            let beat = overdue[0]
            let unit = beat.daysOverdue == 1 ? "day" : "days"
            return "\(beat.name) is \(beat.daysOverdue) \(unit) overdue"
        default:
            // The phrasing leans on the due clause that precedes it: none →
            // standalone, one named due → reintroduce "beats", many → "more".
            switch dueCount {
            case 0: return "\(overdue.count) beats overdue"
            case 1: return "\(overdue.count) beats are overdue"
            default: return "\(overdue.count) more are overdue"
            }
        }
    }
}
