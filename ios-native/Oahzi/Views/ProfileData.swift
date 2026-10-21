import SwiftUI
import SwiftData

extension Profile {
    func entries(on day: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.sorted { $0.timestamp < $1.timestamp }
    }
    /// Net hydration for a day (alcohol reduces or subtracts), clamped at 0.
    func netTotal(on day: Date) -> Double { max(0, entries(on: day).reduce(0) { $0 + $1.netOz }) }
    /// dayKey -> net oz (clamped at 0). Used by the ring, calendar, streaks and stats.
    var dailyNetTotals: [String: Double] {
        entries.reduce(into: [String: Double]()) { $0[HydrateBackupCodec.dayKey(for: $1.timestamp), default: 0] += $1.netOz }
            .mapValues { max(0, $0) }
    }
}

/// Convenience resolver used by every screen.
struct ActiveProfileReader<Content: View>: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query private var settingsRows: [AppSettings]
    @ViewBuilder var content: (Profile, AppSettings, [Profile]) -> Content

    var body: some View {
        if let s = settingsRows.first, let p = profiles.first(where: { $0.profileId == s.activeProfileId }) ?? profiles.first {
            content(p, s, profiles)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
        }
    }
}

extension VolumeUnit {
    /// Quick-add chip amounts in this unit's display values.
    func formatValue(_ v: Double) -> String { "\(Int(v.rounded())) \(rawValue)" }
}
