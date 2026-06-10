//
//  DayTicker.swift
//  Rhythm
//
//  "Today" as observable app state. Urgency must never be computed from a
//  cached date: the ticker refreshes at midnight (significant time change),
//  on foreground, and on time-zone changes, re-rendering everything that
//  reads it.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DayTicker {
    private(set) var today: Date

    init(calendar: Calendar = .current) {
        today = DayMath.startOfDay(.now, calendar: calendar)
    }

    func refresh(calendar: Calendar = .current) {
        let now = DayMath.startOfDay(.now, calendar: calendar)
        if now != today {
            today = now
        }
    }
}
