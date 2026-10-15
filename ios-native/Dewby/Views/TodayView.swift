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
    @State private var amountOz: Double = 8          // slider always steps in oz (4…40 by 4)
    @State private var type: DrinkType = .water
    @State private var showSettings = false

    var body: some View {
        let unit = settings.unit
        let net = profile.netTotal(on: .now)
        let progress = profile.goalOz > 0 ? net / profile.goalOz : 0
        let streak = HydrationStats.compute(totals: profile.dailyNetTotals, goal: profile.goalOz).streak

        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    VStack(spacing: Theme.Space.l) {
                        WaterRing(progress: progress, sloshTrigger: logCount).frame(maxWidth: 240)
                        Text("\(unit.format(oz: net)) of \(unit.format(oz: profile.goalOz))")
                            .font(.body).foregroundStyle(.secondary)
                        if net >= profile.goalOz {
                            Label("Goal reached!", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .dewCard(padding: Theme.Space.xxl)

                    DrinkTypePicker(selection: $type).dewCard(padding: Theme.Space.l)

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Amount").font(.headline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(unit.format(oz: amountOz)).font(.fredoka(28, relativeTo: .title))
                                .foregroundStyle(Theme.ink).monospacedDigit()
                                .contentTransition(.numericText()).animation(.snappy, value: amountOz)
                        }
                        Slider(value: $amountOz, in: 4...40, step: 4) { Text("Amount") }
                            minimumValueLabel: { Text(unit.format(oz: 4)).font(.caption).foregroundStyle(.secondary) }
                            maximumValueLabel: { Text(unit.format(oz: 40)).font(.caption).foregroundStyle(.secondary) }
                            .tint(Theme.water)
                            .sensoryFeedback(.selection, trigger: amountOz)
                            .accessibilityValue(unit.format(oz: amountOz))
                    }
                    .dewCard()

                    ZStack {
                        Button(action: log) {
                            Label("Log \(unit.format(oz: amountOz))", systemImage: type.symbol)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .buttonStyle(LogPillStyle())
                        .accessibilityHint("Logs \(type.label)")
                        SparkleBurst(trigger: logCount)
                    }

                    if streak > 0 { StreakCard(days: streak) }
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .contentMargins(.bottom, Theme.Space.xxxl, for: .scrollContent)   // keeps content clear of the tab bar
            .dewScreen()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }.accessibilityLabel("Settings")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: logCount)
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private func log() {
        let now = Date.now
        ctx.insert(DrinkEntry(amountOz: amountOz, timestamp: now, type: type, timeLabel: HydrateBackupCodec.timeLabel(for: now), profile: profile))
        try? ctx.save()
        logCount += 1
    }
}

/// Two labeled groups of SF Symbol tiles; horizontal scroll so labels never wrap.
struct DrinkTypePicker: View {
    @Binding var selection: DrinkType
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            group("Hydrating", DrinkType.hydrating)
            group("Dehydrating", DrinkType.dehydrating)
        }
    }
    private func group(_ title: String, _ types: [DrinkType]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(types, id: \.self) { t in tile(t) }
                }
                .padding(.vertical, 3)
            }
        }
    }
    private func tile(_ t: DrinkType) -> some View {
        let on = selection == t
        return Button { selection = t } label: {
            VStack(spacing: 6) {
                Image(systemName: t.symbol).font(.title2).foregroundStyle(on ? .white : t.tint).frame(height: 28)
                Text(t.label).font(.caption.weight(.semibold)).foregroundStyle(on ? .white : Theme.ink)
                    .lineLimit(1).fixedSize()
            }
            .frame(minWidth: 72, minHeight: 72)
            .padding(.horizontal, Theme.Space.s)
            .background(on ? AnyShapeStyle(Theme.logGradient) : AnyShapeStyle(Theme.background),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(t.label)
        .accessibilityAddTraits(on ? .isSelected : [])
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
