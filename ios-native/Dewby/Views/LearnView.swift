import SwiftUI

/// Learn tab: how the ring works, the factor table (generated from DrinkType.hydrationFactor so it never drifts), why, and sources.
struct LearnView: View {
    var body: some View {
        ActiveProfileReader { _, s, _ in LearnContent(unit: s.unit) }
    }
}

private struct LearnContent: View {
    let unit: VolumeUnit
    private let exampleOz: Double = 12

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    ringCard
                    factorCard("Hydrating", DrinkType.hydrating, symbol: "drop.fill", tint: Theme.water)
                    factorCard("Caffeine & alcohol", DrinkType.caffeineAndAlcohol, symbol: "cup.and.saucer.fill", tint: .brown)
                    whyCard
                    sourcesCard
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .contentMargins(.bottom, Theme.Space.xxxl, for: .scrollContent)
            .dewScreen()
            .navigationTitle("Learn")
        }
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Label("How the ring works", systemImage: "circle.dashed.inset.filled")
                .font(.dewCardTitle).foregroundStyle(Theme.ink)
            Text("Not every sip counts the same. Each drink you log is multiplied by its hydration factor:")
                .font(.body).foregroundStyle(.secondary)
            Text("logged \(unit.rawValue) × factor = hydration \(unit.rawValue)")
                .font(.fredoka(20, relativeTo: .title3)).foregroundStyle(Theme.ink)
                .padding(Theme.Space.m).frame(maxWidth: .infinity)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            bullet("plus.circle.fill", Theme.water, "Hydrating drinks add to your day.")
            bullet("minus.circle.fill", Theme.coral, "Alcohol subtracts from it. Coffee and tea count like water.")
            bullet("0.circle.fill", Theme.inkSecondary, "Your daily total never drops below 0.")
            bullet("checkmark.seal.fill", Theme.coral, "Streaks, calendar and trends all use this net hydration. Your backups keep the raw amounts.")
        }
        .dewCard()
    }

    private func bullet(_ symbol: String, _ tint: Color, _ text: String) -> some View {
        Label { Text(text).foregroundStyle(Theme.ink) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
            .font(.subheadline)
    }

    private func factorCard(_ title: String, _ types: [DrinkType], symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Label(title, systemImage: symbol).font(.dewCardTitle).foregroundStyle(tint)
            ForEach(types, id: \.self) { t in
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: t.symbol).foregroundStyle(t.tint).font(.title3).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.label).font(.headline).foregroundStyle(Theme.ink)
                        Text("\(unit.format(oz: exampleOz)) → \(unit.formatSigned(oz: t.netOz(exampleOz)))")
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Text(Self.percent(t.hydrationFactor))
                        .font(.fredoka(20, relativeTo: .title3)).monospacedDigit()
                        .foregroundStyle(t.isHydrating ? Theme.ink : Theme.coral)
                }
                .accessibilityElement(children: .combine)
                if t != types.last { Divider() }
            }
        }
        .dewCard()
    }

    static func percent(_ f: Double) -> String { LearnPercent.label(f) }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Label("Why drinks differ", systemImage: "lightbulb.fill").font(.dewCardTitle).foregroundStyle(Theme.ink)
            why("drop.fill", Theme.water, "Water content", "Water, juice and most drinks are mostly water, so nearly all of it counts.")
            why("cube.fill", Theme.pink, "Sugar & thickness", "Sugary sodas, energy drinks and thick smoothies have less free water and are absorbed differently, so they count a bit less.")
            why("bolt.fill", .brown, "Caffeine", "At moderate intake (about 4 cups of coffee a day or less), coffee, espresso, lattes and tea hydrate about as well as water. Regular drinkers adapt to caffeine's mild diuretic effect, so Dewby counts them fully.")
            why("wineglass.fill", .red, "Alcohol", "Alcohol suppresses the hormone that helps your body hold on to water (a diuretic effect), so it subtracts.")
        }
        .dewCard()
    }

    private func why(_ symbol: String, _ tint: Color, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Label("Sources", systemImage: "book.closed.fill").font(.dewCardTitle).foregroundStyle(Theme.ink)
            Text("Maughan RJ, et al. A randomized trial to assess the potential of different beverages to affect hydration status: development of a beverage hydration index. Am J Clin Nutr. 2016;103(3):717–723.")
                .font(.footnote).foregroundStyle(Theme.ink)
            Text("Killer SC, Blannin AK, Jeukendrup AE. No evidence of dehydration with moderate daily coffee intake: a counterbalanced cross-over study in a free-living population. PLoS ONE. 2014;9(1):e84154.")
                .font(.footnote).foregroundStyle(Theme.ink)
            Label("These factors are simplified estimates to help you build a habit. They are not medical advice. Talk to a doctor about your own fluid needs.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
                .padding(Theme.Space.m)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .dewCard()
    }
}

enum LearnPercent {
    static func label(_ f: Double) -> String {
        let p = (f * 100).rounded()
        return "\(p < 0 ? "−" : "")\(Int(abs(p)))%"
    }
}
