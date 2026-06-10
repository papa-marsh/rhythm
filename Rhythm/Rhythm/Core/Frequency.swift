//
//  Frequency.swift
//  Rhythm
//
//  Unit-based frequency representation. Per spec, frequency is stored as
//  {n, unit} and displayed as set ("every 4 months", "Weekly") — never
//  normalized to days. The derived day-count exists only for grace math
//  and stats.
//

import Foundation

enum FrequencyUnit: String, CaseIterable, Codable, Sendable {
    case days
    case weeks
    case months
    case years

    /// Approximate days per unit, used only for grace derivation and stats.
    var approximateDays: Int {
        switch self {
        case .days: 1
        case .weeks: 7
        case .months: 30
        case .years: 365
        }
    }

    var singular: String {
        switch self {
        case .days: "day"
        case .weeks: "week"
        case .months: "month"
        case .years: "year"
        }
    }

    /// Label when n == 1: Daily / Weekly / Monthly / Yearly.
    var adverb: String {
        switch self {
        case .days: "Daily"
        case .weeks: "Weekly"
        case .months: "Monthly"
        case .years: "Yearly"
        }
    }
}

struct Frequency: Equatable, Codable, Sendable {
    var n: Int
    var unit: FrequencyUnit

    init(n: Int, unit: FrequencyUnit) {
        self.n = n
        self.unit = unit
    }

    /// Best unit-based representation of a day count (used when converting a
    /// discovery's suggested interval into a frequency).
    init(approximateDays days: Int) {
        if days >= 365, days % 365 == 0 {
            self.init(n: days / 365, unit: .years)
        } else if days >= 30, days % 30 == 0 {
            self.init(n: days / 30, unit: .months)
        } else if days >= 7, days % 7 == 0 {
            self.init(n: days / 7, unit: .weeks)
        } else {
            self.init(n: days, unit: .days)
        }
    }

    /// Derived day count for grace math and stats only.
    var approximateDays: Int { n * unit.approximateDays }

    /// Short label for list chips: "Weekly", "3 weeks".
    var shortLabel: String {
        n == 1 ? unit.adverb : "\(n) \(unit.rawValue)"
    }

    /// Long label for detail views: "every week", "every 3 weeks", "every day".
    var longLabel: String {
        n == 1 ? "every \(unit.singular)" : "every \(n) \(unit.rawValue)"
    }
}

enum Grace {
    /// Derive a grace period (days) from a frequency (days). Sub-linear:
    /// weekly → 1, monthly → 5, quarterly → 8, yearly → 16.
    static func days(forFrequencyDays freq: Int) -> Int {
        if freq <= 2 { return 0 }
        if freq <= 8 { return 1 }
        return max(2, Int((0.85 * Double(freq).squareRoot()).rounded()))
    }

    /// Snooze length equals the grace period, but never less than a day.
    static func snoozeDays(forGrace grace: Int) -> Int {
        max(1, grace)
    }
}
