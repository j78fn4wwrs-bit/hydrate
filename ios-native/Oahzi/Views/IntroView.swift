import SwiftUI
import UIKit

/// Jim's brand intro — follows /dewby-brand/intro/MOTION_NOTES.md exactly.
/// Design canvas 393×852 pt. Frame 0 = IntroBackground only (same image as LaunchScreen.storyboard, aspect-fill), so nothing jumps.
/// Calls `onFinish` at 1.5 s (Reduce Motion: 0.8 s); RootView runs the crossfade (0.3 s / 0.2 s).
struct IntroView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let showTagline = true   // optional per notes; included
    static let ease = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.8)   // easeOutCubic

    @State private var icon = false
    @State private var ripple1 = false
    @State private var ripple2 = false
    @State private var sparkles = [false, false, false, false]
    @State private var word = false
    @State private var tag = false

    // Layout from the notes (pt, top-left origin on the 393×852 canvas)
    private let iconCenter = CGPoint(x: 196.5, y: 393.3)
    private let sparkleSpecs: [(dx: CGFloat, dy: CGFloat, r: CGFloat, sunny: Bool)] = [
        (110, -87, 11, true), (-117, -40, 8, false), (100, 67, 7, false), (-93, 83, 9, true),
    ]

    var body: some View {
        GeometryReader { geo in
            // Same mapping as the aspect-fill background, so elements stay registered to the art on any screen size.
            let s = max(geo.size.width / 393, geo.size.height / 852)
            let ox = (geo.size.width - 393 * s) / 2, oy = (geo.size.height - 852 * s) / 2
            let pt = { (x: CGFloat, y: CGFloat) in CGPoint(x: ox + x * s, y: oy + y * s) }
            let c = pt(iconCenter.x, iconCenter.y)

            ZStack(alignment: .topLeading) {
                Image("IntroBackground").resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()

                // Ripples: radius 74.4 pt at scale 1, 2 pt white stroke; scale 0.9→2.3, opacity 0.55→0
                ForEach(0..<2, id: \.self) { i in
                    let on = i == 0 ? ripple1 : ripple2
                    Circle().stroke(.white, lineWidth: 2 / (on ? 2.3 : 0.9))   // keep the stroke ~2 pt while scaling
                        .frame(width: 148.8 * s, height: 148.8 * s)
                        .scaleEffect(on ? 2.3 : 0.9)
                        .opacity(reduceMotion ? 0 : (on ? 0 : (icon ? 0.55 : 0)))
                        .position(c)
                }

                // Icon tile: 120 pt, radius 27 pt continuous, shadow #8A1035 35%, blur 10, y+8
                Image("OahziIcon").resizable().scaledToFit()
                    .frame(width: 120 * s, height: 120 * s)
                    .clipShape(RoundedRectangle(cornerRadius: 27 * s, style: .continuous))
                    .shadow(color: Color(red: 0x8A / 255, green: 0x10 / 255, blue: 0x35 / 255).opacity(0.35), radius: 10 * s / 2, y: 8 * s)
                    .scaleEffect(reduceMotion ? 1 : (icon ? 1 : 0.4))
                    .opacity(icon ? 1 : 0)
                    .position(c)

                ForEach(sparkleSpecs.indices, id: \.self) { i in
                    let sp = sparkleSpecs[i]
                    SparkleStar().fill(sp.sunny ? Theme.celebrate : .white)
                        .frame(width: sp.r * 2 * s, height: sp.r * 2 * s)
                        .scaleEffect(reduceMotion ? 1 : (sparkles[i] ? 1 : 0))
                        .opacity(sparkles[i] ? 1 : 0)
                        .position(x: c.x + sp.dx * s, y: c.y + sp.dy * s)
                }

                baselineText("Oahzi", font: .custom("Fredoka-Bold", fixedSize: 64 * s), tracking: 1,
                             opacity: 1, baseline: pt(0, 530).y, width: geo.size.width)
                    .opacity(word ? 1 : 0)
                    .offset(y: reduceMotion || word ? 0 : 24 * s)

                if Self.showTagline {
                    baselineText("Make every sip count", font: .custom("Fredoka-Medium", fixedSize: 20 * s), tracking: 0,
                                 opacity: 0.88, baseline: pt(0, 563).y, width: geo.size.width)
                        .opacity(tag ? 1 : 0)
                        .offset(y: reduceMotion || tag ? 0 : 16 * s)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(Self.showTagline ? "Oahzi. Make every sip count" : "Oahzi")
        .task { await run() }
    }

    /// Text whose last baseline sits exactly at `baseline` (pt from top), horizontally centered.
    private func baselineText(_ s: String, font: Font, tracking: CGFloat, opacity: Double, baseline: CGFloat, width: CGFloat) -> some View {
        Color.clear.frame(width: width, height: baseline)
            .overlay(alignment: .bottom) {
                Text(s).font(font).tracking(tracking).foregroundStyle(.white.opacity(opacity))
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
            }
    }

    private func run() async {
        if reduceMotion {
            // Notes: no scale/spring/ripple/offset; fade all in together 250 ms easeOut, hold to 800 ms.
            withAnimation(.easeOut(duration: 0.25)) {
                icon = true; sparkles = [true, true, true, true]; word = true; tag = true
            }
            try? await Task.sleep(for: .milliseconds(800))
            onFinish()
            return
        }
        // 100 ms: icon spring 0.4→1 (overshoot ~1.05 @ ~450 ms). Opacity rides the same spring (reaches ~1 by ~250 ms).
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.10)) { icon = true }
        withAnimation(Self.ease.delay(0.30)) { ripple1 = true }
        withAnimation(Self.ease.delay(0.45)) { ripple2 = true }
        for (i, t) in [0.55, 0.63, 0.71, 0.79].enumerated() {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(t)) { sparkles[i] = true }
        }
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.4).delay(0.65)) { word = true }
        if Self.showTagline {
            withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.4).delay(0.85)) { tag = true }
        }
        try? await Task.sleep(for: .milliseconds(450))
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()   // optional haptic at the overshoot peak
        try? await Task.sleep(for: .milliseconds(1050))             // → 1500 ms
        onFinish()
    }
}

/// 4-point star (sparkle).
struct SparkleStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2, ir = r * 0.32
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rr = i.isMultiple(of: 2) ? r : ir
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}
