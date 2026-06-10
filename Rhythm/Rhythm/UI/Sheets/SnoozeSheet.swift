//
//  SnoozeSheet.swift
//  Rhythm
//
//  Snooze picker: preset lengths (default = grace period) plus a custom
//  date. Snoozing pushes the beat off the radar until the chosen day.
//

import SwiftUI

struct SnoozeSheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(\.dismiss) private var dismiss

    let beat: Beat

    @State private var customDate = Date.now
    @State private var showCalendar = false

    private struct Option: Identifiable {
        let id: Int
        let label: String
        let days: Int
        var isDefault = false
    }

    private var options: [Option] {
        let grace = Grace.snoozeDays(forGrace: beat.grace)
        let all = [
            Option(id: 0, label: "Tomorrow", days: 1),
            Option(
                id: 1, label: "\(grace) \(grace == 1 ? "day" : "days") — matches grace",
                days: grace, isDefault: true),
            Option(id: 2, label: "In 3 days", days: 3),
            Option(id: 3, label: "Next week", days: 7),
        ]
        // Drop presets that collide with the grace default (e.g. grace = 1).
        var seen = Set<Int>()
        return all.filter { seen.insert($0.days).inserted }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(options) { option in
                        Button {
                            snooze(until: DayMath.addDays(option.days, to: ticker.today))
                        } label: {
                            HStack {
                                Label {
                                    Text(option.label)
                                        .fontWeight(option.isDefault ? .semibold : .regular)
                                        .foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: "zzz")
                                        .foregroundStyle(Theme.accent)
                                }
                                Spacer()
                                Text(dayLabel(option.days))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(
                        "Push “\(beat.name)” off your radar until later. Default matches its grace period."
                    )
                }

                Section {
                    Toggle("Pick a date", isOn: $showCalendar.animation())
                    if showCalendar {
                        DatePicker(
                            "Custom date", selection: $customDate,
                            in: DayMath.addDays(1, to: ticker.today)...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        Button {
                            snooze(until: customDate)
                        } label: {
                            Text("Snooze until \(formatted(customDate))")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Theme.accent)
                        .foregroundStyle(.white)
                    }
                }
            }
            .navigationTitle("Snooze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                customDate = DayMath.addDays(
                    max(1, DayMath.days(from: ticker.today, to: beat.due) + 1), to: ticker.today)
            }
        }
        .presentationDetents([.large])
    }

    private func snooze(until date: Date) {
        store.snooze(beat, until: date)
        toasts.show(
            "Snoozed until \(formatted(date))", systemImage: "zzz", color: Theme.orange)
        dismiss()
    }

    private func dayLabel(_ days: Int) -> String {
        formatted(DayMath.addDays(days, to: ticker.today))
    }

    private func formatted(_ date: Date) -> String {
        let off = DayMath.days(from: ticker.today, to: date)
        if off == 1 { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
