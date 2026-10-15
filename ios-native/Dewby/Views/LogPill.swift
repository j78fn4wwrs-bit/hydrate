import SwiftUI

/// Big coral→pink pill with chunky 3D shadow; press = squash. Sparkle burst on tap. Haptic via .sensoryFeedback at call site.
struct LogPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.fredoka(22, relativeTo: .title2))
            .foregroundStyle(.white)          // white on coral: ≥17pt semibold per handoff
            .frame(maxWidth: .infinity, minHeight: 64)
            .background {
                ZStack {
                    Capsule().fill(Theme.pink.mix(with: .black, by: 0.25)).offset(y: pressed ? 2 : 7)
                    Capsule().fill(Theme.logGradient).offset(y: pressed ? 2 : 0)
                }
            }
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(x: pressed ? 1.04 : 1, y: pressed ? 0.9 : 1)
            .shadow(color: Theme.pink.opacity(0.35), radius: 14, y: 8)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: pressed)
    }
}

struct SparkleBurst: View {
    var trigger: Int
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let a = Double(i) / 10 * 2 * .pi
                Image(systemName: i.isMultiple(of: 2) ? "sparkle" : "drop.fill")
                    .font(.system(size: i.isMultiple(of: 2) ? 14 : 9))
                    .foregroundStyle(i.isMultiple(of: 3) ? Theme.celebrate : Theme.water)
                    .offset(x: go ? cos(a) * 110 : 0, y: go ? sin(a) * 48 : 0)
                    .opacity(go ? 0 : 1)
                    .scaleEffect(go ? 1.2 : 0.3)
            }
        }
        .opacity(trigger == 0 ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            go = false
            withAnimation(.easeOut(duration: 0.6)) { go = true }
        }
    }
}

struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.s)
            .background(Theme.background, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
