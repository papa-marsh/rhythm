//
//  RhythmApp.swift
//  Rhythm
//

import SwiftData
import SwiftUI

@main
struct RhythmApp: App {
    let sharedModelContainer: ModelContainer
    @State private var store: RhythmStore
    @State private var settings = AppSettings()
    @State private var ticker = DayTicker()
    @State private var toasts = ToastCenter()

    init() {
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
            sharedModelContainer = try ModelContainer(
                for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        _store = State(initialValue: RhythmStore(context: sharedModelContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(ticker)
                .environment(toasts)
                #if DEBUG
                    .task { seedIfEmpty() }
                #endif
        }
        .modelContainer(sharedModelContainer)
    }

    #if DEBUG
        /// Simulator/dev convenience: start with the prototype's sample data.
        @MainActor
        private func seedIfEmpty() {
            let context = sharedModelContainer.mainContext
            let cadences = (try? context.fetchCount(FetchDescriptor<Cadence>())) ?? 0
            let beats = (try? context.fetchCount(FetchDescriptor<Beat>())) ?? 0
            guard cadences == 0 && beats == 0 else { return }
            SeedData.populate(context)
        }
    #endif
}
