//
//  ContentView.swift
//  Rhythm
//
//  Placeholder root — replaced by the tabbed app shell in Stage 3.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.tint)
            Text("Rhythm")
                .font(.largeTitle.bold())
        }
    }
}

#Preview {
    ContentView()
}
