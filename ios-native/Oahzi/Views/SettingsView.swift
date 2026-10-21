import SwiftUI
import SwiftData

/// Gear sheet: profiles, units, backup (moved off Today in M2).
struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query private var settingsRows: [AppSettings]
    @State private var importing = false
    @State private var exportDoc: BackupDocument?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                if let s = settingsRows.first { content(s) }
            }
            .dewScreen()
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
                do {
                    let url = try r.get()
                    let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
                    let res = try BackupService.importBackup(try Data(contentsOf: url), into: ctx)
                    message = "Imported \(res.entriesAdded) drinks (\(res.entriesSkipped) already present)."
                } catch { message = "Couldn't import: that file isn't a Hydrate backup." }
            }
            .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                          document: exportDoc, contentType: .json, defaultFilename: "oahzi-backup") { _ in exportDoc = nil }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} }
        }
    }

    @ViewBuilder private func content(_ s: AppSettings) -> some View {
        @Bindable var s = s
        Section("Profiles") {
            ForEach(profiles) { p in
                NavigationLink { ProfileEditor(profile: p, unit: s.unit, canDelete: profiles.count > 1) } label: {
                    HStack {
                        Image(systemName: p.profileId == s.activeProfileId ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(p.profileId == s.activeProfileId ? Theme.coral : .secondary)
                            .onTapGesture { s.activeProfileId = p.profileId }
                            .accessibilityLabel(p.profileId == s.activeProfileId ? "Active" : "Make active")
                        Text(p.name)
                        Spacer()
                        Text(s.unit.format(oz: p.goalOz)).foregroundStyle(.secondary)
                    }
                }
            }
            Button("Add profile", systemImage: "plus") {
                let np = Profile(name: "Profile \(profiles.count + 1)")
                ctx.insert(np); s.activeProfileId = np.profileId; try? ctx.save()
            }
        }
        Section("Units") {
            Picker("Unit", selection: $s.unit) {
                ForEach(VolumeUnit.allCases, id: \.self) { Text($0 == .oz ? "Ounces (oz)" : "Milliliters (ml)").tag($0) }
            }.pickerStyle(.inline).labelsHidden()
        }
        Section(header: Text("Backup"), footer: Text("Everything stays on this iPhone. Backups are plain JSON, compatible with the Hydrate web app.")) {
            Button("Import Hydrate backup…", systemImage: "square.and.arrow.down") { importing = true }
            Button("Export backup", systemImage: "square.and.arrow.up") {
                if let d = try? BackupService.exportAll(from: ctx) { exportDoc = BackupDocument(data: d) }
            }
        }
    }
}

private struct ProfileEditor: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: Profile
    let unit: VolumeUnit
    let canDelete: Bool
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("Name") { TextField("Name", text: $profile.name) }
            Section("Daily goal") { GoalStepper(goalOz: $profile.goalOz, unit: unit) }
            if canDelete {
                Section {
                    Button("Delete profile", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .dewScreen()
        .navigationTitle(profile.name)
        .confirmationDialog("Delete \(profile.name) and all its drinks?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let doomed = profile
                dismiss()   // leave the editor before the model goes away
                DispatchQueue.main.async {
                    ctx.delete(doomed); try? ctx.save()
                    _ = try? DataStore.bootstrap(ctx)   // re-points activeProfileId if needed
                }
            }
        }
    }
}

/// Goal stepper in the user's unit; stores oz.
struct GoalStepper: View {
    @Binding var goalOz: Double
    let unit: VolumeUnit
    var body: some View {
        let step = unit == .oz ? 4.0 : 100.0
        Stepper(value: Binding(get: { unit.fromOz(goalOz).rounded() }, set: { goalOz = unit.toOz($0) }),
                in: unit == .oz ? 16...300 : 500...9000, step: step) {
            Text(unit.format(oz: goalOz)).font(.fredoka(28, relativeTo: .title)).foregroundStyle(Theme.ink).monospacedDigit()
        }
    }
}
