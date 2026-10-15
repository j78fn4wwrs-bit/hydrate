import Foundation

/// Pure stats over per-day totals (oz). Mirrors the web app's rules.
public struct HydrationStats: Equatable, Sendable {
    public var avg7: Double, avg30: Double, streak: Int, bestDayOz: Double, totalOz: Double, daysMet: Int

    /// - totals: dayKey ("YYYY-MM-DD") -> oz. Averages are over the last 7/30 calendar days including today (empty days count as 0).
    /// - streak: consecutive goal-met days ending today; if today isn't met yet, it ends yesterday (web app behavior).
    public static func compute(totals: [String: Double], goal: Double, today: Date = .now, calendar: Calendar = .current) -> HydrationStats {
        func key(_ offset: Int) -> String {
            HydrateBackupCodec.dayKey(for: calendar.date(byAdding: .day, value: -offset, to: today) ?? today, calendar: calendar)
        }
        let avg = { (n: Int) in (0..<n).reduce(0.0) { $0 + (totals[key($1)] ?? 0) } / Double(n) }
        var streak = 0
        var i = (totals[key(0)] ?? 0) >= goal ? 0 : 1
        while (totals[key(i)] ?? 0) >= goal, goal > 0 { streak += 1; i += 1 }
        return HydrationStats(avg7: avg(7), avg30: avg(30), streak: streak,
                              bestDayOz: totals.values.max() ?? 0, totalOz: totals.values.reduce(0, +),
                              daysMet: goal > 0 ? totals.values.filter { $0 >= goal }.count : 0)
    }
}
