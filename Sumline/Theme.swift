import SwiftUI
import UIKit

/// "Aurora" design system — a deep midnight canvas lit by slow-drifting
/// aurora light, frosted-glass tiles, and a glowing signal path.
/// Light mode is "Dawn": the same aurora over soft morning pastel.
enum Theme {

    // MARK: - Canvas

    static let midnight = Color(red: 0.043, green: 0.055, blue: 0.102)
    static let dawnPaper = Color(red: 0.953, green: 0.949, blue: 0.988)
    static let canvas = Color(light: dawnPaper, dark: midnight)

    // MARK: - Aurora hues

    static let indigo = Color(red: 0.486, green: 0.424, blue: 1.000)
    static let teal = Color(red: 0.176, green: 0.890, blue: 0.769)
    static let magenta = Color(red: 0.898, green: 0.373, blue: 0.827)
    static let amber = Color(red: 1.000, green: 0.757, blue: 0.290)
    static let coral = Color(red: 1.000, green: 0.396, blue: 0.380)
    static let mint = Color(red: 0.290, green: 0.894, blue: 0.573)

    // MARK: - Glass surfaces

    static let glass = Color(light: Color.white.opacity(0.62),
                             dark: Color.white.opacity(0.055))
    static let glassBright = Color(light: Color.white.opacity(0.85),
                                   dark: Color.white.opacity(0.10))
    static let glassStroke = Color(light: Color.white.opacity(0.95),
                                   dark: Color.white.opacity(0.14))
    static let ink = Color(light: Color(red: 0.102, green: 0.094, blue: 0.188),
                           dark: Color(red: 0.949, green: 0.945, blue: 1.000))
    static let inkFaint = Color(light: Color(red: 0.102, green: 0.094, blue: 0.188).opacity(0.5),
                                dark: Color(red: 0.949, green: 0.945, blue: 1.000).opacity(0.5))

    static let pathGradient = LinearGradient(
        colors: [indigo, teal],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: - Color eras (the palette shifts every 10 levels)

    struct Palette: Equatable {
        let name: String
        let a: Color
        let b: Color

        var gradient: LinearGradient {
            LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static let palettes: [Palette] = [
        Palette(name: "Aurora", a: indigo, b: teal),
        Palette(name: "Ember", a: coral, b: amber),
        Palette(name: "Orchid", a: magenta, b: indigo),
        Palette(name: "Lagoon", a: Color(red: 0.10, green: 0.62, blue: 0.94), b: mint),
        Palette(name: "Sunset", a: amber, b: magenta),
        Palette(name: "Rose", a: Color(red: 1.00, green: 0.37, blue: 0.55), b: coral),
    ]

    /// Level 1-10 -> palette 0, 11-20 -> palette 1, ... cycling forever.
    static func palette(forLevel level: Int) -> Palette {
        palettes[(max(level, 1) - 1) / 10 % palettes.count]
    }

    static let heroGradient = LinearGradient(
        colors: [indigo, magenta, teal],
        startPoint: .leading, endPoint: .trailing)

    static let winGradient = LinearGradient(
        colors: [mint, teal],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: - Type

    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Glass card container

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var bright = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(bright ? Theme.glassBright : Theme.glass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Theme.glassStroke, Theme.glassStroke.opacity(0.25)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, bright: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, bright: bright))
    }
}

// MARK: - Haptics

enum Haptics {
    static var enabled = true

    static func tick() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Shared components

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(16))
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background {
                if prominent {
                    Capsule().fill(Theme.pathGradient)
                        .shadow(color: Theme.indigo.opacity(0.5), radius: 14, y: 4)
                } else {
                    Capsule().fill(Theme.glass)
                        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StatChip: View {
    let value: String
    let caption: String
    var tint: Color = Theme.ink

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.number(24))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(caption)
                .font(Theme.label(11, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16)
    }
}

struct Wordmark: View {
    var size: CGFloat = 19

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                .font(.system(size: size * 0.85, weight: .bold))
                .foregroundStyle(Theme.heroGradient)
            Text("SUMLINE")
                .font(Theme.label(size, weight: .heavy))
                .kerning(size * 0.16)
                .foregroundStyle(Theme.ink)
        }
        .shadow(color: Theme.indigo.opacity(0.35), radius: 12)
    }
}
