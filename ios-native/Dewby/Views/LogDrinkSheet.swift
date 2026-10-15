import SwiftUI

struct LogDrinkSheet: View {
    let unit: VolumeUnit
    var onLog: (Double, DrinkType) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var type: DrinkType = .water
    @State private var amount: Double

    init(unit: VolumeUnit, onLog: @escaping (Double, DrinkType) -> Void) {
        self.unit = unit; self.onLog = onLog
        _amount = State(initialValue: unit.defaultLog)
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Theme.Space.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                        ForEach(DrinkType.allCases, id: \.self) { t in
                            Button { type = t } label: {
                                VStack(spacing: Theme.Space.s) {
                                    Image(systemName: t.symbol).font(.title2).foregroundStyle(t.tint)
                                    Text(t.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.center).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(type == t ? Theme.coral : .clear, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(type == t ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text(unit.formatValue(amount)).font(.dewBigNumber).foregroundStyle(Theme.ink)
                            .contentTransition(.numericText()).animation(.snappy, value: amount)
                        Slider(value: $amount, in: unit.sliderRange, step: unit.sliderStep) { Text("Amount") }
                            .tint(Theme.water)
                            .sensoryFeedback(.selection, trigger: amount)
                    }
                    .dewCard()
                    Button { onLog(unit.toOz(amount), type); dismiss() } label: {
                        Label("Log \(type.label.lowercased())", systemImage: "plus")
                    }
                    .buttonStyle(LogPillStyle())
                }
                .padding(Theme.Space.l)
            }
            .dewScreen()
            .navigationTitle("Log a drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
