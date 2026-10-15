import SwiftUI
import SwiftData

extension Profile {
    func entries(on day: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.sorted { $0.timestamp < $1.timestamp }
    }
    func total(on day: Date) -> Double { entries(on: day).reduce(0) { $0 + $1.amountOz } }
    /// dayKey -> oz
    var dailyTotals: [String: Double] {
        entries.reduce(into: [:]) { $0[HydrateBackupCodec.dayKey(for: $1.timestamp), default: 0] += $1.amountOz }
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
    var quickAmounts: [Double] { self == .oz ? [8, 12, 16] : [150, 250, 500] }
    var defaultLog: Double { self == .oz ? 8 : 250 }
    var sliderRange: ClosedRange<Double> { self == .oz ? 2...40 : 50...1200 }
    var sliderStep: Double { self == .oz ? 2 : 50 }   // handoff: Slider(step 50) for ml
    func formatValue(_ v: Double) -> String { "\(Int(v.rounded())) \(rawValue)" }
}
