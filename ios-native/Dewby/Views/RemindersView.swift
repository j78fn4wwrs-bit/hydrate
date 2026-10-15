import SwiftUI
import SwiftData

/// M1: settings are saved (SwiftData) but NOT scheduled yet (UNUserNotificationCenter wiring is M3).
struct RemindersView: View {
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        NavigationStack {
            Form {
                if let s = settingsRows.first { content(s) }
            }
            .dewScreen()
            .navigationTitle("Reminders")
        }
    }

    @ViewBuilder private func content(_ s: AppSettings) -> some View {
        @Bindable var s = s
        Section {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "bell.fill").font(.title2).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(Theme.logGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading) {
                    Text("Sip reminders").font(.dewCardTitle).foregroundStyle(Theme.ink)
                    Text(summary(s)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.Space.xs)
            .listRowBackground(Theme.card)
        }
        Section(footer: Text("Saved now; reminders start firing in a later update.")) {
            Toggle("Remind me", isOn: $s.remindersEnabled).tint(Theme.water)
            Picker("Every", selection: $s.reminderIntervalMinutes) {
                ForEach([30, 60, 90, 120, 180, 240], id: \.self) { m in Text(m % 60 == 0 ? "\(m / 60) h" : "\(m) min").tag(m) }
            }
            DatePicker("From", selection: time($s.reminderStartMinutes), displayedComponents: .hourAndMinute)
            DatePicker("Until", selection: time($s.reminderEndMinutes), displayedComponents: .hourAndMinute)
        }
        Section(header: Text("Alert"), footer: Text("Vibration only happens if your iPhone's Settings › Sounds & Haptics allows it.")) {
            Picker("Style", selection: $s.alertStyle) {
                ForEach(AlertStyle.allCases, id: \.self) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
            if s.alertStyle == .sound {
                Picker("Tone", selection: $s.tone) {
                    ForEach(ReminderTone.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Button("Preview", systemImage: "play.circle.fill") { TonePlayer.shared.preview(s.tone, style: s.alertStyle) }
                .disabled(s.alertStyle == .silent)
        }
        .onChange(of: s.toneRaw) { TonePlayer.shared.preview(s.tone, style: s.alertStyle) }
    }

    private func summary(_ s: AppSettings) -> String {
        let f = { (m: Int) in (Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now).formatted(date: .omitted, time: .shortened) }
        let every = s.reminderIntervalMinutes % 60 == 0 ? "\(s.reminderIntervalMinutes / 60) h" : "\(s.reminderIntervalMinutes) min"
        return s.remindersEnabled ? "Every \(every), \(f(s.reminderStartMinutes))–\(f(s.reminderEndMinutes))" : "Off"
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) }
        )
    }
}
