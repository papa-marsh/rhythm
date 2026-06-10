//
//  CadencesScreen.swift
//  Rhythm
//
//  The library of recurring definitions. Single inset list, sortable by
//  name / frequency / recently added, frequency chip with a schedule icon
//  (repeat = Relative, anchor = Fixed).
//

import SwiftData
import SwiftUI

enum CadenceSort: String, CaseIterable {
    case name, frequency, created

    var label: String {
        switch self {
        case .name: "Name (A–Z)"
        case .frequency: "Frequency"
        case .created: "Recently added"
        }
    }
}

struct CadencesScreen: View {
    @Environment(Navigator.self) private var navigator
    @Environment(AppSettings.self) private var settings

    @Query private var cadences: [Cadence]
    @State private var search = ""
    @State private var sort: CadenceSort = .name
    @State private var createPresented = false
    @State private var quickBeatPresented = false
    @State private var createDiscoveryPresented = false

    var body: some View {
        @Bindable var navigator = navigator
        NavigationStack(path: $navigator.cadencePath) {
            List {
                ForEach(sorted, id: \.id) { cadence in
                    row(for: cadence)
                }
                if sorted.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Cadences")
            .navigationSubtitle("\(cadences.count) recurring")
            .searchable(text: $search, prompt: "Search cadences")
            .searchToolbarBehavior(.minimize)
            .navigationDestination(for: Cadence.self) { cadence in
                CadenceDetailScreen(cadence: cadence)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort cadences", selection: $sort) {
                            ForEach(CadenceSort.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Cadence", systemImage: "arrow.triangle.2.circlepath") {
                            createPresented = true
                        }
                        Button("Beat", systemImage: "flag") { quickBeatPresented = true }
                        Button("Discovery", systemImage: "target") {
                            createDiscoveryPresented = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $createPresented) {
                CreateCadenceSheet()
            }
            .sheet(isPresented: $quickBeatPresented) {
                QuickBeatSheet()
            }
            .sheet(isPresented: $createDiscoveryPresented) {
                CreateDiscoverySheet()
            }
        }
    }

    private func row(for cadence: Cadence) -> some View {
        NavigationLink(value: cadence) {
            HStack(alignment: .center, spacing: 12) {
                GlyphTile(glyph: cadence.glyph, colorHex: cadence.colorHex)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cadence.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(settings.density == .comfortable ? 2 : 1)
                    if settings.density == .comfortable {
                        frequencyChip(for: cadence)
                    }
                    if !cadence.note.isEmpty {
                        Text(cadence.note)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(settings.density == .comfortable ? 3 : 1)
                    }
                }
                if settings.density == .compact {
                    Spacer(minLength: 8)
                    frequencyChip(for: cadence)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func frequencyChip(for cadence: Cadence) -> some View {
        HStack(spacing: 4) {
            Image(
                systemName: cadence.scheduleType == .fixed
                    ? "anchor" : "arrow.triangle.2.circlepath"
            )
            .font(.system(size: 10, weight: .semibold))
            Text(cadence.frequency.shortLabel)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 7, style: .continuous))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            search.isEmpty ? "No cadences yet" : "No matches",
            systemImage: "arrow.triangle.2.circlepath",
            description: search.isEmpty
                ? Text("Create one with the + button — or start a Discovery if you don’t know the frequency yet.")
                : Text("No cadences match “\(search)”.")
        )
        .listRowBackground(Color.clear)
    }

    private var sorted: [Cadence] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        var list = cadences
        if !query.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(query) || $0.note.lowercased().contains(query)
            }
        }
        switch sort {
        case .name:
            return list.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .frequency:
            return list.sorted {
                $0.frequency.approximateDays < $1.frequency.approximateDays
            }
        case .created:
            return list.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
