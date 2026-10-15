import XCTest
import SwiftData
@testable import Dewby

final class BackupCodecTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }

    func testDecodeMultiProfile() throws {
        let b = try HydrateBackupCodec.decode(fixture("sample_backup"))
        XCTAssertEqual(b.kind, .multiProfile)
        XCTAssertEqual(b.active, "p2")
        XCTAssertEqual(b.profiles.map(\.id), ["p1", "p2", "p3"])
        let mike = b.profiles[0]
        XCTAssertEqual(mike.name, "Mike"); XCTAssertEqual(mike.goal, 120)
        XCTAssertEqual(mike.days["2026-10-13"]?.map(\.type), [.water, .coffee, .water])   // missing type -> water
        // "8" string accepted, unknown type -> water, oz 0 dropped
        XCTAssertEqual(mike.days["2026-10-14"], [BackupEntry(oz: 20, type: .energy, timeLabel: "6:45 PM"),
                                                 BackupEntry(oz: 8, type: .water, timeLabel: "7:00 PM")])
        XCTAssertEqual(b.profiles[2].goal, 108, "non-v2 profiles reset to 108 like the web app")
    }

    func testDecodeLegacy() throws {
        let b = try HydrateBackupCodec.decode(fixture("legacy_backup"))
        XCTAssertEqual(b.kind, .legacy)
        XCTAssertEqual(b.profiles.count, 1)
        XCTAssertEqual(b.profiles[0].name, "Me")
        XCTAssertEqual(b.profiles[0].goal, 108)   // no v2 flag
        XCTAssertEqual(Array(b.profiles[0].days.keys), ["2026-01-02"])
    }

    func testDecodeWebSingleExport() throws {
        let json = #"{"name":"Mike","goal":96,"v2":1,"days":{"2026-10-01":[{"oz":8,"type":"water","t":"9:00 AM"}]}}"#
        let b = try HydrateBackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(b.kind, .singleProfile); XCTAssertEqual(b.profiles[0].goal, 96)
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try HydrateBackupCodec.decode(Data("[1,2]".utf8)))
        XCTAssertThrowsError(try HydrateBackupCodec.decode(Data(#"{"foo":1}"#.utf8)))
    }

    func testTimestampParsing() throws {
        let d = try XCTUnwrap(HydrateBackupCodec.timestamp(dayKey: "2026-10-13", timeLabel: "1:15 PM", index: 0, calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: d), 13); XCTAssertEqual(cal.component(.minute, from: d), 15)
        let n = try XCTUnwrap(HydrateBackupCodec.timestamp(dayKey: "2026-10-14", timeLabel: "10:00\u{202F}AM", index: 0, calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: n), 10)
        let g = try XCTUnwrap(HydrateBackupCodec.timestamp(dayKey: "2026-10-14", timeLabel: "garbage", index: 2, calendar: cal))
        XCTAssertEqual(cal.component(.hour, from: g), 12)
    }

    func testEncodeDecodeRoundTrip() throws {
        let b = try HydrateBackupCodec.decode(fixture("sample_backup"))
        let again = try HydrateBackupCodec.decode(HydrateBackupCodec.encode(b))
        XCTAssertEqual(again.profiles.map(\.days), b.profiles.map(\.days))
        XCTAssertEqual(again.active, b.active)
        XCTAssertEqual(again.profiles[2].goal, 108)
    }

    @MainActor func testImportIntoSwiftDataIsIdempotent() throws {
        let container = try DataStore.makeContainer(inMemory: true)
        let ctx = container.mainContext
        let r1 = try BackupService.importBackup(fixture("sample_backup"), into: ctx, calendar: cal)
        XCTAssertEqual(r1.entriesAdded, 8)
        let r2 = try BackupService.importBackup(fixture("sample_backup"), into: ctx, calendar: cal)
        XCTAssertEqual(r2.entriesAdded, 0); XCTAssertEqual(r2.entriesSkipped, 8)
        let profiles = try ctx.fetch(FetchDescriptor<Profile>())
        XCTAssertEqual(Set(profiles.map(\.profileId)), ["p1", "p2", "p3"])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AppSettings>()).first?.activeProfileId, "p2")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AppSettings>()).first?.unit, .oz)

        // Export -> decode matches original days
        let out = try HydrateBackupCodec.decode(BackupService.exportAll(from: ctx, calendar: cal))
        let orig = try HydrateBackupCodec.decode(fixture("sample_backup"))
        for p in orig.profiles {
            // Unparseable times sort to noon on export, so compare per-day contents order-independently.
            let norm: ([String: [BackupEntry]]) -> [String: [String]] = { $0.mapValues { $0.map { "\($0.oz)|\($0.type)|\($0.timeLabel ?? "")" }.sorted() } }
            XCTAssertEqual(out.profiles.first { $0.id == p.id }.map { norm($0.days) }, norm(p.days), p.id)
        }
    }

    @MainActor func testDefaults() throws {
        let ctx = try DataStore.makeContainer(inMemory: true).mainContext
        let s = try DataStore.bootstrap(ctx)
        XCTAssertEqual(s.unit, .oz); XCTAssertEqual(s.reminderIntervalMinutes, 120)
        XCTAssertEqual(s.reminderStartMinutes, 540); XCTAssertEqual(s.reminderEndMinutes, 1140)
        XCTAssertEqual(s.tone, .drip); XCTAssertEqual(s.alertStyle, .sound)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Profile>()).first?.goalOz, 108)
    }

    func testAllTonesBundled() {
        for t in ReminderTone.allCases {
            XCTAssertNotNil(Bundle(for: Profile.self).url(forResource: t.rawValue, withExtension: "caf"), t.rawValue)
        }
    }

    func testStats() {
        let today = cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9))!
        let totals = ["2026-10-12": 108.0, "2026-10-13": 120, "2026-10-14": 110, "2026-10-15": 40, "2026-10-01": 200]
        let s = HydrationStats.compute(totals: totals, goal: 108, today: today, calendar: cal)
        XCTAssertEqual(s.streak, 3, "today not met yet -> count from yesterday")
        XCTAssertEqual(s.bestDayOz, 200); XCTAssertEqual(s.totalOz, 578); XCTAssertEqual(s.daysMet, 4)
        XCTAssertEqual(s.avg7, (108 + 120 + 110 + 40) / 7, accuracy: 0.001)
        XCTAssertEqual(s.avg30, 578 / 30, accuracy: 0.001)
        let met = HydrationStats.compute(totals: totals.merging(["2026-10-15": 108]) { $1 }, goal: 108, today: today, calendar: cal)
        XCTAssertEqual(met.streak, 4)
    }

    func testDrinkTypesAndFactors() {
        XCTAssertEqual(DrinkType.from(raw: "sports"), .energy)
        XCTAssertEqual(DrinkType.from(raw: nil), .water)
        XCTAssertEqual(DrinkType.from(raw: "nope"), .water)
        XCTAssertEqual(DrinkType.energy.backupRaw, "sports")
        XCTAssertEqual(Set(DrinkType.hydrating + DrinkType.dehydrates), Set(DrinkType.allCases))
        XCTAssertTrue(DrinkType.hydrating.allSatisfy { $0.hydrationFactor > 0 && $0.isHydrating })
        for t in [DrinkType.coffee, .espresso, .latte, .tea] { XCTAssertEqual(t.hydrationFactor, 1.0, t.rawValue); XCTAssertTrue(t.isHydrating) }
        XCTAssertEqual(DrinkType.beer.hydrationFactor, 0.8)
        XCTAssertEqual(DrinkType.wine.hydrationFactor, 0.5)
        XCTAssertEqual(DrinkType.spirits.hydrationFactor, -0.5)
        XCTAssertEqual(DrinkType.dehydrates, [.beer, .wine, .spirits])
        XCTAssertFalse(DrinkType.beer.isHydrating)
        XCTAssertEqual(DrinkType.from(raw: "alcohol"), .spirits, "legacy alcohol migrates to spirits")
        XCTAssertEqual(VolumeUnit.oz.formatSigned(oz: DrinkType.beer.netOz(12)), "+9.6 oz")
        XCTAssertEqual(VolumeUnit.oz.formatSigned(oz: DrinkType.spirits.netOz(12)), "−6 oz")
    }

    @MainActor func testNetTotalsClampAndExportRaw() throws {
        let ctx = try DataStore.makeContainer(inMemory: true).mainContext
        try DataStore.bootstrap(ctx)
        let p = try XCTUnwrap(ctx.fetch(FetchDescriptor<Profile>()).first)
        let now = Date.now
        ctx.insert(DrinkEntry(amountOz: 16, timestamp: now, type: .water, profile: p))
        ctx.insert(DrinkEntry(amountOz: 8, timestamp: now, type: .coffee, profile: p))   // +8 (caffeine counts like water)
        try ctx.save()
        XCTAssertEqual(p.netTotal(on: now), 24, accuracy: 0.001, "coffee does not lower the total")
        ctx.insert(DrinkEntry(amountOz: 60, timestamp: now, type: .spirits, profile: p))   // −30
        try ctx.save()
        XCTAssertEqual(p.netTotal(on: now), 0, "clamped at 0")
        let out = try HydrateBackupCodec.decode(BackupService.exportAll(from: ctx))
        let raw = out.profiles[0].days.values.flatMap { $0 }.map(\.oz).sorted()
        XCTAssertEqual(raw, [8, 16, 40], "export keeps raw amounts")
    }

    func testHydratingFactors() {
        let expected: [DrinkType: Double] = [.water: 1.0, .juice: 1.0, .soda: 0.9, .energy: 0.9, .smoothie: 0.85, .other: 1.0]
        for (t, f) in expected { XCTAssertEqual(t.hydrationFactor, f, accuracy: 1e-9, t.rawValue) }
        XCTAssertEqual(DrinkType.energy.netOz(12), 10.8, accuracy: 1e-9)
        XCTAssertEqual(VolumeUnit.oz.describe(rawOz: 12, typeLabel: "Energy drink", netOz: 10.8), "12 oz Energy drink · +10.8 oz hydration")
        XCTAssertEqual(VolumeUnit.oz.formatSigned(oz: -4), "−4 oz")
        XCTAssertEqual(VolumeUnit.ml.formatSigned(oz: 10.8), "+319.4 ml")
    }

    func testLearnPercentLabels() {
        XCTAssertEqual(LearnPercent.label(0.85), "85%")
        XCTAssertEqual(LearnPercent.label(-1.5), "−150%")
    }

    @MainActor func testLegacyAlcoholRowsAndBackups() throws {
        // Stored SwiftData row from a pre-split build
        let e = DrinkEntry(amountOz: 2, type: .water)
        e.typeRaw = "alcohol"
        XCTAssertEqual(e.type, .spirits)
        XCTAssertEqual(e.netOz, -1, accuracy: 1e-9)
        // Backup file containing the legacy value
        let json = #"{"name":"Mike","goal":108,"v2":1,"days":{"2026-10-14":[{"oz":2,"type":"alcohol","t":"9:00 PM"}]}}"#
        let b = try HydrateBackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(b.profiles[0].days["2026-10-14"]?.first?.type, .spirits)
    }
}
