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
    @Environment(Navigator.self) private var navigator
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var navigator = navigator
        TabView(selection: $navigator.tab) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                TodayScreen()
            }
            Tab("Cadences", systemImage: "arrow.triangle.2.circlepath", value: AppTab.cadences) {
                CadencesScreen()
            }
            Tab("Discovery", systemImage: "safari", value: AppTab.discovery) {
                DiscoveryScreen()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .overlay { ToastOverlay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ticker.refresh()
                scheduler.replan()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification)
        ) { _ in
            ticker.refresh()
            scheduler.replan()
        }
        // These settings are baked into scheduled notification content.
        .onChange(of: settings.sound) { scheduler.replan() }
        .onChange(of: settings.showEmoji) { scheduler.replan() }
    }
}


