//
//  Navigator.swift
//  Rhythm
//
//  Cross-tab navigation state: which tab is selected and the Cadences
//  tab's push stack — so e.g. Beat Detail's "Part of cadence" row can jump
//  to a cadence from anywhere.
//

import SwiftUI

enum AppTab: Hashable {
    case today, cadences, discovery, settings
}

@MainActor
@Observable
final class Navigator {
    var tab: AppTab = .today
    var cadencePath: [Cadence] = []

    func openCadence(_ cadence: Cadence) {
        tab = .cadences
        cadencePath = [cadence]
    }
}
