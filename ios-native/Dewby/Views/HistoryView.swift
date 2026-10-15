import SwiftUI
import Charts

struct HistoryView: View {
    var body: some View {
        ActiveProfileReader { p, s, _ in HistoryContent(profile: p, unit: s.unit) }
    }
}

private struct HistoryContent: View {
    let profile: Profile
    let unit: VolumeUnit
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Date.now
    private let cal = Calendar.current

    var body: some View {
        let totals = profile.dailyTotals
        let stats = HydrationStats.compute(totals: totals, goal: profile.goalOz)
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    calendarCard(totals)
                    dayCard
                    chartCard
                    statsCard(stats)
                    mixCard
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.xxxl)
            }
            .dewScreen()
            .navigationTitle("History")
        }
    }

    // MARK: Calendar month grid
    private func calendarCard(_ totals: [String: Double]) -> some View {
        let days = monthDays()
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return VStack(spacing: Theme.Space.m) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.dewCardTitle).foregroundStyle(Theme.ink)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
                    .disabled(cal.isDate(month, equalTo: .now, toGranularity: .month))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { Text($0.element).font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day, oz: totals[HydrateBackupCodec.dayKey(for: day)] ?? 0) } else { Color.clear.frame(height: 40) }
                }
            }
            Text("Darker = closer to goal. ✓ = goal met.").font(.caption).foregroundStyle(.secondary)
        }
        .dewCard()
    }

    private func dayCell(_ day: Date, oz: Double) -> some View {
        let r = profile.goalOz > 0 ? min(oz / profile.goalOz, 1) : 0
        let met = oz >= profile.goalOz && oz > 0
        let selected = cal.isDate(day, inSameDayAs: selectedDay)
        return Button { selectedDay = day } label: {
            VStack(spacing: 0) {
                Text("\(cal.component(.day, from: day))").font(.subheadline.weight(.semibold))
                if met { Image(systemName: "checkmark").font(.caption2.weight(.heavy)) }
            }
            .foregroundStyle(r > 0.6 ? .white : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Theme.water.opacity(oz > 0 ? 0.15 + r * 0.85 : 0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? Theme.coral : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(day > .now)
        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(unit.format(oz: oz))\(met ? ", goal met" : "")")
    }

    private func monthDays() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private func shiftMonth(_ d: Int) {
        if let m = cal.date(byAdding: .month, value: d, to: month) { month = m }
    }

    // MARK: Selected day entries
    private var dayCard: some View {
        let entries = profile.entries(on: selectedDay)
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Text(cal.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(date: .abbreviated, time: .omitted))
                    .font(.dewCardTitle).foregroundStyle(Theme.ink)
                Spacer()
                Text(unit.format(oz: entries.reduce(0) { $0 + $1.amountOz })).font(.headline).foregroundStyle(.secondary)
            }
            if entries.isEmpty {
                Text("No drinks logged.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(entries) { EntryRow(entry: $0, unit: unit) }
            }
        }
        .dewCard()
    }

    // MARK: 30-day chart stacked by drink
    private struct Bar: Identifiable { let id = UUID(); let day: Date; let type: DrinkType; let value: Double }

    private var chartCard: some View {
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -29, to: .now) ?? .now)
        var sums: [Date: [DrinkType: Double]] = [:]
        for e in profile.entries where e.timestamp >= start {
            sums[cal.startOfDay(for: e.timestamp), default: [:]][e.type, default: 0] += e.amountOz
        }
        let bars = sums.flatMap { day, m in m.map { Bar(day: day, type: $0.key, value: unit.fromOz($0.value)) } }
        let avg = (0..<30).reduce(0.0) { acc, i in
            acc + (sums[cal.startOfDay(for: cal.date(byAdding: .day, value: -i, to: .now)!)]?.values.reduce(0, +) ?? 0)
        } / 30
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Last 30 days · avg \(unit.format(oz: avg))").font(.subheadline).foregroundStyle(.secondary)
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
