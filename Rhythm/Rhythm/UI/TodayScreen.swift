//
//  TodayScreen.swift
//  Rhythm
//
//  The main list: beats that currently matter, smart-sorted by urgency
//  (tier severity desc, then days-until-due asc), with non-urgent beats
//  split into a "Later" section. Swipe right to complete; swipe left for
//  Skip / Snooze.
//

import SwiftData
import SwiftUI

struct TodayScreen: View {
    @Environment(RhythmStore.self) private var store
    @Environment(DayTicker.self) private var ticker
    @Environment(ToastCenter.self) private var toasts

    @Query private var beats: [Beat]
    @State private var search = ""
    @State private var addMenuPresented = false
    @State private var detailBeat: Beat?
    @State private var snoozeBeat: Beat?
    @State private var quickBeatPresented = false
    @State private var createCadencePresented = false
    @State private var createDiscoveryPresented = false

    var body: some View {
        NavigationStack {
            List {
                if !urgent.isEmpty || !later.isEmpty {
                    summaryStrip
                }

                if urgent.isEmpty {
                    allCaughtUp
                } else {
                    Section {
                        ForEach(urgent, id: \.id) { beat in
                            row(for: beat)
                        }
                    }
                }

                if !later.isEmpty {
                    Section("Later") {
                        ForEach(later, id: \.id) { beat in
                            row(for: beat)
                        }
                    }
                }
            }
            .listRowSpacing(0)
            .navigationTitle("Today")
            .navigationSubtitle(subtitle)
            .searchable(text: $search, prompt: "Search beats")
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        addMenuPresented = true
                    }
                }
            }
            .confirmationDialog("Add to Rhythm", isPresented: $addMenuPresented, titleVisibility: .visible) {
                Button("Cadence") { createCadencePresented = true }
                Button("Beat") { quickBeatPresented = true }
                Button("Discovery") { createDiscoveryPresented = true }
            }
            .sheet(item: $detailBeat) { beat in
                BeatDetailSheet(beat: beat) { snoozeBeat = $0 }
            }
            .sheet(item: $snoozeBeat) { beat in
                SnoozeSheet(beat: beat)
            }
            .sheet(isPresented: $quickBeatPresented) {
                QuickBeatSheet()
            }
            .sheet(isPresented: $createCadencePresented) {
                CreateCadenceSheet()
            }
            .sheet(isPresented: $createDiscoveryPresented) {
                CreateDiscoverySheet()
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(for beat: Beat) -> some View {
        BeatRowView(beat: beat)
            .listRowInsets(EdgeInsets())
            .contentShape(.rect)
            .onTapGesture { detailBeat = beat }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    complete(beat)
                } label: {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(Theme.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // First listed sits at the screen edge (outermost): Snooze,
                // then Skip inboard of it, per spec's inner→outer order.
                Button {
                    snooze(beat)
                } label: {
                    Label("Snooze", systemImage: "zzz")
                }
                .tint(Theme.orange)
                Button {
                    skip(beat)
                } label: {
                    Label("Skip", systemImage: "forward.end")
                }
                .tint(Color(lightHex: "#8E8E93", darkHex: "#48484A"))
            }
    }

    // MARK: Actions

    private func complete(_ beat: Beat) {
        let linked = beat.cadence != nil
        store.complete(beat)
        toasts.show(.completed(nextScheduled: linked))
    }

    private func skip(_ beat: Beat) {
        store.skip(beat)
        toasts.show("Skipped", systemImage: "forward.end", color: Theme.orange)
    }

    private func snooze(_ beat: Beat) {
        snoozeBeat = beat
    }

    // MARK: Derived lists

    private var filtered: [Beat] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return beats }
        return beats.filter {
            $0.name.lowercased().contains(query) || $0.note.lowercased().contains(query)
        }
    }

    private struct RankedBeat {
        let beat: Beat
        let urgency: Urgency
    }

    private var ranked: [RankedBeat] {
        let today = ticker.today
        return filtered.map { beat in
            RankedBeat(beat: beat, urgency: beat.urgency(today: today))
        }
    }

    /// Smart sort: tier severity descending, then closeness ascending.
    private var urgent: [Beat] {
        ranked
            .filter { $0.urgency.tier.isUrgent }
            .sorted { (a: RankedBeat, b: RankedBeat) in
                if a.urgency.tier != b.urgency.tier {
                    return a.urgency.tier > b.urgency.tier
                }
                return a.urgency.daysUntilDue < b.urgency.daysUntilDue
            }
            .map(\.beat)
    }

    private var later: [Beat] {
        ranked
            .filter { !$0.urgency.tier.isUrgent }
            .sorted { (a: RankedBeat, b: RankedBeat) in
                a.urgency.daysUntilDue < b.urgency.daysUntilDue
            }
            .map(\.beat)
    }

    // MARK: Header pieces

    private var subtitle: String {
        ticker.today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var overdueCount: Int {
        filtered.count { $0.urgency(today: ticker.today).tier >= .overdue }
    }

    private var upcomingCount: Int {
        filtered.count {
            let tier = $0.urgency(today: ticker.today).tier
            return tier == .almost || tier == .due
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 16) {
            if overdueCount > 0 {
                countDot(count: overdueCount, label: "overdue", color: Theme.red)
            }
            if upcomingCount > 0 {
                countDot(count: upcomingCount, label: "upcoming", color: Theme.accent)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
        .listRowSeparator(.hidden)
    }

    private func countDot(count: Int, label: String, color: Color) -> some View {
        let text: Text =
            Text("\(count)").fontWeight(.semibold)
            + Text(" \(label)").foregroundStyle(.secondary)
        return HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            text
        }
        .font(.system(size: 13.5))
    }

    private var allCaughtUp: some View {
        Section {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.green)
                Text("All caught up")
                    .font(.system(size: 19, weight: .bold))
                Text("Nothing’s within its grace period.\nEnjoy the quiet.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}
