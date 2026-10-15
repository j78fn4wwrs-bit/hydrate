import SwiftUI

/// M1 placeholder. M2: Swift Charts BarMark + day list.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("History coming soon", systemImage: "calendar", description: Text("Charts and past days arrive in M2."))
                .navigationTitle("History")
        }
    }
}
