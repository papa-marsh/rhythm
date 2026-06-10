//
//  EditDiscoverySheet.swift
//  Rhythm
//
//  Edit a discovery: identity, description, the logged occurrences
//  (re-date or remove each), and deletion of the discovery itself.
//

import SwiftUI

struct EditDiscoverySheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(\.dismiss) private var dismiss

    let discovery: Discovery

    @State private var name = ""
    @State private var colorHex = ""
    @State private var glyph = ""
    @State private var note = ""
    @State private var loaded = false
    @State private var deleteConfirmPresented = false

    private var sortedLogs: [DiscoveryLog] {
        (discovery.logs ?? []).sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GlyphColorPicker(glyph: $glyph, colorHex: $colorHex)
                        .listRowInsets(EdgeInsets())
                    TextField("Discovery name", text: $name)
                }

                Section("Description") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    if sortedLogs.isEmpty {
                        Text("No occurrences logged yet.")
                            .font(.system(size: 14.5))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sortedLogs, id: \.id) { log in
                        DatePicker(
                            "Logged", selection: logDateBinding(log), in: ...ticker.today,
                            displayedComponents: .date)
                    }
                    .onDelete(perform: deleteLogs)
                } header: {
                    Text("Logged occurrences")
                } footer: {
                    Text("Swipe a row to remove it. Dates feed the suggested frequency.")
                }

                Section {
                    Button(role: .destructive) {
                        deleteConfirmPresented = true
                    } label: {
                        Label("Delete discovery", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.updateDiscovery(
                            discovery,
                            name: name.trimmingCharacters(in: .whitespaces),
                            colorHex: colorHex, glyph: glyph, note: note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete “\(discovery.name)”?", isPresented: $deleteConfirmPresented,
                titleVisibility: .visible
            ) {
                Button("Delete discovery", role: .destructive) {
                    dismiss()
                    store.deleteDiscovery(discovery)
                    toasts.show("Discovery deleted", systemImage: "trash", color: Theme.red)
                }
            } message: {
                Text("Its logged occurrences will also be deleted.")
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = discovery.name
        colorHex = discovery.colorHex
        glyph = discovery.glyph
        note = discovery.note
    }

    private func logDateBinding(_ log: DiscoveryLog) -> Binding<Date> {
        Binding {
            log.date
        } set: {
            store.setLogDate(log, to: $0)
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        let logs = sortedLogs
        for index in offsets {
            store.deleteLog(logs[index])
        }
    }
}
