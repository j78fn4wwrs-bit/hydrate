import SwiftUI

/// Animated brand intro (~1.5 s) on every launch.
/// Frame 0 matches the static UILaunchScreen exactly: solid LaunchBackground (#FF5A3C) + LaunchMark (reverse logo, 240 pt) centered.
/// Then: pink gradient fades in, the wordmark eases down, the app icon springs in with a drop ripple, then `onFinish`.
struct IntroView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gradient = false
    @State private var iconIn = false
    @State private var ripple = false
    @State private var markDown = false

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Color("LaunchBackground")
                LinearGradient(colors: [Theme.coral, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(gradient ? 1 : 0)

                // Ripple rings behind the icon
                ForEach(0..<2, id: \.self) { i in
                    Circle().stroke(.white.opacity(0.6), lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ripple ? 2.4 + Double(i) * 0.6 : 0.6)
                        .opacity(ripple ? 0 : (iconIn ? 0.8 : 0))
                        .position(x: center.x, y: center.y - 70)
                }

                Image("DewbyIcon").resizable().scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))   // iOS icon squircle ratio ≈ 22.5%
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                    .scaleEffect(iconIn ? 1 : 0.3)
                    .opacity(iconIn ? 1 : 0)
                    .position(x: center.x, y: center.y - 70)

                // Same asset/size/position as the static launch screen at frame 0.
                Image("LaunchMark")
                    .frame(width: 240)
                    .scaleEffect(markDown ? 0.8 : 1)
                    .position(x: center.x, y: center.y + (markDown ? 70 : 0))
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Dewby")
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            // No motion: simple fades only.
            withAnimation(.easeInOut(duration: 0.4)) { gradient = true; iconIn = true; markDown = true }
            try? await Task.sleep(for: .milliseconds(1100))
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { gradient = true }
            withAnimation(.spring(duration: 0.55, bounce: 0.25).delay(0.1)) { markDown = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.55).delay(0.25)) { iconIn = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.55)) { ripple = true }
            try? await Task.sleep(for: .milliseconds(1500))
        }
        onFinish()
    }
}
