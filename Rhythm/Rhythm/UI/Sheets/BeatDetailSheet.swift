//
//  BeatDetailSheet.swift
//  Rhythm
//
//  The full beat editor: status banner, identity, cadence link, schedule
//  (due + grace), notification overrides, notes, and actions. Edits apply
//  on Done and affect only this beat, never its cadence.
//

import SwiftUI

struct BeatDetailSheet: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss

    let beat: Beat
    var onSnooze: (Beat) -> Void = { _ in }

    @State private var draft = Draft()
    @State private var loaded = false
    @State private var showCompletedOn = false
    @State private var completedOnDate = Date.now

    struct Draft {
        var name = ""
        var note = ""
        var due = Date.now
        var grace = 1
        var snoozedUntil: Date?
        var notify = NotifyPreferences.standard
    }

    var body: some View {
        NavigationStack {
            Form {
                statusBanner

                Section {
                    HStack(spacing: 13) {
                        GlyphTile(glyph: beat.glyph, colorHex: beat.colorHex, size: 40)
                        TextField("Beat name", text: $draft.name)
                            .font(.system(size: 20, weight: .semibold))
                    }
                }

                if let cadence = beat.cadence {
                    Section {
                        Button {
                            save()
                            dismiss()
                            navigator.openCadence(cadence)
                        } label: {
                            HStack {
                                Label {
                                    Text("Cadence")
                                        .foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(Theme.accent)
                                }
                                Spacer()
                                Text(cadence.name)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if isSnoozedNow {
                    Section {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Snoozed")
                                    Text(snoozeSubtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "zzz")
                                    .foregroundStyle(Theme.orange)
                            }
                            Spacer()
                            Button("Resume") {
                                draft.snoozedUntil = nil
                            }
                            .font(.subheadline.weight(.medium))
                        }
                    }
                }

                Section {
                    DatePicker(
                        "Due date", selection: $draft.due, displayedComponents: .date)
                    StepperRow(label: "Grace period", value: $draft.grace)
                } header: {
                    Text("Schedule")
                } footer: {
                    Text(scheduleFooter)
                }

                Section {
                    NotifyRows(notify: $draft.notify)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Overrides the cadence default for this beat only.")
                }

                Section("Notes") {
                    TextField("Add a note…", text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                actionButtons
            }
            .navigationTitle("Beat")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDismissal()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { loadDraft() }
    }

    // MARK: Pieces

    private var statusBanner: some View {
        let urgency = Urgency.compute(
            due: draft.due, snoozedUntil: draft.snoozedUntil, grace: draft.grace,
            today: ticker.today)
        let color = urgency.isSnoozed ? Theme.orange : Theme.tierColor(urgency.tier)
        return Section {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(bannerTitle(urgency))
                    .font(.system(size: 14.5, weight: .semibold))
                Spacer()
                if let trailing = bannerTrailing(urgency) {
                    Text(trailing)
                        .font(.system(size: 14))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(color)
            .listRowBackground(color.opacity(0.12))
        }
    }

    private func bannerTitle(_ urgency: Urgency) -> String {
        if urgency.isSnoozed { return "Snoozed" }
        switch urgency.tier {
        case .later: return "Not due yet"
        case .almost: return "Upcoming"
        case .due: return "Due today"
        case .overdue, .late:
            let days = -urgency.daysUntilDue
            return "\(days) \(days == 1 ? "day" : "days") overdue"
        }
    }

    private func bannerTrailing(_ urgency: Urgency) -> String? {
        if urgency.isSnoozed, let until = draft.snoozedUntil {
            return "back \(DayMath.relativePhrase(for: until, from: ticker.today))"
        }
        switch urgency.tier {
        case .later, .almost:
            return DayMath.relativePhrase(for: draft.due, from: ticker.today)
        default:
            return nil
        }
    }

    private var isSnoozedNow: Bool {
        Urgency.isActivelySnoozed(snoozedUntil: draft.snoozedUntil, today: ticker.today)
    }

    private var snoozeSubtitle: String {
        guard let until = draft.snoozedUntil else { return "" }
        let back = DayMath.relativePhrase(for: until, from: ticker.today)
        let original = draft.due.formatted(.dateTime.month(.abbreviated).day())
        return "Back \(back) · originally due \(original)"
    }

    private var scheduleFooter: String {
        let graceCopy = "Used for the main beat view, notification timing, and snooze length."
        if let cadence = beat.cadence {
            return "This beat follows “\(cadence.name)”. Editing here affects only this beat. "
                + graceCopy
        }
        return graceCopy
    }

    private var actionButtons: some View {
        Section {
            Button {
                save(applyEdits: true)
                let linked = beat.cadence != nil
                store.complete(beat)
                toasts.show(.completed(nextScheduled: linked))
                dismiss()
            } label: {
                Label("Complete", systemImage: "checkmark")
                    .fontWeight(.semibold)
            }

            Button {
                withAnimation(.snappy) { showCompletedOn.toggle() }
            } label: {
                Label("Completed on…", systemImage: "calendar.badge.checkmark")
            }
            if showCompletedOn {
                DatePicker(
                    "Completion date", selection: $completedOnDate, in: completedOnRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                Button {
                    save(applyEdits: true)
                    let linked = beat.cadence != nil
                    store.complete(beat, on: completedOnDate)
                    toasts.show(.completed(nextScheduled: linked))
                    dismiss()
                } label: {
                    Text("Mark completed \(completedOnLabel)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }

            Button {
                save()
                let date = store.quickSnooze(beat)
                toasts.show(
                    "Snoozed until \(DayMath.relativePhrase(for: date, from: ticker.today))",
                    systemImage: "zzz", color: Theme.orange)
                dismiss()
            } label: {
                Label("Snooze", systemImage: "zzz")
            }

            Button {
                save()
                dismiss()
                onSnooze(beat)
            } label: {
                Label("Snooze until…", systemImage: "calendar.badge.clock")
            }

            Button {
                store.skip(beat)
                toasts.show("Skipped", systemImage: "forward.end", color: Theme.orange)
                dismiss()
            } label: {
                Label("Skip", systemImage: "forward.end")
            }

            if beat.cadence == nil {
                Button(role: .destructive) {
                    store.deleteStandalone(beat)
                    toasts.show("Beat deleted", systemImage: "trash", color: Theme.red)
                    dismiss()
                } label: {
                    Label("Delete beat", systemImage: "trash")
                }
            }
        }
    }

    /// Backdated completion is bounded by the most recent history entry
    /// (for linked beats) and today.
    private var completedOnRange: ClosedRange<Date> {
        let lower =
            beat.cadence?.sortedHistory.first?.date ?? Date.distantPast
        return lower...ticker.today
    }

    private var completedOnLabel: String {
        let off = DayMath.days(from: ticker.today, to: completedOnDate)
        if off == 0 { return "today" }
        if off == -1 { return "yesterday" }
        return completedOnDate.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Draft plumbing

    private func loadDraft() {
        guard !loaded else { return }
        loaded = true
        draft = Draft(
            name: beat.name,
            note: beat.note,
            due: beat.due,
            grace: beat.grace,
            snoozedUntil: beat.snoozedUntil,
            notify: beat.resolvedNotify
        )
    }

    private func save(applyEdits: Bool = true) {
        guard applyEdits else { return }
        beat.name = draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            ? beat.name : draft.name
        beat.note = draft.note
        beat.due = DayMath.startOfDay(draft.due)
        beat.grace = draft.grace
        beat.snoozedUntil = draft.snoozedUntil

        // Persist notification fields as overrides only where they differ
        // from what the beat would inherit anyway.
        let base = beat.cadence?.notify ?? .standard
        beat.notifyAlmostOverride = draft.notify.almost == base.almost ? nil : draft.notify.almost
        beat.notifyDueOverride = draft.notify.due == base.due ? nil : draft.notify.due
        beat.notifyOverdueOverride =
            draft.notify.overdue == base.overdue ? nil : draft.notify.overdue
        beat.notifyMinutesOverride =
            draft.notify.minutes == base.minutes ? nil : draft.notify.minutes

        store.saveEdits(beat)
    }
}
