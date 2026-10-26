import SwiftUI

/// The living backdrop: large soft-light blobs drifting slowly across the
/// canvas, blurred into an aurora. Runs at a gentle frame rate so it sips
/// battery; pauses entirely for Reduce Motion.
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Blob spec: base position (unit space), orbit radius, speed, hue, size.
    private struct Blob {
        let x: Double, y: Double
        let orbit: Double
        let speed: Double
        let phase: Double
        let color: Color
        let radius: Double
    }

    private static let blobs: [Blob] = [
        Blob(x: 0.15, y: 0.10, orbit: 0.10, speed: 0.09, phase: 0.0, color: Theme.indigo, radius: 0.55),
        Blob(x: 0.90, y: 0.22, orbit: 0.08, speed: 0.07, phase: 2.1, color: Theme.teal, radius: 0.45),
        Blob(x: 0.30, y: 0.55, orbit: 0.12, speed: 0.05, phase: 4.0, color: Theme.magenta, radius: 0.50),
        Blob(x: 0.85, y: 0.80, orbit: 0.09, speed: 0.08, phase: 1.2, color: Theme.indigo, radius: 0.50),
        Blob(x: 0.10, y: 0.95, orbit: 0.07, speed: 0.06, phase: 5.3, color: Theme.teal, radius: 0.42),
    ]

    var body: some View {
        ZStack {
            Theme.canvas

            TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1 / 24,
                                    paused: reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let alpha = colorScheme == .dark ? 0.32 : 0.38
                    for blob in Self.blobs {
                        let cx = (blob.x + cos(t * blob.speed + blob.phase) * blob.orbit) * size.width
                        let cy = (blob.y + sin(t * blob.speed * 0.9 + blob.phase) * blob.orbit) * size.height
                        let r = blob.radius * min(size.width, size.height)
                        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [blob.color.opacity(alpha), blob.color.opacity(0)]),
                                center: CGPoint(x: cx, y: cy),
                                startRadius: 0, endRadius: r))
                    }
                }
            }
            .blur(radius: 40)
            .ignoresSafeArea()

            // Subtle vignette keeps edges calm so content pops.
            RadialGradient(colors: [.clear, Theme.canvas.opacity(0.55)],
                           center: .center, startRadius: 120, endRadius: 700)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
