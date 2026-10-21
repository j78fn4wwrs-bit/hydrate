import SwiftUI

/// Jim's approved brand intro — concept 3b "water ripple reveal" (oahzi-intro/MOTION_NOTES.md).
/// Design canvas 393×852 pt (final frame 1179×2556 px @3x). Frame 0 = IntroBackground only (same image as
/// LaunchScreen.storyboard, aspect-fill), so nothing jumps.
/// Three radial wave packets launch from the icon centre; the icon surfaces under the distortion (Ripple.metal),
/// cross-fades to a crisp copy at 1.9–2.1 s, then "Oahzi" types in with a cursor.
/// Calls `onFinish` at 3.0 s (Reduce Motion: 0.2 s fade to the final frame, hold, 1.0 s); RootView runs the crossfade.
struct IntroView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let duration: Double = 3.0
    static let reduceMotionDuration: Double = 1.0

    // Layout from the notes (pt on the 393×852 canvas)
    private static let iconCenter = CGPoint(x: 196.5, y: 393.3)
    private static let iconSize: CGFloat = 120
    private static let wordBaselineY: CGFloat = 530
    private static let wordLeftX: CGFloat = 196.5 - 87      // left-anchored at the final centred position
    private static let word = "Oahzi"

    // Wave parameters (pt, pt/s) — scaled by the canvas factor at draw time
    private static let speed: Float = 300
    private static let wavelength: Float = 37
    private static let amp0: Float = 11
    private static let shaderEnd: Double = 2.2   // amplitude ≈ 0 by now → stop running the shader

    @State private var start = Date()
    @State private var finished = false
    @State private var reducedShown = false

    var body: some View {
        GeometryReader { geo in
            // Same mapping as the aspect-fill background, so elements stay registered to the art on any screen size.
            let s = max(geo.size.width / 393, geo.size.height / 852)
            let ox = (geo.size.width - 393 * s) / 2, oy = (geo.size.height - 852 * s) / 2
            let c = CGPoint(x: ox + Self.iconCenter.x * s, y: oy + Self.iconCenter.y * s)

            Group {
                if reduceMotion {
                    finalFrame(size: geo.size, s: s, ox: ox, oy: oy, c: c)
                        .opacity(reducedShown ? 1 : 0)
                } else {
                    TimelineView(.animation(minimumInterval: nil, paused: finished)) { ctx in
                        let t = max(0, ctx.date.timeIntervalSince(start))
                        animatedFrame(t: t, size: geo.size, s: s, ox: ox, oy: oy, c: c)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .background(Image("IntroBackground").resizable().scaledToFill().ignoresSafeArea())
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Oahzi")
        .task { await run() }
    }

    // MARK: Frames

    @ViewBuilder
    private func animatedFrame(t: Double, size: CGSize, s: CGFloat, ox: CGFloat, oy: CGFloat, c: CGPoint) -> some View {
        let crisp = Self.smoothstep(1.9, 2.1, t)
        ZStack(alignment: .topLeading) {
            if t < Self.shaderEnd {
                // Background + surfacing icon, refracted together. The wordmark stays outside the effect.
                let tf = Float(t), sf = Float(s)
                let args: [Shader.Argument] = [.float2(c), .float(tf),
                                               .float(Self.speed * sf), .float(Self.wavelength * sf), .float(Self.amp0 * sf)]
                ZStack(alignment: .topLeading) {
                    background(size)
                    iconTile(s: s)
                        .opacity(Self.smoothstep(0.35, 1.35, t))
                        .position(c)
                }
                .frame(width: size.width, height: size.height)
                .ignoresSafeArea()   // effect layer must cover the status-bar/home-indicator areas too
                .compositingGroup()
                .colorEffect(Shader(function: ShaderLibrary.oahziRippleLight, arguments: args))
                .distortionEffect(Shader(function: ShaderLibrary.oahziRipple, arguments: args),
                                  maxSampleOffset: CGSize(width: 48 * s, height: 48 * s))
                .ignoresSafeArea()
            } else {
                background(size)
            }

            // Crisp, undistorted icon cross-fades in over 1.9–2.1 s so the settle is pixel-perfect.
            iconTile(s: s)
                .opacity(crisp)
                .position(c)

            typingWordmark(t: t, s: s, ox: ox, oy: oy)
        }
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
    }

    private func finalFrame(size: CGSize, s: CGFloat, ox: CGFloat, oy: CGFloat, c: CGPoint) -> some View {
        ZStack(alignment: .topLeading) {
            background(size)
            iconTile(s: s).position(c)
            wordmark(letters: Self.word.count, cursor: false, s: s, ox: ox, oy: oy)
        }
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
    }

    // MARK: Pieces

    private func background(_ size: CGSize) -> some View {
        Image("IntroBackground").resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
    }

    /// Icon tile: 120 pt, radius 27 pt continuous, shadow #8A1035 25%, y+10 (per the 3b art).
    private func iconTile(s: CGFloat) -> some View {
        Image("OahziIntroMark").resizable().scaledToFit()
            .frame(width: Self.iconSize * s, height: Self.iconSize * s)
            .clipShape(RoundedRectangle(cornerRadius: 27 * s, style: .continuous))
            .shadow(color: Color(red: 0x8A / 255, green: 0x10 / 255, blue: 0x35 / 255).opacity(0.25), radius: 6 * s, y: 10 * s)
    }

    /// "Oahzi" types in from 1.75 s at 150 ms per letter; cursor visible 1.6–2.9 s, blinking at 2 Hz after 2.5 s.
    private func typingWordmark(t: Double, s: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        let n = t >= 1.75 ? min(Self.word.count, Int((t - 1.75) / 0.15) + 1) : 0
        let cursorOn = t > 1.6 && t < 2.9 && (t < 2.5 || Int(t * 4) % 2 == 0)
        return wordmark(letters: n, cursor: cursorOn, s: s, ox: ox, oy: oy)
    }

    private func wordmark(letters: Int, cursor: Bool, s: CGFloat, ox: CGFloat, oy: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 2.7 * s) {
            Text(String(Self.word.prefix(letters)))
                .font(.custom("Fredoka-Bold", fixedSize: 64 * s))
                .tracking(1 * s)
                .foregroundStyle(.white)
                .fixedSize()
            RoundedRectangle(cornerRadius: 2.3 * s)
                .fill(.white)
                .frame(width: 4.7 * s, height: 56.7 * s)
                .alignmentGuide(.lastTextBaseline) { $0.height - 6.7 * s }   // dips 6.7 pt below the baseline
                .opacity(cursor ? 1 : 0)
        }
        .alignmentGuide(.leading) { _ in 0 }
        .alignmentGuide(.top) { $0[.lastTextBaseline] }   // pin the baseline to the offset below
        .offset(x: ox + Self.wordLeftX * s, y: oy + Self.wordBaselineY * s)
    }

    // MARK: Timing

    private func run() async {
        if reduceMotion {
            // Notes: Reduce Motion shows the final frame with a 0.2 s cross-fade, no ripples.
            withAnimation(.easeOut(duration: 0.2)) { reducedShown = true }
            try? await Task.sleep(for: .seconds(Self.reduceMotionDuration))
            onFinish()
            return
        }
        start = Date()
        try? await Task.sleep(for: .seconds(Self.duration))
        finished = true   // pause the TimelineView
        onFinish()
    }

    private static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}
