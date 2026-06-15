//
//  CreateCadenceSheet.swift
//  Rhythm
//
//  Create / edit a cadence — the locked single scrolling form: identity,
//  scheduling cards, frequency (presets + stepper + unit) with live grace
//  suggestion, grace, first due, notifications. Edit mode pre-populates
//  everything.
//

import SwiftUI

struct CreateCadenceSheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var editing: Cadence?

    @State private var name = ""
    @State private var colorHex = "#5E5CE6"
    @State private var glyph = "🔁"
    @State private var note = ""
    @State private var scheduleType = ScheduleType.relative
    @State private var everyN = 1
    @State private var everyUnit = FrequencyUnit.weeks
    @State private var grace = 1
    @State private var graceTouched = false
    @State private var firstDue = Date.now
    @State private var notify = NotifyPreferences.standard
    @State private var loaded = false

    private var frequency: Frequency { Frequency(n: everyN, unit: everyUnit) }
    private var suggestedGrace: Int {
        Grace.days(forFrequencyDays: frequency.approximateDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GlyphColorPicker(glyph: $glyph, colorHex: $colorHex)
                        .listRowInsets(EdgeInsets())
                    TextField("Cadence name", text: $name)
                }

                Section("Scheduling") {
                    ScheduleTypeCards(selection: $scheduleType)
                }

                Section {
                    FrequencyPickerView(n: $everyN, unit: $everyUnit)
                } header: {
                    Text("Frequency")
                } footer: {
                    Text("Suggested grace period: \(suggestedGrace) \(suggestedGrace == 1 ? "day" : "days")")
                }

                Section {
                    StepperRow(label: "Grace period", value: graceBinding)
                } footer: {
                    Text("How early a beat lands on your radar — and its snooze length.")
                }

                Section(editing == nil ? "First beat due" : "Next beat due") {
                    DatePicker("Due", selection: $firstDue, displayedComponents: .date)
                }

                Section("Notifications") {
                    NotifyRows(notify: $notify)
                }

                Section("Notes") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(editing == nil ? "New cadence" : "Edit cadence")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDismissal()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save") { submit() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { load() }
            .onChange(of: everyN) { syncSuggestedGrace() }
            .onChange(of: everyUnit) { syncSuggestedGrace() }
        }
    }

    // MARK: Grace plumbing

    private var graceBinding: Binding<Int> {
        Binding {
            grace
        } set: {
            grace = $0
            graceTouched = true
        }
    }

    private func syncSuggestedGrace() {
        guard !graceTouched else { return }
        grace = suggestedGrace
    }

    // MARK: Load / submit

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let cadence = editing {
            name = cadence.name
            colorHex = cadence.colorHex
            glyph = cadence.glyph
            note = cadence.note
            scheduleType = cadence.scheduleType
            everyN = cadence.frequency.n
            everyUnit = cadence.frequency.unit
            grace = cadence.grace
            graceTouched = true  // editing never silently overwrites grace
            firstDue = cadence.activeBeat?.due ?? ticker.today
            notify = cadence.notify
        } else {
            scheduleType = settings.defaultScheduleType
            notify = settings.defaultNotify
            grace = suggestedGrace
            firstDue = DayMath.addDays(
                min(frequency.approximateDays, 14), to: ticker.today)
        }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let cadence = editing {
            store.updateCadence(
                cadence, name: trimmed, colorHex: colorHex, glyph: glyph, note: note,
                scheduleType: scheduleType, frequency: frequency, grace: grace,
                due: firstDue, notify: notify)
            toasts.show(
                "Cadence updated", systemImage: "arrow.triangle.2.circlepath",
                color: Theme.accent)
        } else {
            store.createCadence(
                name: trimmed, colorHex: colorHex, glyph: glyph, note: note,
                scheduleType: scheduleType, frequency: frequency, grace: grace,
                firstDue: firstDue, notify: notify)
            toasts.show(
                "Cadence created", systemImage: "arrow.triangle.2.circlepath",
                color: Theme.accent)
        }
        dismiss()
    }
}
