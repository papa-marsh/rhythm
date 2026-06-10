//
//  CadenceDetailScreen.swift
//  Rhythm
//
//  One cadence: hero, the next beat with actions, stats (target vs actual
//  interval, grace), schedule summary, full history, delete.
//

import SwiftUI

struct CadenceDetailScreen: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker
    @Environment(\.dismiss) private var dismiss

    let cadence: Cadence

    @State private var editPresented = false
    @State private var deleteConfirmPresented = false

    var body: some View {
        List {
            hero

            if let beat = cadence.activeBeat {
                nextBeatSection(beat)
            }

            statsSection

            Section("Schedule") {
                LabeledContent("Scheduling", value: cadence.scheduleType.displayName)
                LabeledContent("Frequency", value: frequencyLabel)
                LabeledContent("Notifications", value: cadence.notify.summary)
            }

            historySection

            Section {
                Button(role: .destructive) {
                    deleteConfirmPresented = true
                } label: {
                    Label("Delete cadence", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(cadence.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editPresented = true }
            }
        }
        .sheet(isPresented: $editPresented) {
            CreateCadenceSheet(editing: cadence)
        }
        .confirmationDialog(
            "Delete “\(cadence.name)”?", isPresented: $deleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete cadence", role: .destructive) {
                dismiss()
                store.deleteCadence(cadence)
                toasts.show("Cadence deleted", systemImage: "trash", color: Theme.red)
            }
        } message: {
            Text("This cadence’s beat history will also be deleted.")
        }
    }

    /// Instant snooze: default length = the beat's grace period.
    private func quickSnooze(_ beat: Beat) {
        let date = DayMath.addDays(Grace.snoozeDays(forGrace: beat.grace), to: ticker.today)
        store.snooze(beat, until: date)
        let label =
            DayMath.days(from: ticker.today, to: date) == 1
            ? "tomorrow" : date.formatted(.dateTime.month(.abbreviated).day())
        toasts.show("Snoozed until \(label)", systemImage: "zzz", color: Theme.orange)
    }

    // MARK: Sections

    private var hero: some View {
        Section {
            VStack(spacing: 10) {
                GlyphTile(glyph: cadence.glyph, colorHex: cadence.colorHex, size: 62)
                Text(cadence.name)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                if !cadence.note.isEmpty {
                    Text(cadence.note)
                        .font(.system(size: 14.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func nextBeatSection(_ beat: Beat) -> some View {
        Section("Next beat") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(beat.effectiveDue(today: ticker.today).formatted(
                        .dateTime.month(.abbreviated).day()))
                        .font(.system(size: 17, weight: .semibold))
                    Text(nextBeatSubtitle(beat))
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DueChip(urgency: beat.urgency(today: ticker.today))
            }
            HStack(spacing: 10) {
                Button {
                    store.complete(beat)
                    toasts.show(.completed(nextScheduled: true))
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                        Text("Complete")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    quickSnooze(beat)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "zzz")
                        Text("Snooze")
                    }
                    .fontWeight(.semibold)
                    .frame(height: 26)
                }
                .buttonStyle(.bordered)
            }
            .buttonBorderShape(.roundedRectangle(radius: 13))
            .controlSize(.large)
            .listRowSeparator(.hidden)
        }
    }

    private func nextBeatSubtitle(_ beat: Beat) -> String {
        let due = beat.effectiveDue(today: ticker.today)
        let weekday = due.formatted(.dateTime.weekday(.abbreviated))
        return "\(weekday) · \(DayMath.relativePhrase(for: due, from: ticker.today))"
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 10) {
                statCard(value: cadence.frequency.shortLabel, label: "Target interval")
                statCard(
                    value: "\(actualAverage)d", label: "Actual average", color: averageColor)
                statCard(value: "\(cadence.grace)d", label: "Grace period")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }

    private func statCard(value: String, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }

    private var actualAverage: Int {
        cadence.actualAverageDays ?? cadence.frequency.approximateDays
    }

    /// Amber when actual drifts from target by more than grace.
    private var averageColor: Color {
        abs(actualAverage - cadence.frequency.approximateDays) > cadence.grace
            ? Theme.orange : Theme.green
    }

    private var frequencyLabel: String {
        let label = cadence.frequency.longLabel
        return label.prefix(1).uppercased() + label.dropFirst()
    }

    private var historySection: some View {
        let history = cadence.sortedHistory
        return Section("History · \(history.count) beats") {
            if history.isEmpty {
                Text("No beats completed yet.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                historyRow(
                    entry,
                    interval: index < history.count - 1
                        ? DayMath.days(from: history[index + 1].date, to: entry.date) : nil)
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry, interval: Int?) -> some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(
                    entry.action == .skipped ? Color(.systemGray3) : Theme.green, lineWidth: 2
                )
                .background {
                    if entry.action == .completed {
                        Circle().fill(Theme.green)
                    }
                }
                .frame(width: 11, height: 11)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 16))
                Text(
                    "\(entry.date.formatted(.dateTime.weekday(.abbreviated))) · \(entry.action == .skipped ? "skipped" : "completed")"
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let interval {
                Text("\(interval)d")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
