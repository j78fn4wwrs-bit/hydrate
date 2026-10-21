import SwiftUI
import SwiftData
import UIKit

@main
struct OahziApp: App {
    let container: ModelContainer

    init() {
        do { container = try DataStore.makeContainer() } catch { fatalError("SwiftData container failed: \(error)") }
        do { try DataStore.bootstrap(container.mainContext) } catch { assertionFailure("Bootstrap failed: \(error)") }
        Self.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView().tint(Theme.coral)
        }
        .modelContainer(container)
    }

    /// Fredoka nav titles everywhere, scaled for Dynamic Type.
    private static func styleNavigationBars() {
        let ink = UIColor(named: "ink") ?? .label
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        if let big = UIFont(name: "Fredoka-Bold", size: 34) {
            a.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: big), .foregroundColor: ink]
        }
        if let small = UIFont(name: "Fredoka-SemiBold", size: 18) {
            a.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: small), .foregroundColor: ink]
        }
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.largeTitleTextAttributes = a.largeTitleTextAttributes
        scrolled.titleTextAttributes = a.titleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = a
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
    }
}
