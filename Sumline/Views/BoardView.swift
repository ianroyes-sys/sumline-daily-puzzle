import SwiftUI

/// The 5x5 grid with drag-to-draw path input. Glass tiles over the aurora,
/// with a glowing gradient stroke for the player's line.
struct BoardView: View {
    let puzzle: Puzzle
    @Binding var path: [Int]
    var solved: Bool
    var failedFlash: Bool
    var hintCells: [Int]
    var palette: Theme.Palette = Theme.palettes[0]
    var onPathChanged: () -> Void
    var onRelease: () -> Void

    private let size = Puzzle.gridSize

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cell = side / CGFloat(size)

            ZStack {
                tiles(cell: cell)
                pathGlow(cell: cell)
                pathStroke(cell: cell)
                numbers(cell: cell)
                hints(cell: cell)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !solved else { return }
                        handleDrag(at: value.location, cell: cell)
                    }
                    .onEnded { _ in
                        guard !solved else { return }
                        onRelease()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Layers

    private func tiles(cell: CGFloat) -> some View {
        ForEach(0..<25, id: \.self) { index in
            let inPath = path.contains(index)
            RoundedRectangle(cornerRadius: cell * 0.26, style: .continuous)
                .fill(Theme.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: cell * 0.26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Theme.glassStroke, Theme.glassStroke.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
                .frame(width: cell - 9, height: cell - 9)
                .position(center(of: index, cell: cell))
                .scaleEffect(inPath ? 1.05 : 1, anchor: .center)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: inPath)
        }
    }

    /// A soft luminous halo underneath the stroke — the "aurora" of the line.
    private func pathGlow(cell: CGFloat) -> some View {
        strokeShape(cell: cell, width: cell * 0.62)
            .blur(radius: 14)
            .opacity(solved ? 0.9 : 0.55)
            .animation(.easeOut(duration: 0.3), value: solved)
    }

    private func pathStroke(cell: CGFloat) -> some View {
        strokeShape(cell: cell, width: cell * 0.44)
            .animation(.easeOut(duration: 0.15), value: path)
    }

    @ViewBuilder
    private func strokeShape(cell: CGFloat, width: CGFloat) -> some View {
        if !path.isEmpty {
            let points = path.map { center(of: $0, cell: cell) }
            if points.count == 1 {
                Circle()
                    .fill(fillStyle)
                    .frame(width: width, height: width)
                    .position(points[0])
            } else {
                Path { p in p.addLines(points) }
                    .stroke(style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    .fill(fillStyle)
            }
        }
    }

    private var fillStyle: AnyShapeStyle {
        if failedFlash { return AnyShapeStyle(Theme.coral) }
        if solved { return AnyShapeStyle(Theme.winGradient) }
        return AnyShapeStyle(palette.gradient)
    }

    private func numbers(cell: CGFloat) -> some View {
        ForEach(0..<25, id: \.self) { index in
            let inPath = path.contains(index)
            Text("\(puzzle.values[index])")
                .font(Theme.number(cell * 0.42))
                .foregroundStyle(inPath ? Color.white : Theme.ink)
                .shadow(color: inPath ? .black.opacity(0.3) : .clear, radius: 2, y: 1)
                .position(center(of: index, cell: cell))
                .animation(.easeOut(duration: 0.12), value: inPath)
        }
    }

    private func hints(cell: CGFloat) -> some View {
        ForEach(hintCells, id: \.self) { index in
            Circle()
                .strokeBorder(Theme.amber, lineWidth: 3)
                .shadow(color: Theme.amber.opacity(0.7), radius: 8)
                .frame(width: cell * 0.85, height: cell * 0.85)
                .position(center(of: index, cell: cell))
                .modifier(PulseEffect())
        }
    }

    // MARK: - Geometry & input

    private func center(of index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(index % size) + 0.5) * cell,
                y: (CGFloat(index / size) + 0.5) * cell)
    }

    private func handleDrag(at location: CGPoint, cell: CGFloat) {
        let col = Int(location.x / cell)
        let row = Int(location.y / cell)
        guard (0..<size).contains(col), (0..<size).contains(row) else { return }
        let index = row * size + col

        // Require the touch to be near the cell's center so diagonal swipes
        // don't grab unintended tiles.
        let c = center(of: index, cell: cell)
        let distance = hypot(location.x - c.x, location.y - c.y)
        guard distance < cell * 0.38 else { return }

        if path.isEmpty {
            path = [index]
            onPathChanged()
        } else if index == path.last {
            return
        } else if path.count >= 2 && index == path[path.count - 2] {
            path.removeLast() // backtrack
            onPathChanged()
        } else if puzzle.areAdjacent(path[path.count - 1], index), !path.contains(index) {
            path.append(index)
            onPathChanged()
        }
    }
}

struct PulseEffect: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.06 : 0.94)
            .opacity(pulsing ? 1 : 0.6)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}
