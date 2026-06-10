//
//  RootView.swift
//  Rhythm
//
//  The tabbed app shell: Today, Cadences, Discovery, Settings.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                TodayScreen()
            }
            Tab("Cadences", systemImage: "arrow.triangle.2.circlepath") {
                CadencesScreen()
            }
            Tab("Discovery", systemImage: "safari") {
                DiscoveryScreen()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsScreen()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}

// MARK: - Placeholders (filled in Stages 4–7)

struct TodayScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Today", systemImage: "calendar", description: Text("Coming in Stage 4"))
        }
    }
}

struct CadencesScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Cadences", systemImage: "arrow.triangle.2.circlepath",
                description: Text("Coming in Stage 6"))
        }
    }
}

struct DiscoveryScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Discovery", systemImage: "safari", description: Text("Coming in Stage 7"))
        }
    }
}
