import Foundation
import SwiftData

enum DataStore {
    static let schema = Schema([Profile.self, DrinkEntry.self, AppSettings.self])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory))
    }

    /// Ensures a settings row and at least one profile ("Me", 108 oz) exist.
    @MainActor @discardableResult
    static func bootstrap(_ ctx: ModelContext) throws -> AppSettings {
        let settings = try ctx.fetch(FetchDescriptor<AppSettings>()).first ?? { let s = AppSettings(); ctx.insert(s); return s }()
        var profiles = try ctx.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)]))
        if profiles.isEmpty { let p = Profile(profileId: "p1", name: "Me"); ctx.insert(p); profiles = [p] }
        if settings.activeProfileId == nil || !profiles.contains(where: { $0.profileId == settings.activeProfileId }) {
            settings.activeProfileId = profiles.first?.profileId
        }
        try ctx.save()
        return settings
    }
}

/// Bridges the pure codec and SwiftData.
@MainActor
enum BackupService {
    struct ImportResult: Equatable { var profilesAdded = 0, profilesUpdated = 0, entriesAdded = 0, entriesSkipped = 0 }

    /// Merge policy: profiles match by id (multi-profile files) or by name (single/legacy files; else added as new).
    /// Goal/name are taken from the file. Entries that already exist (same day+time+oz+type) are skipped, so re-importing is idempotent.
    @discardableResult
    static func importBackup(_ data: Data, into ctx: ModelContext, calendar: Calendar = .current) throws -> ImportResult {
        let backup = try HydrateBackupCodec.decode(data)
        let settings = try DataStore.bootstrap(ctx)
        var existing = try ctx.fetch(FetchDescriptor<Profile>())
        var result = ImportResult()
        var firstImportedId: String?

        // A fresh install has only the untouched default "Me"/p1 with no entries: let the import replace it cleanly.
        let pristineDefault = existing.count == 1 && existing[0].entries.isEmpty && existing[0].profileId == "p1"

        for bp in backup.profiles {
            let target: Profile
            let match: Profile? = backup.kind == .multiProfile
                ? existing.first { $0.profileId == bp.id }
                : (existing.first { $0.name == bp.name } ?? (pristineDefault ? existing.first : nil))
            if let m = match {
                target = m; m.name = bp.name; m.goalOz = bp.goal; result.profilesUpdated += 1
            } else {
                var id = bp.id
                if backup.kind != .multiProfile || existing.contains(where: { $0.profileId == id }) {
                    id = "p\(Int(Date().timeIntervalSince1970 * 1000))\(existing.count)"
                }
                target = Profile(profileId: id, name: bp.name, goalOz: bp.goal)
                ctx.insert(target); existing.append(target); result.profilesAdded += 1
            }
            if firstImportedId == nil || bp.id == backup.active { firstImportedId = target.profileId }

            var seen = Set(target.entries.map { key($0, calendar) })
            for (day, entries) in bp.days.sorted(by: { $0.key < $1.key }) {
                for (i, e) in entries.enumerated() {
                    guard let ts = HydrateBackupCodec.timestamp(dayKey: day, timeLabel: e.timeLabel, index: i, calendar: calendar) else { continue }
                    let entry = DrinkEntry(amountOz: e.oz, timestamp: ts, type: e.type, timeLabel: e.timeLabel)
                    let k = key(entry, calendar)
                    if seen.contains(k) { result.entriesSkipped += 1; continue }
                    seen.insert(k); ctx.insert(entry); entry.profile = target; result.entriesAdded += 1
                }
            }
        }
        if let a = firstImportedId { settings.activeProfileId = a }
        try ctx.save()
        return result
    }

    private static func key(_ e: DrinkEntry, _ cal: Calendar) -> String {
        "\(HydrateBackupCodec.dayKey(for: e.timestamp, calendar: cal))|\(e.timeLabel ?? HydrateBackupCodec.timeLabel(for: e.timestamp))|\(e.amountOz)|\(e.typeRaw)"
    }

    static func snapshot(_ p: Profile, calendar: Calendar = .current) -> BackupProfile {
        var days: [String: [BackupEntry]] = [:]
        for e in p.entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            days[HydrateBackupCodec.dayKey(for: e.timestamp, calendar: calendar), default: []]
                .append(BackupEntry(oz: e.amountOz, type: e.type, timeLabel: e.timeLabel ?? HydrateBackupCodec.timeLabel(for: e.timestamp)))
        }
        return BackupProfile(id: p.profileId, name: p.name, goal: p.goalOz, days: days)
    }

    /// All profiles, in the {active, list} format (importable by both Oahzi and the web app's storage format).
    static func exportAll(from ctx: ModelContext, calendar: Calendar = .current) throws -> Data {
        let settings = try DataStore.bootstrap(ctx)
        let ps = try ctx.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)]))
        return try HydrateBackupCodec.encode(HydrateBackup(kind: .multiProfile, active: settings.activeProfileId,
                                                           profiles: ps.map { snapshot($0, calendar: calendar) }))
    }
}
