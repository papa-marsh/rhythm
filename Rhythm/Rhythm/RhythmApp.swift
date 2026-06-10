//
//  RhythmApp.swift
//  Rhythm
//
//  Created by Marshall Warners on 6/9/26.
//

import SwiftUI
import SwiftData

@main
struct RhythmApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        // CloudKit mirroring stays off until the real schema lands (Stage 2);
        // .automatic would try to mirror the template Item model and crash.
        let modelConfiguration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
