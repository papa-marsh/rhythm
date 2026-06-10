//
//  ToastCenter.swift
//  Rhythm
//
//  Brief confirmation pill above the tab bar (complete/skip/snooze/create/
//  delete), ~2.2s. iOS has no native toast; this is the one piece of fully
//  custom chrome the spec requires.
//

import SwiftUI

struct Toast: Equatable {
    var message: String
    var systemImage: String
    var color: Color

    static func completed(nextScheduled: Bool) -> Toast {
        Toast(
            message: nextScheduled ? "Completed · next beat scheduled" : "Completed",
            systemImage: "checkmark", color: Theme.green)
    }
}

@MainActor
@Observable
final class ToastCenter {
    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: Toast) {
        dismissTask?.cancel()
        current = toast
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }

    func show(_ message: String, systemImage: String, color: Color) {
        show(Toast(message: message, systemImage: systemImage, color: color))
    }
}

struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        VStack {
            Spacer()
            if let toast = toasts.current {
                HStack(spacing: 9) {
                    Image(systemName: toast.systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(toast.color)
                    Text(toast.message)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.regularMaterial.shadow(.drop(radius: 12, y: 4)), in: .capsule)
                .environment(\.colorScheme, .dark)
                .padding(.bottom, 70)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toasts.current)
        .allowsHitTesting(false)
    }
}
