//
//  AppSettings.swift
//  Rhythm
//
//  User preferences, persisted to UserDefaults. Local-only by design —
//  appearance and alert behavior are device preferences, not synced data.
//

import SwiftUI

enum DisplayDensity: String, CaseIterable {
    case compact, comfortable

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .comfortable: "Comfortable"
        }
    }
}

enum Appearance: String, CaseIterable {
    case light, dark, system

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    private static let defaults = UserDefaults.standard

    var appearance: Appearance {
        didSet { Self.defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    var showEmoji: Bool {
        didSet { Self.defaults.set(showEmoji, forKey: "showEmoji") }
    }
    var density: DisplayDensity {
        didSet { Self.defaults.set(density.rawValue, forKey: "density") }
    }
    var defaultScheduleType: ScheduleType {
        didSet { Self.defaults.set(defaultScheduleType.rawValue, forKey: "defaultScheduleType") }
    }
    var defaultNotifyAlmost: Bool {
        didSet { Self.defaults.set(defaultNotifyAlmost, forKey: "defaultNotifyAlmost") }
    }
    var defaultNotifyDue: Bool {
        didSet { Self.defaults.set(defaultNotifyDue, forKey: "defaultNotifyDue") }
    }
    var defaultNotifyOverdue: Bool {
        didSet { Self.defaults.set(defaultNotifyOverdue, forKey: "defaultNotifyOverdue") }
    }
    var defaultNotifyMinutes: Int {
        didSet { Self.defaults.set(defaultNotifyMinutes, forKey: "defaultNotifyMinutes") }
    }
    var sound: Bool {
        didSet { Self.defaults.set(sound, forKey: "sound") }
    }
    var vibrate: Bool {
        didSet { Self.defaults.set(vibrate, forKey: "vibrate") }
    }

    /// Default notification preferences applied to new cadences.
    var defaultNotify: NotifyPreferences {
        NotifyPreferences(
            almost: defaultNotifyAlmost, due: defaultNotifyDue,
            overdue: defaultNotifyOverdue, minutes: defaultNotifyMinutes)
    }

    init() {
        let d = Self.defaults
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        showEmoji = d.object(forKey: "showEmoji") as? Bool ?? true
        density = DisplayDensity(rawValue: d.string(forKey: "density") ?? "") ?? .compact
        defaultScheduleType =
            ScheduleType(rawValue: d.string(forKey: "defaultScheduleType") ?? "") ?? .relative
        defaultNotifyAlmost = d.object(forKey: "defaultNotifyAlmost") as? Bool ?? false
        defaultNotifyDue = d.object(forKey: "defaultNotifyDue") as? Bool ?? true
        defaultNotifyOverdue = d.object(forKey: "defaultNotifyOverdue") as? Bool ?? true
        defaultNotifyMinutes = d.object(forKey: "defaultNotifyMinutes") as? Int ?? 9 * 60
        sound = d.object(forKey: "sound") as? Bool ?? true
        vibrate = d.object(forKey: "vibrate") as? Bool ?? true
    }
}
