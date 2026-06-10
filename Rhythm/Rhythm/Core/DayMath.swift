//
//  DayMath.swift
//  Rhythm
//
//  Calendar-aware day-granularity date math. Beats are due on a *day*,
//  never a time, so all comparisons happen between start-of-day dates.
//
//  Month/year addition is anchor-day-preserving: adding months keeps the
//  original anchor day-of-month, clamped to the target month's length.
//  A monthly cadence anchored on the 31st lands on Jun 30 but snaps back
//  to Jul 31 — which is why the anchor day is stored and re-applied each
//  cycle instead of being derived from the previously-clamped date.
//

import Foundation

enum DayMath {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addDays(_ n: Int, to date: Date, calendar: Calendar = .current) -> Date {
        let day = startOfDay(date, calendar: calendar)
        guard let result = calendar.date(byAdding: .day, value: n, to: day) else {
            preconditionFailure("Calendar failed to add \(n) days to \(day)")
        }
        return startOfDay(result, calendar: calendar)
    }

    /// Whole days from `from` to `to` (positive = future). DST-safe.
    static func days(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let a = startOfDay(from, calendar: calendar)
        let b = startOfDay(to, calendar: calendar)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Add months preserving the original anchor day-of-month, clamped to the
    /// target month's length. `anchorDay` of nil/0 falls back to the source
    /// date's day-of-month.
    static func addMonthsAnchored(
        _ months: Int,
        to date: Date,
        anchorDay: Int?,
        calendar: Calendar = .current
    ) -> Date {
        let day = startOfDay(date, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = comps.year, let month = comps.month, let dom = comps.day else {
            preconditionFailure("Calendar failed to decompose \(day)")
        }

        // Zero-based month index arithmetic, floor-safe for negative results.
        let index = year * 12 + (month - 1) + months
        let targetYear = index >= 0 ? index / 12 : (index - 11) / 12
        let targetMonth = ((index % 12) + 12) % 12 + 1

        guard
            let firstOfTarget = calendar.date(
                from: DateComponents(year: targetYear, month: targetMonth, day: 1)),
            let daysInTarget = calendar.range(of: .day, in: .month, for: firstOfTarget)?.count
        else {
            preconditionFailure("Calendar failed to resolve month \(targetYear)-\(targetMonth)")
        }

        let anchor = (anchorDay ?? 0) > 0 ? anchorDay! : dom
        let targetDay = min(anchor, daysInTarget)
        guard
            let result = calendar.date(
                from: DateComponents(year: targetYear, month: targetMonth, day: targetDay))
        else {
            preconditionFailure(
                "Calendar failed to build date \(targetYear)-\(targetMonth)-\(targetDay)")
        }
        return startOfDay(result, calendar: calendar)
    }

    /// Add one frequency interval to a date.
    /// - days/weeks → plain calendar-day addition.
    /// - months/years → anchor-day-preserving month addition.
    static func add(
        _ frequency: Frequency,
        to date: Date,
        anchorDay: Int? = nil,
        calendar: Calendar = .current
    ) -> Date {
        switch frequency.unit {
        case .days:
            return addDays(frequency.n, to: date, calendar: calendar)
        case .weeks:
            return addDays(frequency.n * 7, to: date, calendar: calendar)
        case .months:
            return addMonthsAnchored(
                frequency.n, to: date, anchorDay: anchorDay, calendar: calendar)
        case .years:
            return addMonthsAnchored(
                frequency.n * 12, to: date, anchorDay: anchorDay, calendar: calendar)
        }
    }

    /// Relative phrasing for a date: "today", "tomorrow", "yesterday",
    /// "in 3 days", "2 days ago".
    static func relativePhrase(for date: Date, from today: Date, calendar: Calendar = .current)
        -> String
    {
        let off = days(from: today, to: date, calendar: calendar)
        switch off {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case let n where n > 1: return "in \(n) days"
        case let n: return "\(-n) days ago"
        }
    }
}
