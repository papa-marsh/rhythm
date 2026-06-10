//
//  DiscoverySheets.swift
//  Rhythm
//
//  Start a discovery (unknown frequency) and convert a ready discovery
//  into a real cadence pre-filled with the suggested frequency.
//

import SwiftUI

// MARK: - Start a discovery

struct CreateDiscoverySheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = "#64D2FF"
    @State private var glyph = "🎯"
    @State private var logToday = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GlyphColorPicker(glyph: $glyph, colorHex: $colorHex)
                        .listRowInsets(EdgeInsets())
                    TextField("e.g. Change fridge water filter", text: $name)
                } footer: {
                    Text("For things you do on no known schedule. Log it twice and Rhythm suggests a frequency.")
                }

                Section {
                    Toggle("Log first occurrence", isOn: $logToday)
                } footer: {
                    Text("You can also start with zero and log the first occurrence next time you do it.")
                }
            }
            .navigationTitle("Start a discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        store.createDiscovery(
                            name: name.trimmingCharacters(in: .whitespaces),
                            colorHex: colorHex, glyph: glyph,
                            logFirstOccurrenceToday: logToday)
                        toasts.show(
                            "Discovery started", systemImage: "target", color: Theme.accent)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Convert to cadence

struct ConvertDiscoverySheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let discovery: Discovery

    @State private var name = ""
    @State private var scheduleType = ScheduleType.relative
    @State private var everyN = 1
    @State private var everyUnit = FrequencyUnit.months
    @State private var loaded = false

    private var frequency: Frequency { Frequency(n: everyN, unit: everyUnit) }
    private var suggested: Int { discovery.suggestedFrequencyDays ?? 30 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.green)
                        banner
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Theme.green.opacity(0.08))
                }

                Section {
                    HStack(spacing: 13) {
                        GlyphTile(
                            glyph: discovery.glyph, colorHex: discovery.colorHex, size: 40)
                        TextField("Cadence name", text: $name)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }

                Section("Scheduling") {
                    ScheduleTypeCards(selection: $scheduleType)
                }

                Section("Suggested frequency") {
                    FrequencyPickerView(n: $everyN, unit: $everyUnit)
                }
            }
            .navigationTitle("Convert to cadence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { convert() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
    }

    private var banner: Text {
        Text("Based on \(discovery.logCount) logged occurrences, Rhythm suggests ")
            + Text("every \(suggested) days").fontWeight(.semibold)
            + Text(". Adjust if you like.")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = discovery.name
        scheduleType = settings.defaultScheduleType
        let f = Frequency(approximateDays: suggested)
        everyN = f.n
        everyUnit = f.unit
    }

    private func convert() {
        let days = frequency.approximateDays
        store.convertDiscovery(
            discovery,
            scheduleType: scheduleType,
            frequency: frequency,
            grace: Grace.days(forFrequencyDays: days),
            firstDue: DayMath.addDays(days, to: ticker.today),
            notify: settings.defaultNotify)
        toasts.show("Converted to cadence", systemImage: "sparkles", color: Theme.green)
        dismiss()
    }
}
