//
//  FormComponents.swift
//  Rhythm
//
//  Shared form pieces: the emoji + color identity picker (no preset emoji
//  grid — tap the tile and type any emoji) and labeled stepper rows.
//

import SwiftUI

// MARK: - Glyph + color picker

struct GlyphColorPicker: View {
    @Binding var glyph: String
    @Binding var colorHex: String

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Button {
                    focused = true
                } label: {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(hex: colorHex))
                        .frame(width: 78, height: 78)
                        .overlay {
                            TextField("", text: $text)
                                .focused($focused)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 42))
                                .tint(.white.opacity(0.7))
                        }
                        .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                Text("Tap to pick an emoji")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 10)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(Theme.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if colorHex == hex {
                                    Circle()
                                        .strokeBorder(.background, lineWidth: 2.5)
                                        .padding(1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .onAppear { text = glyph }
        .onChange(of: text) { _, newValue in
            // Keep only the most recent grapheme (one emoji).
            guard let last = newValue.last.map(String.init), !newValue.isEmpty else {
                text = glyph
                return
            }
            if last != text { text = last }
            glyph = last
        }
    }
}

// MARK: - Stepper row

/// "Grace period   3 days  [- +]" — labeled value with a native stepper.
struct StepperRow: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...365
    var unit: (Int) -> String = { $0 == 1 ? "day" : "days" }

    var body: some View {
        HStack {
            Stepper(value: $value, in: range) {
                HStack {
                    Text(label)
                    Spacer()
                    Text("\(value) \(unit(value))")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Notification preference rows

/// The three grace-tied toggles + delivery time, bound to a NotifyPreferences.
struct NotifyRows: View {
    @Binding var notify: NotifyPreferences

    var body: some View {
        Toggle("Almost due", isOn: $notify.almost)
        Toggle("Due", isOn: $notify.due)
        Toggle("Overdue", isOn: $notify.overdue)
        DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
    }

    private var timeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: notify.minutes / 60, minute: notify.minutes % 60,
                second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            notify.minutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }
}
