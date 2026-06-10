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
                    scheduleCard(
                        .relative, icon: "checkmark",
                        description:
                            "Counts from when you finish. Best for mowing, haircuts — things that drift.")
                    scheduleCard(
                        .fixed, icon: "calendar",
                        description:
                            "Hard schedule regardless of completion. Best for bills, trash day.")
                }

                Section {
                    frequencyPicker
                } header: {
                    Text("Frequency")
                } footer: {
                    Text("Suggested grace period: \(suggestedGrace) \(suggestedGrace == 1 ? "day" : "days")")
                }

                Section {
                    StepperRow(label: "Grace period", value: graceBinding)
                } header: {
                    Text("Grace period")
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

    // MARK: Scheduling cards

    private func scheduleCard(
        _ type: ScheduleType, icon: String, description: String
    ) -> some View {
        Button {
            scheduleType = type
        } label: {
            HStack(alignment: .top, spacing: 13) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(scheduleType == type ? Theme.accent : Color(.tertiarySystemFill))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(scheduleType == type ? .white : .secondary)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(
                    systemName: scheduleType == type
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(scheduleType == type ? Theme.accent : Color(.systemGray3))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Frequency

    private var frequencyPicker: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                preset("Daily", days: 1)
                preset("Weekly", days: 7)
                preset("Monthly", days: 30)
                preset("Yearly", days: 365)
            }
            HStack(spacing: 12) {
                Text("Every")
                    .foregroundStyle(.secondary)
                Text("\(everyN)")
                    .font(.system(size: 26, weight: .bold))
                    .frame(minWidth: 34)
                    .contentTransition(.numericText())
                Stepper("Count", value: $everyN, in: 1...365)
                    .labelsHidden()
                Picker("Unit", selection: $everyUnit) {
                    Text("days").tag(FrequencyUnit.days)
                    Text("wks").tag(FrequencyUnit.weeks)
                    Text("mos").tag(FrequencyUnit.months)
                    Text("yrs").tag(FrequencyUnit.years)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, 4)
    }

    private func preset(_ label: String, days: Int) -> some View {
        let active = frequency.approximateDays == days
        return Button {
            let f = Frequency(approximateDays: days)
            withAnimation(.snappy) {
                everyN = f.n
                everyUnit = f.unit
            }
        } label: {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    active ? Theme.accent : Color(.tertiarySystemFill),
                    in: .rect(cornerRadius: 9, style: .continuous)
                )
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
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
