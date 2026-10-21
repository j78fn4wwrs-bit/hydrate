import AVFoundation
import UIKit
import UserNotifications

/// In-app preview of reminder tones + haptics, and the notification sound to use when scheduling (M3).
@MainActor
final class TonePlayer {
    static let shared = TonePlayer()
    private var player: AVAudioPlayer?

    func preview(_ tone: ReminderTone, style: AlertStyle) {
        player?.stop()
        switch style {
        case .silent: return
        case .haptic:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .sound:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard let url = Bundle.main.url(forResource: tone.rawValue, withExtension: ReminderTone.fileExtension) else {
                assertionFailure("Missing sound \(tone.fileName)"); return
            }
            try? AVAudioSession.sharedInstance().setCategory(.ambient)   // respects the ring/silent switch, mixes with music
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
    }

    /// iOS has no "vibrate-only" notification API: .haptic uses the default sound (which vibrates per system settings).
    /// Whether any notification vibrates is controlled by the user's Settings > Sounds & Haptics, not the app.
    static func notificationSound(tone: ReminderTone, style: AlertStyle) -> UNNotificationSound? {
        switch style {
        case .sound: UNNotificationSound(named: UNNotificationSoundName(tone.fileName))
        case .haptic: nil   // M3: decide between silent banner vs default; see README
        case .silent: nil
        }
    }
}
