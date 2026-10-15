import Foundation

public enum AlertStyle: String, CaseIterable, Codable, Sendable {
    case sound, haptic, silent
    public var label: String {
        switch self { case .sound: "Sound"; case .haptic: "Vibrate only"; case .silent: "Silent" }
    }
}

/// THE tone manifest. Every tone lives in Dewby/Resources/Sounds/<rawValue>.caf.
/// To add a tone: drop dewby_xyz.caf in that folder and add ONE line below: `case xyz = "dewby_xyz"` plus its label.
/// rawValue is persisted in settings; don't rename existing cases' raw values.
public enum ReminderTone: String, CaseIterable, Codable, Sendable {
    case drip    = "dewby_drip"
    case splash  = "dewby_splash"
    case stream  = "dewby_stream"
    case chime   = "dewby_chime"
    case marimba = "dewby_marimba"
    case bells   = "dewby_bells"

    public static let `default`: ReminderTone = .drip
    public static let fileExtension = "caf"
    /// Name for UNNotificationSound(named:) — sounds are copied flat into the app bundle root.
    public var fileName: String { "\(rawValue).\(Self.fileExtension)" }
    public var label: String {
        switch self {
        case .drip: "Water drip"; case .splash: "Splash"; case .stream: "Stream"
        case .chime: "Dew chime"; case .marimba: "Marimba"; case .bells: "Bells"
        }
    }
    public var isWater: Bool { [.drip, .splash, .stream].contains(self) }
}
