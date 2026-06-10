//
//  RhythmApp.swift
//  Rhythm
//

import SwiftData
import SwiftUI

@main
struct RhythmApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Cadence.self,
            Beat.self,
            HistoryEntry.self,
            Discovery.self,
            DiscoveryLog.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.marshallwarners.RhythmData")
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
