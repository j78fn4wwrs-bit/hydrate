import SwiftUI

struct HistoryView: View {
    var body: some View {
        ActiveProfileReader { p, s, _ in HistoryContent(profile: p, unit: s.unit) }
    }
}

private struct HistoryContent: View {
    @Environment(\.modelContext) private var ctx
    let profile: Profile
    let unit: VolumeUnit
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Date.now
    private let cal = Calendar.current

    var body: some View {
        let totals = profile.dailyNetTotals
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    dayCard
                    calendarCard(totals)
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.xxxl)
            }
            .dewScreen()
            .contentMargins(.bottom, Theme.Space.xxxl, for: .scrollContent)
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
                Text("net \(unit.format(oz: profile.netTotal(on: selectedDay)))").font(.headline).foregroundStyle(.secondary)
            }
            if entries.isEmpty {
                Text("No drinks logged.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(entries.reversed()) { e in
                    EntryRow(entry: e, unit: unit)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { ctx.delete(e); try? ctx.save() }
                        }
                }
                Text("Long-press a drink to delete it. Amounts shown are what you drank; the total is net hydration.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .dewCard()
    }

}
