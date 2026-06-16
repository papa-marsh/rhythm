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
        .onChange(of: focused) { _, isFocused in
            // Clear on focus so typing replaces rather than appends; if the
            // field is dismissed still empty, fall back to the prior glyph
            // (which was never overwritten).
            if isFocused {
                text = ""
            } else if text.isEmpty {
                text = glyph
            }
        }
        .onChange(of: text) { _, newValue in
            // Keep only the most recent grapheme (one emoji). Empty is
            // allowed while editing — focus loss restores the glyph.
            guard let last = newValue.last.map(String.init) else { return }
            if last != newValue { text = last }
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

// MARK: - Schedule type cards

/// The two selectable Relative/Fixed cards with descriptions.
struct ScheduleTypeCards: View {
    @Binding var selection: ScheduleType

    var body: some View {
        card(
            .relative, icon: "checkmark",
            description: "Counts from when you finish. Best for mowing, haircuts — things that drift.")
        card(
            .fixed, icon: "calendar",
            description: "Hard schedule regardless of completion. Best for bills, trash day.")
    }

    private func card(_ type: ScheduleType, icon: String, description: String) -> some View {
        Button {
            selection = type
        } label: {
            HStack(alignment: .top, spacing: 13) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selection == type ? Theme.accent : Color(.tertiarySystemFill))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selection == type ? .white : .secondary)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selection == type ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selection == type ? Theme.accent : Color(.systemGray3))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Frequency picker

/// Directly-editable count + stepper, with the unit selector beneath.
struct FrequencyPickerView: View {
    @Binding var n: Int
    @Binding var unit: FrequencyUnit

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text("Every")
                    .foregroundStyle(.secondary)
                TextField("Count", value: countBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 64)
                    .padding(.vertical, 4)
                    .background(
                        Color(.tertiarySystemFill),
                        in: .rect(cornerRadius: 9, style: .continuous))
                Stepper("Count", value: $n, in: 1...999)
                    .labelsHidden()
            }
            Picker("Unit", selection: $unit) {
                Text("days").tag(FrequencyUnit.days)
                Text("weeks").tag(FrequencyUnit.weeks)
                Text("months").tag(FrequencyUnit.months)
                Text("years").tag(FrequencyUnit.years)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    /// Clamp typed values to a sane range.
    private var countBinding: Binding<Int> {
        Binding {
            n
        } set: {
            n = min(max($0, 1), 999)
        }
    }
}

// MARK: - Keyboard dismissal

/// Resign whichever field is first responder. The editor forms don't share
/// a FocusState across their fields, so dismissal goes through UIKit.
@MainActor
private func endTextEditing() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension View {
    /// Editor-sheet keyboard chrome: a Done button above the keyboard plus
    /// drag-to-dismiss. Apply to the sheet's Form — keyboard toolbar items
    /// declared on views *inside* the scroll content vanish when their row
    /// scrolls offscreen.
    func keyboardDismissal() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { endTextEditing() }
                }
            }
    }
}

// MARK: - Notification preference rows

/// The three grace-tied toggles + delivery time, bound to a NotifyPreferences.
struct NotifyRows: View {
    @Binding var notify: NotifyPreferences

    var body: some View {
        Toggle("Upcoming", isOn: $notify.almost)
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
