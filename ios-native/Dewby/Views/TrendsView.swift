import SwiftUI
import Charts

struct TrendsView: View {
    var body: some View {
        ActiveProfileReader { p, s, _ in TrendsContent(profile: p, unit: s.unit) }
    }
}

private struct TrendsContent: View {
    let profile: Profile
    let unit: VolumeUnit
    private let cal = Calendar.current

    var body: some View {
        let stats = HydrationStats.compute(totals: profile.dailyNetTotals, goal: profile.goalOz)
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    statsCard(stats)
                    chartCard
                    balanceCard
                    mixCard
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .contentMargins(.bottom, Theme.Space.xxxl, for: .scrollContent)
            .dewScreen()
            .navigationTitle("Trends")
        }
    }

    // MARK: Hydrating vs dehydrating (last 30 days, raw amounts + net effect)
    private var balanceCard: some View {
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -29, to: .now) ?? .now)
        let recent = profile.entries.filter { $0.timestamp >= start }
        let hyd = recent.filter { $0.type.isHydrating }.reduce(0) { $0 + $1.amountOz }
        let deh = recent.filter { !$0.type.isHydrating }.reduce(0) { $0 + $1.amountOz }
        let penalty = recent.filter { !$0.type.isHydrating }.reduce(0) { $0 + $1.netOz }   // negative
        let sum = max(hyd + deh, 1)
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Hydrating vs. dehydrating").font(.dewCardTitle).foregroundStyle(Theme.ink)
            Text("Last 30 days").font(.caption).foregroundStyle(.secondary)
            GeometryReader { g in
                HStack(spacing: 3) {
                    Capsule().fill(Theme.water).frame(width: max(hyd > 0 ? 8 : 0, (g.size.width - 3) * hyd / sum))
                    Capsule().fill(Theme.coral).frame(width: max(deh > 0 ? 8 : 0, (g.size.width - 3) * deh / sum))
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)
            HStack(alignment: .top) {
                balanceStat("Hydrating", unit.format(oz: hyd), "drop.fill", Theme.water)
                Spacer()
                balanceStat("Dehydrating", unit.format(oz: deh), "cup.and.saucer.fill", Theme.coral)
            }
            Text("Dehydrating drinks took \(unit.format(oz: -penalty)) off your net hydration (estimated; factors are placeholders).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .dewCard()
    }

    private func balanceStat(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            Text(value).font(.fredoka(24, relativeTo: .title2)).foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 30-day chart stacked by drink
    private struct Bar: Identifiable { let id = UUID(); let day: Date; let type: DrinkType; let value: Double }

    private var chartCard: some View {
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -29, to: .now) ?? .now)
        var sums: [Date: [DrinkType: Double]] = [:]
        for e in profile.entries where e.timestamp >= start {
            sums[cal.startOfDay(for: e.timestamp), default: [:]][e.type, default: 0] += e.netOz   // net: dehydrating stacks below 0
        }
        let bars = sums.flatMap { day, m in m.map { Bar(day: day, type: $0.key, value: unit.fromOz($0.value)) } }
        let avg = (0..<30).reduce(0.0) { acc, i in
            acc + (sums[cal.startOfDay(for: cal.date(byAdding: .day, value: -i, to: .now)!)].map { max(0, $0.values.reduce(0, +)) } ?? 0)
        } / 30
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Net hydration, last 30 days · avg \(unit.format(oz: avg))").font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(bars) { b in
                    BarMark(x: .value("Day", b.day, unit: .day), y: .value(unit.rawValue, b.value))
                        .foregroundStyle(by: .value("Drink", b.type.label))
                        .cornerRadius(3)
                }
                RuleMark(y: .value("Goal", unit.fromOz(profile.goalOz)))
                    .foregroundStyle(Theme.coral).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) { Text("Goal").font(.caption2).foregroundStyle(Theme.coral) }
            }
            .chartForegroundStyleScale(domain: DrinkType.allCases.map(\.label), range: DrinkType.allCases.map(\.tint))
            .chartXScale(domain: start...(cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now))
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .chartLegend(position: .bottom, spacing: Theme.Space.s)
            .frame(height: 220)
        }
        .dewCard()
    }

    // MARK: Stats
    private func statsCard(_ s: HydrationStats) -> some View {
        let items: [(String, String)] = [
            ("7-day avg", unit.format(oz: s.avg7)), ("30-day avg", unit.format(oz: s.avg30)),
            ("Streak", "\(s.streak) day\(s.streak == 1 ? "" : "s")"), ("Best day", unit.format(oz: s.bestDayOz)),
            ("Goals met", "\(s.daysMet)"), ("All-time", unit.format(oz: s.totalOz)),
        ]
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Stats").font(.dewCardTitle).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Space.m)], spacing: Theme.Space.m) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.1).font(.fredoka(24, relativeTo: .title2)).foregroundStyle(Theme.ink).minimumScaleFactor(0.6).lineLimit(1)
                        Text(item.0).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.m)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .dewCard()
    }

    // MARK: Drink mix (all-time)
    private var mixCard: some View {
        var by: [DrinkType: Double] = [:]
        for e in profile.entries { by[e.type, default: 0] += e.amountOz }
        let total = max(by.values.reduce(0, +), 1)
        let rows = by.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Drink mix").font(.dewCardTitle).foregroundStyle(Theme.ink)
            if rows.isEmpty { Text("Log a few drinks to see your mix.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(rows, id: \.key) { t, v in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(t.label, systemImage: t.symbol).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Int((v / total * 100).rounded()))% · \(unit.format(oz: v))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    GeometryReader { g in
                        Capsule().fill(Theme.background)
                            .overlay(alignment: .leading) { Capsule().fill(t.tint).frame(width: g.size.width * v / total) }
                    }.frame(height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .dewCard()
    }
}
