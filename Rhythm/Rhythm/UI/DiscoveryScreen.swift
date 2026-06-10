//
//  DiscoveryScreen.swift
//  Rhythm
//
//  Track unknown-frequency tasks: log occurrences until Rhythm can suggest
//  a frequency (average interval after 2 logs), then convert to a cadence.
//

import SwiftData
import SwiftUI

struct DiscoveryScreen: View {
    @Environment(RhythmStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @Environment(DayTicker.self) private var ticker

    @Query(sort: \Discovery.createdAt) private var discoveries: [Discovery]
    @State private var createPresented = false
    @State private var convertTarget: Discovery?

    var body: some View {
        NavigationStack {
            List {
                explainer

                ForEach(discoveries, id: \.id) { discovery in
                    DiscoveryCard(
                        discovery: discovery,
                        onLog: { log(discovery) },
                        onConvert: { convertTarget = discovery },
                        onDelete: { delete(discovery) }
                    )
                }

                if discoveries.isEmpty {
                    ContentUnavailableView(
                        "No discoveries yet", systemImage: "safari",
                        description: Text("Start one with the + button.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Discovery")
            .navigationSubtitle("Find your rhythm")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        createPresented = true
                    }
                }
            }
            .sheet(isPresented: $createPresented) {
                CreateDiscoverySheet()
            }
            .sheet(item: $convertTarget) { discovery in
                ConvertDiscoverySheet(discovery: discovery)
            }
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            Text(
                "Don’t know how often something happens? Log it twice and Rhythm suggests a frequency — then converts it to a real cadence."
            )
            .font(.system(size: 13.5))
            .opacity(0.9)
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.accent.opacity(0.1))
    }

    private func log(_ discovery: Discovery) {
        store.logOccurrence(discovery)
        toasts.show("Occurrence logged", systemImage: "target", color: Theme.accent)
    }

    private func delete(_ discovery: Discovery) {
        store.deleteDiscovery(discovery)
        toasts.show("Discovery deleted", systemImage: "trash", color: Theme.red)
    }
}

// MARK: - Card

private struct DiscoveryCard: View {
    @Environment(DayTicker.self) private var ticker

    let discovery: Discovery
    let onLog: () -> Void
    let onConvert: () -> Void
    let onDelete: () -> Void

    private var ready: Bool { discovery.isReadyToConvert }

    var body: some View {
        Section {
            // Header: identity + progress dots
            HStack(spacing: 12) {
                GlyphTile(glyph: discovery.glyph, colorHex: discovery.colorHex, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(discovery.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(discovery.logCount) of 2 logged")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                progressDots
            }

            // Logged timeline
            if discovery.logCount == 0 {
                Text("No occurrences logged yet. Log the next time you do it.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(timeline, id: \.date) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(ready ? Theme.green : Theme.accent)
                            .frame(width: 8, height: 8)
                        Text(item.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 14.5))
                        Spacer()
                        if let interval = item.interval {
                            Text("+\(interval) days")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Footer action
            if ready, let suggested = discovery.suggestedFrequencyDays {
                VStack(alignment: .leading, spacing: 10) {
                    suggestionText(suggested)
                    Button(action: onConvert) {
                        Label("Convert to cadence", systemImage: "arrow.right")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 13))
                    .controlSize(.large)
                }
                .listRowBackground(Theme.green.opacity(0.08))
            } else {
                Button(action: onLog) {
                    Label("Log occurrence", systemImage: "plus")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 13))
                .controlSize(.large)
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete discovery", systemImage: "trash")
            }
        }
    }

    private func suggestionText(_ suggested: Int) -> Text {
        Text("Suggested frequency: ")
            .foregroundStyle(.secondary)
            + Text("about every \(suggested) days")
            .fontWeight(.semibold)
            + Text(". Convert to lock it in.")
            .foregroundStyle(.secondary)
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(
                        index < discovery.logCount
                            ? (ready ? Theme.green : Theme.accent) : Color(.tertiarySystemFill)
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var timeline: [(date: Date, interval: Int?)] {
        let sorted = discovery.sortedLogDates
        return sorted.enumerated().map { index, date in
            (date, index > 0 ? DayMath.days(from: sorted[index - 1], to: date) : nil)
        }
    }
}
