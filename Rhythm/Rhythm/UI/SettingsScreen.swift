//
//  SettingsScreen.swift
//  Rhythm
//
//  Defaults and preferences, per spec → Settings. Native Form with
//  segmented controls, toggles, and a compact time picker.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your device’s appearance.")
                }

                Section {
                    Picker("Display density", selection: $settings.density) {
                        ForEach(DisplayDensity.allCases, id: \.self) { density in
                            Text(density.displayName).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Comfortable moves due dates below titles, giving text the full width.")
                }

                Section {
                    Toggle("Multi-line titles", isOn: $settings.multilineTitles)
                } footer: {
                    Text("Let long beat and cadence names wrap instead of truncating.")
                }

                Section {
                    Toggle("Show emojis", isOn: $settings.showEmoji)
                } footer: {
                    Text("Display emojis next to beats and cadences.")
                }

                Section {
                    Picker("Scheduling", selection: $settings.defaultScheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("New cadence defaults")
                } footer: {
                    Text(
                        "“Relative” counts from when you finish (haircut). “Fixed” keeps a hard schedule (utility bill)."
                    )
                }

                Section {
                    Toggle("Upcoming", isOn: $settings.defaultNotifyAlmost)
                    Toggle("Due", isOn: $settings.defaultNotifyDue)
                    Toggle("Overdue", isOn: $settings.defaultNotifyOverdue)
                    DatePicker(
                        "Default time", selection: defaultTimeBinding,
                        displayedComponents: .hourAndMinute)
                } header: {
                    Text("Default notifications")
                } footer: {
                    Text("Applied to new cadences. Each cadence and beat can override these.")
                }

                Section {
                    Toggle("Daily digest", isOn: $settings.dailyDigestEnabled)
                    if settings.dailyDigestEnabled {
                        DatePicker(
                            "Time", selection: digestTimeBinding,
                            displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Daily digest")
                } footer: {
                    Text(
                        "One summary of everything due or overdue, sent once a day — only when something’s waiting."
                    )
                }

                Section("Alerts") {
                    Toggle("Sound", isOn: $settings.sound)
                    Toggle("Vibrate", isOn: $settings.vibrate)
                }

                Section {
                    LabeledContent("Version", value: versionLabel)
                } header: {
                    Text("About")
                } footer: {
                    Text(
                        "Beats are due on a day, never a time. Notification time only controls when the reminder is delivered."
                    )
                }
            }
            .navigationTitle("Settings")
        }
    }

    /// Bridge minutes-since-midnight ↔ the hour/minute of an arbitrary Date.
    private var defaultTimeBinding: Binding<Date> {
        Binding {
            let cal = Calendar.current
            return cal.date(
                bySettingHour: settings.defaultNotifyMinutes / 60,
                minute: settings.defaultNotifyMinutes % 60,
                second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            settings.defaultNotifyMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    /// Bridge the digest's minutes-since-midnight ↔ a Date for the picker.
    private var digestTimeBinding: Binding<Date> {
        Binding {
            let cal = Calendar.current
            return cal.date(
                bySettingHour: settings.dailyDigestMinutes / 60,
                minute: settings.dailyDigestMinutes % 60,
                second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            settings.dailyDigestMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    private var versionLabel: String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
        return "\(version) (Rhythm)"
    }
}

#Preview {
    SettingsScreen()
        .environment(AppSettings())
}
