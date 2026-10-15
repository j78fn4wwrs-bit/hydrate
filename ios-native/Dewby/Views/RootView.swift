import SwiftUI

struct RootView: View {
    @State private var showIntro = true

    var body: some View {
        ZStack {
            ActiveProfileReader { p, s, _ in
                Group {
                if s.hasOnboarded {
                    TabView {
                        Tab("Today", systemImage: "house.fill") { TodayView() }
                        Tab("History", systemImage: "calendar") { HistoryView() }
                        Tab("Reminders", systemImage: "bell.fill") { RemindersView() }
                    }
                    .transition(.opacity)
                } else {
                    OnboardingView(profile: p, settings: s).transition(.opacity)
                }
                }
                .animation(.easeInOut(duration: 0.4), value: s.hasOnboarded)
            }
            .animation(.easeInOut(duration: 0.35), value: showIntro)

            if showIntro {
                IntroView { withAnimation(.easeInOut(duration: 0.45)) { showIntro = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}
