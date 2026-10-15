import SwiftUI

/// Sine wave filled below `level` (0 = empty, 1 = full).
struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, amplitude) }
        set { level = newValue.first; amplitude = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y0 = rect.height * (1 - level)
        p.move(to: CGPoint(x: 0, y: rect.height))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let rel = x / rect.width
            p.addLine(to: CGPoint(x: x, y: y0 + sin(rel * 2 * .pi * 1.3 + phase) * amplitude))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// Thick ink ring + rising aqua wave + bubbles + percent in Fredoka. `sloshTrigger` changes on each log.
struct WaterRing: View {
    var progress: Double
    var sloshTrigger: Int
    @State private var slosh = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let level = min(max(progress, 0), 1)
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let s = geo.size.width
                ZStack {
                    Circle().fill(Theme.background)
                    WaveShape(level: level, phase: t * 1.6 + 1.2, amplitude: s * (0.025 + slosh * 0.04))
                        .fill(Theme.water.opacity(0.45))
                    WaveShape(level: level, phase: t * 2.2, amplitude: s * (0.03 + slosh * 0.05))
                        .fill(Theme.water)
                    if level > 0.05 && !reduceMotion { bubbles(t: t, size: s, level: level) }
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.fredoka(48, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.5)
                        .position(x: s / 2, y: s * 0.26)
                }
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: max(8, s * 0.04)))
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(.spring(duration: 0.9, bounce: 0.3), value: level)
        .onChange(of: sloshTrigger) {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.15)) { slosh = 1 }
            withAnimation(.easeInOut(duration: 1.2).delay(0.15)) { slosh = 0 }
        }
        .accessibilityElement()
        .accessibilityLabel("Today's progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent of goal")
    }

    private func bubbles(t: Double, size s: CGFloat, level: Double) -> some View {
        ForEach(0..<5, id: \.self) { i in
            let speed = 0.12 + Double(i) * 0.03
            let cycle = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
            let top = 1 - level
            let y = s * (1 - cycle * level * 0.9)
            Circle().fill(.white.opacity(0.55))
                .frame(width: s * (0.025 + Double(i % 3) * 0.012))
                .position(x: s * (0.25 + Double(i) * 0.12 + sin(t + Double(i)) * 0.02), y: max(y, s * (top + 0.05)))
        }
    }
}
