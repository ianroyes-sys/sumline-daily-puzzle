import SwiftUI

/// The viral artifact: a 1080x1350 (4:5) image of your solve — the path
/// drawn as a glowing abstract fingerprint, no numbers spoiled.
struct ShareCardView: View {
    let title: String
    let subtitle: String
    let path: [Int]
    let statLine: String
    let footer: String

    var body: some View {
        VStack(spacing: 44) {
            HStack(spacing: 14) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.heroGradient)
                Text("SUMLINE")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .kerning(10)
                    .foregroundStyle(.white)
            }
            .padding(.top, 70)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            PathFingerprint(path: path)
                .frame(width: 560, height: 560)
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 2)
                )

            Text(statLine)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 44)
                .padding(.vertical, 20)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 2))

            Spacer()

            Text(footer)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 64)
        }
        .frame(width: 1080, height: 1350)
        .background(cardBackground)
    }

    /// Static aurora — same blobs as the app background, frozen for print.
    private var cardBackground: some View {
        ZStack {
            Theme.midnight
            Canvas { context, size in
                let blobs: [(Double, Double, Color, Double)] = [
                    (0.12, 0.10, Theme.indigo, 0.55),
                    (0.92, 0.20, Theme.teal, 0.45),
                    (0.25, 0.60, Theme.magenta, 0.50),
                    (0.88, 0.85, Theme.indigo, 0.50),
                    (0.10, 0.95, Theme.teal, 0.40),
                ]
                for (bx, by, color, br) in blobs {
                    let cx = bx * size.width
                    let cy = by * size.height
                    let r = br * size.width
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                        with: .radialGradient(
                            Gradient(colors: [color.opacity(0.34), color.opacity(0)]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0, endRadius: r))
                }
            }
            .blur(radius: 60)
        }
    }
}

/// The player's path as pure geometry on a dot grid — a brag that never
/// spoils the day's numbers.
struct PathFingerprint: View {
    let path: [Int]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(Puzzle.gridSize)

            ZStack {
                ForEach(0..<25, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(path.contains(index) ? 0 : 0.22))
                        .frame(width: cell * 0.14, height: cell * 0.14)
                        .position(center(of: index, cell: cell))
                }

                if path.count > 1 {
                    let points = path.map { center(of: $0, cell: cell) }
                    let shape = Path { p in p.addLines(points) }
                    shape
                        .stroke(style: StrokeStyle(lineWidth: cell * 0.42, lineCap: .round, lineJoin: .round))
                        .fill(Theme.pathGradient)
                        .shadow(color: Theme.indigo.opacity(0.8), radius: 24)

                    Circle()
                        .fill(Color.white)
                        .frame(width: cell * 0.20, height: cell * 0.20)
                        .position(points[0])
                    Circle()
                        .fill(Color.white)
                        .frame(width: cell * 0.20, height: cell * 0.20)
                        .position(points[points.count - 1])
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func center(of index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(index % Puzzle.gridSize) + 0.5) * cell,
                y: (CGFloat(index / Puzzle.gridSize) + 0.5) * cell)
    }
}

// MARK: - Rendering

@MainActor
enum ShareCardRenderer {
    static func render(title: String, subtitle: String, path: [Int],
                       statLine: String, footer: String) -> Image? {
        let view = ShareCardView(title: title, subtitle: subtitle, path: path,
                                 statLine: statLine, footer: footer)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
