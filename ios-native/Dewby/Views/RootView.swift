import SwiftUI

struct RootView: View {
    @State private var showIntro = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ActiveProfileReader { p, s, _ in
                Group {
                    if s.hasOnboarded {
                        TabView {
                            Tab("Today", systemImage: "house.fill") { TodayView() }
                            Tab("History", systemImage: "calendar") { HistoryView() }
                            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis") { TrendsView() }
                            Tab("Reminders", systemImage: "bell.fill") { RemindersView() }
                        }
                        .minimizeTabBarOnScroll()
                        .transition(.opacity)
                    } else {
                        OnboardingView(profile: p, settings: s).transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: s.hasOnboarded)
            }

            if showIntro {
                IntroView {
                    // Notes: 0.3 s easeInOut crossfade, intro scales to 1.04; Reduce Motion: 0.2 s fade, no scale.
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3)) { showIntro = false }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
    }
}

private extension View {
    /// iOS 26+: Liquid Glass tab bar shrinks while scrolling down (History/Trends). No-op on iOS 18–25.
    @ViewBuilder func minimizeTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) { self.tabBarMinimizeBehavior(.onScrollDown) } else { self }
    }
}
