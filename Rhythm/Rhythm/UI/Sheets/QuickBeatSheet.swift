//
//  QuickBeatSheet.swift
//  Rhythm
//
//  Create a standalone beat: identity, due date, and a manually-set grace
//  (defaulting from the distance to the due date, since there's no
//  frequency to inherit from).
//

import SwiftUI

struct QuickBeatSheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = "#0A84FF"
    @State private var glyph = "🚩"
    @State private var due = Date.now
    @State private var grace = Grace.days(forFrequencyDays: 1)
    @State private var graceTouched = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GlyphColorPicker(glyph: $glyph, colorHex: $colorHex)
                        .listRowInsets(EdgeInsets())
                    TextField("What needs doing?", text: $name)
                }

                Section {
                    DatePicker(
                        "Due date", selection: $due, in: ticker.today...,
                        displayedComponents: .date)
                    StepperRow(label: "Grace period", value: graceBinding)
                } header: {
                    Text("Due")
                } footer: {
                    Text("A standalone beat isn’t tied to a cadence, so set its grace period yourself.")
                }
            }
            .navigationTitle("Quick beat")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDismissal()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                due = DayMath.addDays(1, to: ticker.today)
            }
            .onChange(of: due) { _, newDue in
                guard !graceTouched else { return }
                let distance = max(1, DayMath.days(from: ticker.today, to: newDue))
                grace = Grace.days(forFrequencyDays: distance)
            }
        }
    }

    /// Manual stepper edits stop the auto-derivation from due-date distance.
    private var graceBinding: Binding<Int> {
        Binding {
            grace
        } set: { newValue in
            grace = newValue
            graceTouched = true
        }
    }

    private func add() {
        store.createStandaloneBeat(
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex, glyph: glyph, due: due, grace: grace)
        toasts.show("Beat added", systemImage: "flag", color: Theme.accent)
        dismiss()
    }
}
