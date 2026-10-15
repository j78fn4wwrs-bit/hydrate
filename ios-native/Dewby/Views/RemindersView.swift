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
            .navigationTitle("Reminders")
        }
    }

    @ViewBuilder private func content(_ s: AppSettings) -> some View {
        @Bindable var s = s
        Section(footer: Text("Saved now; reminders start firing in a later update.")) {
            Toggle("Remind me", isOn: $s.remindersEnabled)
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
            Button("Preview", systemImage: "play.fill") { TonePlayer.shared.preview(s.tone, style: s.alertStyle) }
                .disabled(s.alertStyle == .silent)
        }
        .onChange(of: s.toneRaw) { TonePlayer.shared.preview(s.tone, style: s.alertStyle) }
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) }
        )
    }
}
