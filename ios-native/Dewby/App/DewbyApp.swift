import SwiftUI
import SwiftData

@main
struct DewbyApp: App {
    let container: ModelContainer = {
        do { return try DataStore.makeContainer() } catch { fatalError("SwiftData container failed: \(error)") }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color("brandCoral"))
                .task { try? DataStore.bootstrap(container.mainContext) }
        }
        .modelContainer(container)
    }
}

extension Font {
    /// Fredoka (bundled variable font, OFL). Falls back to the system font automatically if missing.
    static func fredoka(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fredoka", size: size, relativeTo: style).weight(.bold)
    }
}
