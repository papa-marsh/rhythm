//
//  Discovery.swift
//  Rhythm
//
//  An unknown-frequency tracker: log occurrences until there are enough
//  (two) to suggest a frequency, then convert into a real cadence.
//  Logs are child models (mirroring HistoryEntry) so they map to native
//  CloudKit records.
//

import Foundation
import SwiftData

@Model
final class Discovery {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var colorHex: String = "#64D2FF"
    var glyph: String = "🎯"
    var note: String = ""

    @Relationship(deleteRule: .cascade, inverse: \DiscoveryLog.discovery)
    var logs: [DiscoveryLog]? = []

    init(name: String, colorHex: String, glyph: String, note: String = "") {
        self.name = name
        self.colorHex = colorHex
        self.glyph = glyph
        self.note = note
    }

    var sortedLogDates: [Date] { (logs ?? []).map(\.date).sorted() }

    var logCount: Int { logs?.count ?? 0 }

    var isReadyToConvert: Bool { logCount >= 2 }

    /// Average interval in days between logged occurrences — the suggested
    /// frequency once two or more are logged.
    var suggestedFrequencyDays: Int? {
        let sorted = sortedLogDates
        guard sorted.count >= 2 else { return nil }
        let total = DayMath.days(from: sorted[0], to: sorted[sorted.count - 1])
        return Int((Double(total) / Double(sorted.count - 1)).rounded())
    }
}

@Model
final class DiscoveryLog {
    var id: UUID = UUID()
    var date: Date = Date.now
    var discovery: Discovery? = nil

    init(date: Date) {
        self.date = date
    }
}
