//
//  Components.swift
//  Rhythm
//
//  Shared visual vocabulary: emoji identity tiles, due chips, and the
//  beat row with its leading urgency bar (the locked "Bar" visual style).
//

import SwiftUI

// MARK: - Glyph tile

/// Emoji identity on a colored rounded tile. Hidden everywhere when the
/// "Show emojis" setting is off.
struct GlyphTile: View {
    @Environment(AppSettings.self) private var settings

    let glyph: String
    let colorHex: String
    var size: CGFloat = 31

    var body: some View {
        if settings.showEmoji {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(Color(hex: colorHex))
                .frame(width: size, height: size)
                .overlay {
                    Text(glyph)
                        .font(.system(size: size * 0.56))
                }
                .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 1, y: 1)
        }
    }
}

// MARK: - Due chip

/// Trailing due chip. `due`/`late` are filled (white on solid color);
/// `almost`/`overdue` are tinted; `later` is neutral. Snoozed beats keep
/// their tier coloring (computed from the snooze date) plus a 💤 icon.
struct DueChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let urgency: Urgency

    var body: some View {
        HStack(spacing: 4) {
            if urgency.isSnoozed {
                Image(systemName: "zzz")
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(urgency.chipLabel)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background, in: .rect(cornerRadius: 7, style: .continuous))
    }

    private var isNeutral: Bool { urgency.tier == .later }
    private var isFilled: Bool { urgency.tier == .due || urgency.tier == .late }

    private var foreground: Color {
        if isNeutral { return .secondary }
        if isFilled { return .white }
        return Theme.tierColor(urgency.tier)
    }

    private var background: Color {
        if isNeutral { return Color(.tertiarySystemFill) }
        let tier = Theme.tierColor(urgency.tier)
        return isFilled ? tier : tier.opacity(colorScheme == .dark ? 0.22 : 0.13)
    }
}

// MARK: - Beat row

/// A beat row: leading urgency bar · glyph tile · name (+ note, + snooze
/// line) · due chip. The locked "Bar" urgency style. In Comfortable
/// density the chip moves below the title so text gets the full width.
struct BeatRowView: View {
    @Environment(DayTicker.self) private var ticker
    @Environment(AppSettings.self) private var settings

    let beat: Beat

    var body: some View {
        let urgency = beat.urgency(today: ticker.today)
        HStack(alignment: settings.density == .comfortable ? .top : .center, spacing: 12) {
            GlyphTile(glyph: beat.glyph, colorHex: beat.colorHex)
            VStack(alignment: .leading, spacing: 3) {
                Text(beat.name)
                    .font(.system(size: 16.5, weight: .semibold))
                    .lineLimit(settings.density == .comfortable ? 2 : 1)
                if settings.density == .comfortable {
                    DueChip(urgency: urgency)
                }
                if !beat.note.isEmpty {
                    Text(beat.note)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(settings.density == .comfortable ? 3 : 1)
                }
                if urgency.isSnoozed {
                    HStack(spacing: 5) {
                        Image(systemName: "zzz")
                            .font(.system(size: 10, weight: .semibold))
                        Text(
                            "Originally due \(DayMath.relativePhrase(for: beat.due, from: ticker.today))"
                        )
                        .font(.system(size: 12.5))
                    }
                    .foregroundStyle(Theme.orange)
                    .lineLimit(1)
                }
            }
            if settings.density == .compact {
                Spacer(minLength: 8)
                DueChip(urgency: urgency)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 9)
        .frame(minHeight: 56)
        .overlay(alignment: .leading) {
            if urgency.tier.isUrgent {
                // Inset enough that iOS 26's large card corner radius
                // doesn't shave the bar on the first/last rows.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.tierColor(urgency.tier))
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .padding(.leading, 6)
            }
        }
    }
}
