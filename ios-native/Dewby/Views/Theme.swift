import SwiftUI

/// Brand tokens from DEV_HANDOFF.md. Namespaced (Theme.*) to avoid clashing with Xcode's generated asset symbols.
enum Theme {
    static let coral = Color("brandCoral")
    static let pink = Color("brandPink")
    static let water = Color("water")
    static let celebrate = Color("celebrate")
    static let ink = Color("ink")
    static let inkSecondary = Color("inkSecondary")
    static let background = Color("background")
    static let card = Color("card")
    /// Yellow streak card keeps dark ink in Dark mode too (white on #FFD23F fails contrast).
    static let inkOnYellow = Color(red: 0x1B / 255, green: 0x22 / 255, blue: 0x38 / 255)
    static let logGradient = LinearGradient(colors: [coral, pink], startPoint: .leading, endPoint: .trailing)

    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 20, xxl: CGFloat = 24, xxxl: CGFloat = 32 }
    static let cardRadius: CGFloat = 28
    static let buttonRadius: CGFloat = 16
}

extension Font {
    /// Fredoka static instances (Bold/SemiBold) generated from the OFL variable font. Scales with Dynamic Type.
    static func fredoka(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle, semibold: Bool = false) -> Font {
        .custom(semibold ? "Fredoka-SemiBold" : "Fredoka-Bold", size: size, relativeTo: style)
    }
    static let dewLargeTitle = fredoka(34, relativeTo: .largeTitle)
    static let dewBigNumber = fredoka(48, relativeTo: .largeTitle)
    static let dewCardTitle = fredoka(20, relativeTo: .title3, semibold: true)
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Space.xl
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.08), radius: 16, y: 6)
    }
}

extension View {
    func dewCard(padding: CGFloat = Theme.Space.xl) -> some View { modifier(CardModifier(padding: padding)) }
    /// Mist background behind scroll/form content. Titles use the Fredoka nav-bar appearance set in DewbyApp.
    func dewScreen() -> some View {
        self.scrollContentBackground(.hidden).background(Theme.background.ignoresSafeArea())
    }
}

extension DrinkType {
    var label: String {
        switch self {
        case .water: "Water"; case .soda: "Soda"; case .juice: "Juice"; case .energy: "Energy drink"
        case .smoothie: "Smoothie"; case .other: "Other"; case .coffee: "Coffee"; case .espresso: "Espresso"; case .latte: "Latte"; case .tea: "Tea"; case .beer: "Beer"; case .wine: "Wine"; case .spirits: "Spirits"
        }
    }
    var symbol: String {
        switch self {
        case .water: "drop.fill"; case .soda: "bubbles.and.sparkles.fill"; case .juice: "takeoutbag.and.cup.and.straw.fill"
        case .energy: "bolt.fill"; case .smoothie: "waterbottle.fill"; case .other: "cup.and.heat.waves.fill"
        case .coffee: "cup.and.saucer.fill"; case .espresso: "cup.and.saucer"; case .latte: "takeoutbag.and.cup.and.straw"; case .tea: "leaf.fill"; case .beer: "mug.fill"; case .wine: "wineglass.fill"; case .spirits: "flame.fill"
        }
    }
    var tint: Color {
        switch self {
        case .water: Theme.water; case .soda: .purple; case .juice: .orange; case .energy: .green
        case .smoothie: Theme.pink; case .other: .teal; case .coffee: .brown; case .espresso: Color(red: 0.36, green: 0.22, blue: 0.13); case .latte: Color(red: 0.78, green: 0.6, blue: 0.42); case .tea: .mint; case .beer: Color(red: 0.85, green: 0.6, blue: 0.1); case .wine: Color(red: 0.55, green: 0.1, blue: 0.25); case .spirits: Theme.coral
        }
    }
}

extension HydrationTier {
    /// Jim's palette: water blue = full, ink-secondary = partial, coral = negative.
    var tint: Color {
        switch self { case .full: Theme.water; case .partial: Theme.inkSecondary; case .negative: Theme.coral }
    }
    var symbol: String {
        switch self { case .full: "drop.fill"; case .partial: "drop.halffull"; case .negative: "minus.circle.fill" }
    }
}
