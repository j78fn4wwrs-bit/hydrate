import Foundation

/// Pure (Foundation-only) codec for Hydrate web-app backups. No SwiftData here so it is unit-testable.
///
/// Full format:   {"active":"p1","list":{"p1":{"name":"Me","goal":108,"days":{"2026-10-14":[{"oz":8,"type":"water","t":"3:45 PM"}]}}}}
/// Web export:    a single profile object {"name","goal","days","v2"} (what the web Export button writes)
/// Legacy:        {"goal","days"} with no name (pre-profiles localStorage "hydrate")
public enum DrinkType: String, CaseIterable, Codable, Sendable {
    // Hydrating
    case water, soda, juice, energy, smoothie, other
    // Dehydrating
    case coffee, espresso, latte, tea, alcohol

    /// Net hydration multiplier applied to an entry's raw oz (ring, totals, streaks, stats).
    /// Update ONLY this table. Raw amounts are always stored/exported unchanged.
    /// Hydrating values are loosely based on the Beverage Hydration Index (Maughan et al., 2016,
    /// Am J Clin Nutr 103:717–723: fluid retained vs. still water over 4 h), rounded down for sugar/thickness.
    /// Dehydrating values are still ⚠️ PLACEHOLDERS pending research.
    public var hydrationFactor: Double {
        switch self {
        case .water: 1.0
        case .juice: 1.0
        case .soda: 0.9
        case .energy: 0.9
        case .smoothie: 0.85   // thicker, less free water
        case .other: 1.0
        case .coffee: -0.5     // PLACEHOLDER
        case .espresso: -1.5   // PLACEHOLDER (small volume, lots of caffeine)
        case .latte: -0.25     // PLACEHOLDER (mostly milk)
        case .tea: -0.25       // PLACEHOLDER
        case .alcohol: -1.0    // PLACEHOLDER
        }
    }
    public var isHydrating: Bool { hydrationFactor >= 0 }
    public func netOz(_ rawOz: Double) -> Double { rawOz * hydrationFactor }
    public static let hydrating: [DrinkType] = [.water, .soda, .juice, .energy, .smoothie, .other]
    public static let dehydrating: [DrinkType] = [.alcohol, .coffee, .espresso, .latte, .tea]

    /// Accepts legacy raw values: "sports" (web app / M1) → .energy. Unknown/missing → water.
    public static func from(raw: String?) -> DrinkType {
        guard let raw else { return .water }
        if raw == "sports" { return .energy }
        return DrinkType(rawValue: raw) ?? .water
    }
    /// Raw value written to backups. Energy is written as "sports" so the Hydrate web app can still display it.
    /// (espresso/latte/tea/alcohol/other are new; the web app does not know them.)
    public var backupRaw: String { self == .energy ? "sports" : rawValue }
}

public struct BackupEntry: Equatable, Sendable {
    public var oz: Double
    public var type: DrinkType
    /// Original web time label, e.g. "3:45 PM" (may be nil / unparseable).
    public var timeLabel: String?
    public init(oz: Double, type: DrinkType, timeLabel: String?) { self.oz = oz; self.type = type; self.timeLabel = timeLabel }
}

public struct BackupProfile: Equatable, Sendable {
    public var id: String
    public var name: String
    public var goal: Double
    public var days: [String: [BackupEntry]]   // key: "YYYY-MM-DD" (local date)
    public init(id: String, name: String, goal: Double, days: [String: [BackupEntry]]) {
        self.id = id; self.name = name; self.goal = goal; self.days = days
    }
}

public struct HydrateBackup: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case multiProfile, singleProfile, legacy }
    public var kind: Kind
    public var active: String?
    public var profiles: [BackupProfile]   // sorted by id for determinism
    public init(kind: Kind, active: String?, profiles: [BackupProfile]) { self.kind = kind; self.active = active; self.profiles = profiles }
}

public enum BackupError: Error, Equatable {
    case notJSONObject
    case unrecognizedFormat
}

public enum HydrateBackupCodec {
    public static let defaultGoal: Double = 108

    // MARK: Decode
    public static func decode(_ data: Data) throws -> HydrateBackup {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw BackupError.notJSONObject }
        if let list = root["list"] as? [String: Any] {
            let profiles = list.compactMap { (id, v) -> BackupProfile? in
                guard let p = v as? [String: Any] else { return nil }
                return profile(id: id, p, fallbackName: "Me")
            }.sorted { $0.id < $1.id }
            guard !profiles.isEmpty else { throw BackupError.unrecognizedFormat }
            let active = (root["active"] as? String).flatMap { a in profiles.contains { $0.id == a } ? a : nil } ?? profiles.first?.id
            return HydrateBackup(kind: .multiProfile, active: active, profiles: profiles)
        }
        if root["days"] is [String: Any] || root["goal"] != nil {
            let hasName = (root["name"] as? String)?.isEmpty == false
            let p = profile(id: "p1", root, fallbackName: "Me")
            return HydrateBackup(kind: hasName ? .singleProfile : .legacy, active: p.id, profiles: [p])
        }
        throw BackupError.unrecognizedFormat
    }

    static func number(_ v: Any?) -> Double? {
        if let n = v as? NSNumber, !(v is Bool) { return n.doubleValue }
        if let s = v as? String { return Double(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func profile(id: String, _ p: [String: Any], fallbackName: String) -> BackupProfile {
        let name = (p["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
        // Web app: goal missing -> 108; non-v2 profiles were reset to 108 on load. We honor that.
        var goal = number(p["goal"]) ?? defaultGoal
        if p["v2"] == nil || goal <= 0 { goal = defaultGoal }
        var days: [String: [BackupEntry]] = [:]
        for (k, v) in (p["days"] as? [String: Any]) ?? [:] {
            guard isDayKey(k), let arr = v as? [Any] else { continue }
            let entries = arr.compactMap { e -> BackupEntry? in
                guard let e = e as? [String: Any], let oz = number(e["oz"]), oz > 0 else { return nil }
                let type = DrinkType.from(raw: e["type"] as? String)
                return BackupEntry(oz: oz, type: type, timeLabel: e["t"] as? String)
            }
            if !entries.isEmpty { days[k] = entries }
        }
        return BackupProfile(id: id, name: name, goal: goal, days: days)
    }

    static func isDayKey(_ k: String) -> Bool { dayFormatter.date(from: k) != nil && k.count == 10 }

    // MARK: Encode (same shape as the web app; profiles carry v2:1 so the web app keeps the goal)
    public static func encode(_ backup: HydrateBackup) throws -> Data {
        var list: [String: Any] = [:]
        for p in backup.profiles { list[p.id] = profileJSON(p) }
        var root: [String: Any] = ["list": list]
        root["active"] = backup.active ?? backup.profiles.first?.id
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// Single-profile export, identical in shape to the web Export button.
    public static func encodeSingle(_ p: BackupProfile) throws -> Data {
        try JSONSerialization.data(withJSONObject: profileJSON(p), options: [.prettyPrinted, .sortedKeys])
    }

    static func profileJSON(_ p: BackupProfile) -> [String: Any] {
        var days: [String: Any] = [:]
        for (k, es) in p.days {
            days[k] = es.map { e -> [String: Any] in
                var d: [String: Any] = ["oz": jsonNumber(e.oz), "type": e.type.backupRaw]
                if let t = e.timeLabel { d["t"] = t }
                return d
            }
        }
        return ["name": p.name, "goal": jsonNumber(p.goal), "days": days, "v2": 1]
    }

    static func jsonNumber(_ d: Double) -> Any { d == d.rounded() && abs(d) < 1e15 ? Int(d) as Any : d as Any }

    // MARK: Date helpers (local calendar, matching the web app's toLocaleDateString('en-CA'))
    public static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f
    }()
    static let timeFormatters: [DateFormatter] = ["h:mm a", "h:mma", "HH:mm", "H:mm", "h:mm:ss a", "HH:mm:ss"].map {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = $0; return f
    }
    static let labelFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "h:mm a"; return f
    }()

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func timeLabel(for date: Date) -> String { labelFormatter.string(from: date) }

    /// Combine a day key and a web time label into a Date. Unparseable labels (other locales) fall back
    /// to noon + index seconds so ordering within the day is preserved.
    public static func timestamp(dayKey: String, timeLabel: String?, index: Int, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12, minute: 0, second: index)
        if let raw = timeLabel?.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespaces).uppercased() {
            for f in timeFormatters {
                if let t = f.date(from: raw) {
                    let tc = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: t)
                    c.hour = tc.hour; c.minute = tc.minute; c.second = (tc.second ?? 0) == 0 ? min(index, 59) : tc.second
                    break
                }
            }
        }
        return calendar.date(from: c)
    }
}
