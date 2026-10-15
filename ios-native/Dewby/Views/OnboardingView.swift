import SwiftUI
import SwiftData

/// Single page, first launch: name + goal stepper. HealthKit is optional per handoff → deferred (not in v1).
struct OnboardingView: View {
    @Environment(\.modelContext) private var ctx
    let profile: Profile
    let settings: AppSettings
    @State private var name = ""
    @State private var goalOz: Double = 108
    @State private var importing = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xxl) {
                Image("DewbyLogo").resizable().scaledToFit().frame(maxWidth: 200).padding(.top, Theme.Space.xxxl)
                    .accessibilityLabel("Dewby")
                Text("Sip, log, glow.").font(.dewLargeTitle).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("What should we call you?").font(.headline)
                    TextField("Your name", text: $name)
                        .textContentType(.givenName).focused($nameFocused)
                        .padding(Theme.Space.m)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }.dewCard()
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Daily goal").font(.headline)
                    Picker("Unit", selection: Binding(get: { settings.unit }, set: { settings.unit = $0 })) {
                        ForEach(VolumeUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    GoalStepper(goalOz: $goalOz, unit: settings.unit)
                }.dewCard()
                Button("Get started") { finish() }.buttonStyle(LogPillStyle())
                Button("I have a Hydrate backup") { importing = true }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.coral)
            }
            .padding(Theme.Space.l)
        }
        .dewScreen()
        .onAppear { name = profile.name == "Me" ? "" : profile.name; goalOz = profile.goalOz }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
            guard let url = try? r.get() else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), (try? BackupService.importBackup(data, into: ctx)) != nil {
                settings.hasOnboarded = true; try? ctx.save()
            }
        }
    }

    private func finish() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = trimmed.isEmpty ? "Me" : trimmed
        profile.goalOz = goalOz
        settings.hasOnboarded = true
        try? ctx.save()
    }
}
