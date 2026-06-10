//
//  Discovery.swift
//  Rhythm
//
//  An unknown-frequency tracker: log occurrences until there are enough
//  (two) to suggest a frequency, then convert into a real cadence.
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
    var logs: [Date] = []

    init(name: String, colorHex: String, glyph: String, note: String = "", logs: [Date] = []) {
        self.name = name
        self.colorHex = colorHex
        self.glyph = glyph
        self.note = note
        self.logs = logs
    }

    var sortedLogs: [Date] { logs.sorted() }

    var isReadyToConvert: Bool { logs.count >= 2 }

    /// Average interval in days between logged occurrences — the suggested
    /// frequency once two or more are logged.
    var suggestedFrequencyDays: Int? {
        let sorted = sortedLogs
        guard sorted.count >= 2 else { return nil }
        let total = DayMath.days(from: sorted[0], to: sorted[sorted.count - 1])
        return Int((Double(total) / Double(sorted.count - 1)).rounded())
    }
}
