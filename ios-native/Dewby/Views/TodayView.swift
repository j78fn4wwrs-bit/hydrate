import SwiftUI
import SwiftData

/// M1 placeholder: shows active profile + today's total, profile switcher, quick-add, import/export.
struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query private var settingsRows: [AppSettings]
    @State private var importing = false
    @State private var exportDoc: BackupDocument?
    @State private var message: String?
    @State private var logTick = 0

    private var settings: AppSettings? { settingsRows.first }
    private var active: Profile? { profiles.first { $0.profileId == settings?.activeProfileId } ?? profiles.first }
    private var todayOz: Double {
        let cal = Calendar.current
        return active?.entries.filter { cal.isDateInToday($0.timestamp) }.reduce(0) { $0 + $1.amountOz } ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                if let p = active {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(settings?.unit.format(oz: todayOz) ?? "").font(.fredoka(48))
                            Text("of \(settings?.unit.format(oz: p.goalOz) ?? "") goal").foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                        Button("Log 8 oz water", systemImage: "drop.fill") {
                            ctx.insert(DrinkEntry(amountOz: 8, type: .water, timeLabel: HydrateBackupCodec.timeLabel(for: .now), profile: p))
                            try? ctx.save(); logTick += 1
                        }.sensoryFeedback(.impact, trigger: logTick)
                    }
                    Section("Profile") {
                        Picker("Active", selection: Binding(get: { p.profileId }, set: { settings?.activeProfileId = $0 })) {
                            ForEach(profiles) { Text($0.name).tag($0.profileId) }
                        }
                        Stepper("Goal: \(Int(p.goalOz)) oz", value: Binding(get: { p.goalOz }, set: { p.goalOz = $0 }), in: 8...300, step: 4)
                        Button("New profile", systemImage: "plus") {
                            let np = Profile(name: "Profile \(profiles.count + 1)"); ctx.insert(np); settings?.activeProfileId = np.profileId
                        }
                    }
                }
                Section("Units") {
                    Picker("Unit", selection: Binding(get: { settings?.unit ?? .oz }, set: { settings?.unit = $0 })) {
                        ForEach(VolumeUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Backup") {
                    Button("Import Hydrate backup…") { importing = true }
                    Button("Export backup") {
                        if let d = try? BackupService.exportAll(from: ctx) { exportDoc = BackupDocument(data: d) }
                    }
                }
            }
            .navigationTitle("Today")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
                do {
                    let url = try r.get()
                    let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
                    let res = try BackupService.importBackup(try Data(contentsOf: url), into: ctx)
                    message = "Imported \(res.entriesAdded) drinks (\(res.entriesSkipped) already present)."
                } catch { message = "Couldn't import: that file isn't a Hydrate backup." }
            }
            .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                          document: exportDoc, contentType: .json, defaultFilename: "dewby-backup") { _ in exportDoc = nil }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} }
        }
    }
}
