import SwiftUI

struct RootView: View {
    var body: some View {
        ActiveProfileReader { p, s, _ in
            TabView {
                Tab("Today", systemImage: "house.fill") { TodayView() }
                Tab("History", systemImage: "calendar") { HistoryView() }
                Tab("Reminders", systemImage: "bell.fill") { RemindersView() }
            }
            .fullScreenCover(isPresented: .constant(!s.hasOnboarded)) { OnboardingView(profile: p, settings: s) }
        }
    }
}
