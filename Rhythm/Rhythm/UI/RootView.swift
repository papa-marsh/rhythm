//
//  RootView.swift
//  Rhythm
//
//  The tabbed app shell: Today, Cadences, Discovery, Settings. Hosts the
//  toast overlay and keeps the day ticker fresh across midnight/foreground.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DayTicker.self) private var ticker
    @Environment(\.scenePhase) private var scenePhase

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
        .overlay { ToastOverlay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { ticker.refresh() }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification)
        ) { _ in
            ticker.refresh()
        }
    }
}

// MARK: - Placeholders (filled in Stages 6–7)

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
