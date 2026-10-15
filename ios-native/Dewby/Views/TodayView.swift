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
    @State private var confirmation: String?

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
            .overlay(alignment: .bottom) {
                if let confirmation {
                    Text(confirmation)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, Theme.Space.m).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(Theme.Space.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
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
                .accessibilityHint(unit.describe(rawOz: amountOz, typeLabel: type.label, netOz: type.netOz(amountOz)))
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
        let msg = settings.unit.describe(rawOz: amountOz, typeLabel: type.label, netOz: type.netOz(amountOz))
        withAnimation(.snappy) { confirmation = msg }
        Task { try? await Task.sleep(for: .seconds(2.2)); if confirmation == msg { withAnimation(.easeOut) { confirmation = nil } } }
    }
}

/// Two labeled groups of SF Symbol tiles; horizontal scroll so labels never wrap.
struct DrinkTypePicker: View {
    @Binding var selection: DrinkType
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            group("Hydrates", DrinkType.hydrating, accent: nil)
            group("Dehydrates", DrinkType.dehydrates, accent: Theme.coral)
        }
    }
    private func group(_ title: String, _ types: [DrinkType], accent: Color?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(accent ?? .secondary).accessibilityAddTraits(.isHeader)
            OverflowRow(items: types, name: title.lowercased()) { t in tile(t, accent: accent) }
        }
    }
    private func tile(_ t: DrinkType, accent: Color?) -> some View {
        let on = selection == t
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { selection = t } label: {
            VStack(spacing: 4) {
                Image(systemName: t.symbol).font(.title3).foregroundStyle(on ? .white : t.tint).frame(height: 22)
                Text(t.label).font(.caption.weight(.semibold)).foregroundStyle(on ? .white : Theme.ink)
                    .lineLimit(1).fixedSize()
                if t.hydrationFactor != 1 {   // show reduced/negative effect right on the tile
                    Text(LearnPercent.label(t.hydrationFactor))
                        .font(.caption2.weight(.bold)).monospacedDigit()
                        .foregroundStyle(on ? .white : (t.hydrationFactor < 0 ? Theme.coral : Theme.inkSecondary))
                }
            }
            .frame(minWidth: 64, minHeight: 56)
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, 2)
            .background(on ? AnyShapeStyle(Theme.logGradient)
                           : AnyShapeStyle(accent.map { $0.opacity(0.12) } ?? Theme.background), in: shape)
            .overlay(shape.strokeBorder(on ? .clear : (accent ?? .clear).opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(t.hydrationFactor == 1 ? t.label : "\(t.label), counts \(LearnPercent.label(t.hydrationFactor))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct EntryRow: View {
    let entry: DrinkEntry
    let unit: VolumeUnit
    var body: some View {
        HStack {
            Image(systemName: entry.type.symbol).foregroundStyle(entry.type.tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(unit.format(oz: entry.amountOz)) \(entry.type.label)").foregroundStyle(Theme.ink)
                Text("\(unit.formatSigned(oz: entry.netOz)) hydration")
                    .font(.caption).foregroundStyle(entry.netOz < 0 ? Theme.coral : .secondary).monospacedDigit()
            }
            Spacer()
            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
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
/// tappable chevrons (page by ~3 tiles), tile-by-tile snapping, and a thin progress bar. Indicators hidden.
struct OverflowRow<Item: Hashable, Tile: View>: View {
    let items: [Item]
    let name: String                       // "hydrating" → "Scroll hydrating drinks right"
    @ViewBuilder var tile: (Item) -> Tile

    @State private var g = RowGeometry()
    @State private var position: Item?     // leading-most snapped tile
    @State private var tapCount = 0

    struct RowGeometry: Equatable { var offset: CGFloat = 0; var contentWidth: CGFloat = 0; var visibleWidth: CGFloat = 0 }

    private let pageStep = 3
    private var overflow: CGFloat { max(0, g.contentWidth - g.visibleWidth) }
    private var canLeft: Bool { g.offset > 2 }
    private var canRight: Bool { g.offset < overflow - 2 }
    private let fade: CGFloat = 28

    var body: some View {
        VStack(spacing: 5) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(items, id: \.self) { tile($0) }
                }
                .scrollTargetLayout()
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .leading)
            .contentMargins(.trailing, 20, for: .scrollContent)
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
            .overlay(alignment: .leading) { chevron(left: true, visible: canLeft) }
            .overlay(alignment: .trailing) { chevron(left: false, visible: canRight) }
            .sensoryFeedback(.impact(weight: .light), trigger: tapCount)

            if overflow > 0 {
                GeometryReader { bar in
                    let frac = g.contentWidth > 0 ? g.visibleWidth / g.contentWidth : 1
                    let w = max(16, bar.size.width * frac)
                    let x = (bar.size.width - w) * min(max(g.offset / overflow, 0), 1)
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

    private func page(_ delta: Int) {
        guard !items.isEmpty else { return }
        let current = position.flatMap { items.firstIndex(of: $0) } ?? 0
        let target = min(max(current + delta, 0), items.count - 1)
        tapCount += 1
        withAnimation(.snappy(duration: 0.35)) { position = items[target] }
    }

    private func chevron(left: Bool, visible: Bool) -> some View {
        Button { page(left ? -pageStep : pageStep) } label: {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 22, height: 22)
                .background(.regularMaterial, in: Circle())
                .frame(width: 44, height: 44)           // ≥44 pt hit target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: visible)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
        .accessibilityLabel("Scroll \(name) drinks \(left ? "left" : "right")")
    }
}
