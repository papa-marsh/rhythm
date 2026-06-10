//
//  SeedData.swift
//  Rhythm
//
//  DEBUG/preview sample data mirroring the design prototype's seeds
//  (design_files/app/data.jsx), with due dates relative to the live today.
//  Production starts empty.
//

#if DEBUG
    import Foundation
    import SwiftData

    enum SeedData {
        /// Populate a context with the prototype's sample data. Intended for
        /// previews and simulator exploration only.
        @MainActor
        static func populate(_ context: ModelContext, calendar: Calendar = .current) {
            let today = DayMath.startOfDay(.now, calendar: calendar)
            let day = { (offset: Int) in DayMath.addDays(offset, to: today, calendar: calendar) }

            func cadence(
                name: String, colorHex: String, glyph: String, note: String = "",
                schedule: ScheduleType, frequency: Frequency, dueOffset: Int,
                notify: NotifyPreferences = .standard, historyCount: Int
            ) {
                let freqDays = frequency.approximateDays
                let due = day(dueOffset)
                let c = Cadence(
                    name: name, colorHex: colorHex, glyph: glyph, note: note,
                    scheduleType: schedule, frequency: frequency,
                    grace: Grace.days(forFrequencyDays: freqDays),
                    anchorDay: calendar.component(.day, from: due), notify: notify)
                context.insert(c)

                // History spaced ~freq apart going back from a recent completion.
                var offset = -Int(Double(freqDays) * 0.4)
                for i in 0..<historyCount {
                    let jitter = freqDays >= 7 ? (i % 3 - 1) * max(1, freqDays / 15) : 0
                    let entry = HistoryEntry(date: day(offset), action: .completed)
                    context.insert(entry)
                    entry.cadence = c
                    offset -= freqDays + jitter
                }

                let beat = Beat(generatedFor: c, due: due)
                context.insert(beat)
                beat.cadence = c
            }

            cadence(
                name: "Mow the lawn", colorHex: "#34C759", glyph: "🌿",
                note: "Front and back. Bag the clippings if it’s gotten tall.",
                schedule: .relative, frequency: Frequency(n: 1, unit: .weeks), dueOffset: 0,
                historyCount: 8)
            cadence(
                name: "Take out the trash", colorHex: "#8E8E93", glyph: "🗑️",
                note: "To the curb Tuesday night. Recycling on alternate weeks.",
                schedule: .fixed, frequency: Frequency(n: 1, unit: .weeks), dueOffset: -1,
                notify: NotifyPreferences(almost: true, due: true, overdue: true, minutes: 18 * 60 + 30),
                historyCount: 10)
            cadence(
                name: "Replace HVAC filter", colorHex: "#FF9500", glyph: "🌬️",
                note: "20×25×1, MERV 11. Box is in the garage.",
                schedule: .fixed, frequency: Frequency(n: 3, unit: .months), dueOffset: -11,
                historyCount: 4)
            cadence(
                name: "Pay electric bill", colorHex: "#FFCC00", glyph: "⚡️",
                schedule: .fixed, frequency: Frequency(n: 1, unit: .months), dueOffset: 3,
                notify: NotifyPreferences(almost: true, due: true, overdue: true, minutes: 9 * 60),
                historyCount: 6)
            cadence(
                name: "Haircut", colorHex: "#5E5CE6", glyph: "✂️",
                note: "Ask for the usual — #3 on the sides.",
                schedule: .relative, frequency: Frequency(n: 5, unit: .weeks), dueOffset: 1,
                historyCount: 5)
            cadence(
                name: "Fertilize the lawn", colorHex: "#30D158", glyph: "🌱",
                note: "Spring application. Don’t mow for 2 days after.",
                schedule: .relative, frequency: Frequency(n: 4, unit: .months), dueOffset: 9,
                historyCount: 3)
            cadence(
                name: "Water the ferns", colorHex: "#32ADE6", glyph: "🪴",
                schedule: .relative, frequency: Frequency(n: 3, unit: .days), dueOffset: 0,
                historyCount: 12)
            cadence(
                name: "Clean the gutters", colorHex: "#A2845E", glyph: "🏠",
                schedule: .relative, frequency: Frequency(n: 6, unit: .months), dueOffset: 41,
                historyCount: 2)
            cadence(
                name: "Replace toothbrush head", colorHex: "#64D2FF", glyph: "🪥",
                schedule: .fixed, frequency: Frequency(n: 3, unit: .months), dueOffset: 26,
                historyCount: 3)

            // Standalone beats
            let library = Beat(
                name: "Return library books", colorHex: "#AF52DE", glyph: "📚",
                note: "3 books — the tote by the door.", due: day(-2), grace: 2)
            context.insert(library)
            let dentist = Beat(
                name: "Call dentist to schedule", colorHex: "#FF2D55", glyph: "🦷",
                due: day(2), grace: 3)
            context.insert(dentist)
            let passport = Beat(
                name: "Renew passport", colorHex: "#0A84FF", glyph: "🛂",
                due: day(88), grace: Grace.days(forFrequencyDays: 88))
            context.insert(passport)

            // Discoveries
            func discovery(name: String, colorHex: String, glyph: String, note: String = "", logOffsets: [Int]) {
                let d = Discovery(name: name, colorHex: colorHex, glyph: glyph, note: note)
                context.insert(d)
                for offset in logOffsets {
                    let log = DiscoveryLog(date: day(offset))
                    context.insert(log)
                    log.discovery = d
                }
            }
            discovery(
                name: "Change fridge water filter", colorHex: "#64D2FF", glyph: "💧",
                note: "No idea how often. Tracking to find out.", logOffsets: [-190])
            discovery(
                name: "Descale the espresso machine", colorHex: "#A2845E", glyph: "☕️",
                logOffsets: [-120, -48])

            try? context.save()
        }
    }
#endif
