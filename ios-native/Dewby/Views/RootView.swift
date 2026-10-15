import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "house.fill") }
            HistoryView().tabItem { Label("History", systemImage: "calendar") }
            RemindersView().tabItem { Label("Reminders", systemImage: "bell.fill") }
        }
    }
}
