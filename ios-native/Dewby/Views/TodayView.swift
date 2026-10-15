import SwiftUI
import SwiftData

struct TodayView: View {
    var body: some View {
        ActiveProfileReader { p, s, _ in TodayContent(profile: p, settings: s) }
    }
}

private struct TodayContent: View {
    @Environment(\.modelContext) private var ctx
    let profile: Profile
    let settings: AppSettings
    @State private var logCount = 0
    @State private var showLogSheet = false
    @State private var showSettings = false

    var body: some View {
        let unit = settings.unit
        let todays = profile.entries(on: .now)
        let total = todays.reduce(0) { $0 + $1.amountOz }
        let progress = profile.goalOz > 0 ? total / profile.goalOz : 0
        let streak = HydrationStats.compute(totals: profile.dailyTotals, goal: profile.goalOz).streak

        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    VStack(spacing: Theme.Space.l) {
                        WaterRing(progress: progress, sloshTrigger: logCount)
                            .frame(maxWidth: 260)
                        Text("\(unit.format(oz: total)) of \(unit.format(oz: profile.goalOz))")
                            .font(.body).foregroundStyle(.secondary)
                        if total >= profile.goalOz {
                            Label("Goal reached!", systemImage: "checkmark.seal.fill")
                                .font(.headline).foregroundStyle(Theme.ink)
                        } else {
                            Text("\(unit.format(oz: profile.goalOz - total)) to go").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .dewCard(padding: Theme.Space.xxl)

                    ZStack {
                        Button { log(unit.toOz(unit.defaultLog), .water) } label: {
                            Label("Log \(unit.formatValue(unit.defaultLog))", systemImage: "plus")
                        }
                        .buttonStyle(LogPillStyle())
                        .accessibilityHint("Logs water")
                        SparkleBurst(trigger: logCount)
                    }

                    HStack(spacing: Theme.Space.m) {
                        ForEach(unit.quickAmounts, id: \.self) { v in
                            Button(unit.formatValue(v)) { log(unit.toOz(v), .water) }.buttonStyle(ChipStyle())
                        }
                        Button { showLogSheet = true } label: { Label("More", systemImage: "cup.and.saucer.fill") }
                            .buttonStyle(ChipStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .dewCard(padding: Theme.Space.l)

                    if streak > 0 { StreakCard(days: streak) }

                    entriesCard(todays, unit: unit)
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.xxxl)
            }
            .dewScreen()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityLabel("Settings")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: logCount)
            .sheet(isPresented: $showLogSheet) {
                LogDrinkSheet(unit: unit) { oz, type in log(oz, type) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    @ViewBuilder private func entriesCard(_ todays: [DrinkEntry], unit: VolumeUnit) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Today's drinks").font(.dewCardTitle).foregroundStyle(Theme.ink)
            if todays.isEmpty {
                Text("Nothing logged yet. Tap the big button!").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(todays.reversed()) { e in
                    EntryRow(entry: e, unit: unit)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { ctx.delete(e); try? ctx.save() }
                        }
                    if e.id != todays.first?.id { Divider() }
                }
            }
        }
        .dewCard()
    }

    private func log(_ oz: Double, _ type: DrinkType) {
        guard oz > 0 else { return }
        let now = Date.now
        ctx.insert(DrinkEntry(amountOz: oz, timestamp: now, type: type, timeLabel: HydrateBackupCodec.timeLabel(for: now), profile: profile))
        try? ctx.save()
        logCount += 1
    }
}

struct EntryRow: View {
    let entry: DrinkEntry
    let unit: VolumeUnit
    var body: some View {
        HStack {
            Image(systemName: entry.type.symbol).foregroundStyle(entry.type.tint).frame(width: 28)
            Text(entry.type.label).foregroundStyle(Theme.ink)
            Spacer()
            Text("\(unit.format(oz: entry.amountOz)) · \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

struct StreakCard: View {
    let days: Int
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "flame.fill").font(.title2).foregroundStyle(Theme.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(days)-day streak").font(.fredoka(20, relativeTo: .title3)).foregroundStyle(Theme.inkOnYellow)
                Text("Keep the dew coming!").font(.subheadline).foregroundStyle(Theme.inkOnYellow)
            }
            Spacer()
        }
        .padding(Theme.Space.xl)
        .background(Theme.celebrate, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.08), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
    }
}

