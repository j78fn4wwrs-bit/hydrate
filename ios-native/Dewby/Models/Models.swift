import Foundation
import SwiftData

@Model
final class Profile {
    /// Stable id; matches the web app's list keys ("p1", "p<ms>") so re-imports merge.
    @Attribute(.unique) var profileId: String
    var name: String
    var goalOz: Double
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \DrinkEntry.profile) var entries: [DrinkEntry] = []

    init(profileId: String = "p\(Int(Date().timeIntervalSince1970 * 1000))", name: String, goalOz: Double = 108, createdAt: Date = .now) {
        self.profileId = profileId; self.name = name; self.goalOz = goalOz; self.createdAt = createdAt
    }
}

@Model
final class DrinkEntry {
    var amountOz: Double
    var timestamp: Date
    var typeRaw: String
    /// Original web time label, kept so export round-trips byte-for-byte when untouched.
    var timeLabel: String?
    var profile: Profile?

    var type: DrinkType {
        get { DrinkType(rawValue: typeRaw) ?? .water }
        set { typeRaw = newValue.rawValue }
    }

    init(amountOz: Double, timestamp: Date = .now, type: DrinkType = .water, timeLabel: String? = nil, profile: Profile? = nil) {
        self.amountOz = amountOz; self.timestamp = timestamp; self.typeRaw = type.rawValue
        self.timeLabel = timeLabel; self.profile = profile
    }
}

/// Singleton settings row.
@Model
final class AppSettings {
    var unitRaw: String = VolumeUnit.oz.rawValue
    var activeProfileId: String?
    var remindersEnabled: Bool = false          // saved only; scheduling is M3
    var reminderIntervalMinutes: Int = 120
    var reminderStartMinutes: Int = 9 * 60      // 9:00
    var reminderEndMinutes: Int = 19 * 60       // 19:00
    var alertStyleRaw: String = AlertStyle.sound.rawValue
    var toneRaw: String = ReminderTone.default.rawValue

    var unit: VolumeUnit { get { VolumeUnit(rawValue: unitRaw) ?? .oz } set { unitRaw = newValue.rawValue } }
    var alertStyle: AlertStyle { get { AlertStyle(rawValue: alertStyleRaw) ?? .sound } set { alertStyleRaw = newValue.rawValue } }
    var tone: ReminderTone { get { ReminderTone(rawValue: toneRaw) ?? .default } set { toneRaw = newValue.rawValue } }

    init() {}
}
