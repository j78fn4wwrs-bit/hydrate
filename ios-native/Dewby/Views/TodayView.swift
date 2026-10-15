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

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            Group {
                if typeSize.isAccessibilitySize {
                    // Large Dynamic Type: fall back to scrolling with a fixed-size ring.
                    ScrollView { content(ringMax: 220, flexible: false) }
                        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
                } else {
                    // Default: everything fits above the tab bar; the ring absorbs leftover height.
                    content(ringMax: 300, flexible: true)
                        .safeAreaPadding(.bottom, Theme.Space.s)
                }
            }
            .dewScreen()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }.accessibilityLabel("Settings")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: logCount)
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private func content(ringMax: CGFloat, flexible: Bool) -> some View {
        let unit = settings.unit
        let net = profile.netTotal(on: .now)
        let progress = profile.goalOz > 0 ? net / profile.goalOz : 0
        let streak = HydrationStats.compute(totals: profile.dailyNetTotals, goal: profile.goalOz).streak

        return VStack(spacing: Theme.Space.m) {
            VStack(spacing: Theme.Space.s) {
                WaterRing(progress: progress, sloshTrigger: logCount)
                    .frame(minWidth: 110, maxWidth: ringMax, minHeight: 110, maxHeight: flexible ? .infinity : ringMax)
                    .layoutPriority(-1)
                Text("\(unit.format(oz: net)) of \(unit.format(oz: profile.goalOz))\(net >= profile.goalOz ? " · Goal reached!" : "")")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: flexible ? .infinity : nil)
            .dewCard(padding: Theme.Space.l)
            .overlay(alignment: .topTrailing) {
                if streak > 0 { StreakBadge(days: streak).padding(Theme.Space.m) }
            }
            .layoutPriority(-1)

            DrinkTypePicker(selection: $type).dewCard(padding: Theme.Space.m)

            VStack(spacing: Theme.Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Amount").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(unit.format(oz: amountOz)).font(.fredoka(24, relativeTo: .title2))
                        .foregroundStyle(Theme.ink).monospacedDigit()
                        .contentTransition(.numericText()).animation(.snappy, value: amountOz)
                }
                Slider(value: $amountOz, in: 4...40, step: 4) { Text("Amount") }
                    .tint(Theme.water)
                    .sensoryFeedback(.selection, trigger: amountOz)
                    .accessibilityValue(unit.format(oz: amountOz))
            }
            .dewCard(padding: Theme.Space.m)

            ZStack {
                Button(action: log) {
                    Label("Log \(unit.format(oz: amountOz))", systemImage: type.symbol)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .buttonStyle(LogPillStyle())
                .accessibilityHint("Logs \(type.label)")
                SparkleBurst(trigger: logCount)
            }
            .padding(.bottom, 7)   // room for the pill's 3D shadow
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.s)
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
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            group("Hydrating", DrinkType.hydrating)
            group("Dehydrating", DrinkType.dehydrating)
        }
    }
    private func group(_ title: String, _ types: [DrinkType]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
            OverflowRow {
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
                Image(systemName: t.symbol).font(.title3).foregroundStyle(on ? .white : t.tint).frame(height: 22)
                Text(t.label).font(.caption.weight(.semibold)).foregroundStyle(on ? .white : Theme.ink)
                    .lineLimit(1).fixedSize()
            }
            .frame(minWidth: 64, minHeight: 56)
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

/// Compact streak badge for the ring card (the full StreakCard didn't fit above the tab bar).
struct StreakBadge: View {
    let days: Int
    var body: some View {
        Label("\(days)-day streak", systemImage: "flame.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.inkOnYellow)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.celebrate, in: Capsule())
            .accessibilityLabel("\(days)-day streak. Keep the dew coming!")
    }
}

/// Horizontal row with overflow cues: edge fades (mask, so it works on any card color in light/dark),
/// chevrons while more content exists in that direction, and a thin progress bar. Indicators hidden.
struct OverflowRow<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var g = RowGeometry()
    @Environment(\.layoutDirection) private var dir

    struct RowGeometry: Equatable { var offset: CGFloat = 0; var contentWidth: CGFloat = 0; var visibleWidth: CGFloat = 0 }

    private var overflow: CGFloat { max(0, g.contentWidth - g.visibleWidth) }
    private var canLeft: Bool { g.offset > 2 }
    private var canRight: Bool { g.offset < overflow - 2 }
    private let fade: CGFloat = 28

    var body: some View {
        VStack(spacing: 5) {
            ScrollView(.horizontal) { content }
                .scrollIndicators(.hidden)
                .contentMargins(.trailing, 20, for: .scrollContent)   // last tile clears the fade + chevron
                .onScrollGeometryChange(for: RowGeometry.self) { geo in
                    RowGeometry(offset: geo.contentOffset.x + geo.contentInsets.leading,
                                contentWidth: geo.contentSize.width + geo.contentInsets.leading + geo.contentInsets.trailing,
                                visibleWidth: geo.containerSize.width)
                } action: { _, new in g = new }
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                            .frame(width: canLeft ? fade : 0)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: canRight ? fade : 0)
                    }
                    .animation(.easeOut(duration: 0.2), value: canLeft)
                    .animation(.easeOut(duration: 0.2), value: canRight)
                }
                .overlay(alignment: .leading) { chevron("chevron.left", visible: canLeft) }
                .overlay(alignment: .trailing) { chevron("chevron.right", visible: canRight) }

            if overflow > 0 {
                GeometryReader { bar in
                    let frac = g.contentWidth > 0 ? g.visibleWidth / g.contentWidth : 1
                    let w = max(16, bar.size.width * frac)
                    let x = overflow > 0 ? (bar.size.width - w) * min(max(g.offset / overflow, 0), 1) : 0
                    Capsule().fill(Theme.inkSecondary.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.coral.opacity(0.75)).frame(width: w).offset(x: x)
                        }
                }
                .frame(width: 44, height: 3)
                .accessibilityHidden(true)
            }
        }
    }

    private func chevron(_ name: String, visible: Bool) -> some View {
        Image(systemName: name)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.inkSecondary)
            .frame(width: 18, height: 18)
            .background(.regularMaterial, in: Circle())
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: visible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
