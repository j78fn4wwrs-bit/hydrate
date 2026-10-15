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
        switch self { case .water: "Water"; case .coffee: "Coffee"; case .juice: "Juice"; case .smoothie: "Smoothie"; case .soda: "Soda"; case .sports: "Sports drink" }
    }
    /// SF Symbols per handoff (drop.fill, cup.and.saucer.fill, mug.fill, waterbottle.fill, flame.fill...).
    var symbol: String {
        switch self {
        case .water: "drop.fill"; case .coffee: "cup.and.saucer.fill"; case .juice: "takeoutbag.and.cup.and.straw.fill"
        case .smoothie: "mug.fill"; case .soda: "bubbles.and.sparkles.fill"; case .sports: "waterbottle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .water: Theme.water; case .coffee: .brown; case .juice: .orange
        case .smoothie: Theme.pink; case .soda: .purple; case .sports: .green
        }
    }
}
