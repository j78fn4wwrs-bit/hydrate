import Foundation

public enum VolumeUnit: String, CaseIterable, Codable, Sendable {
    case oz, ml
    public static let mlPerOz = 29.5735295625
    public func fromOz(_ oz: Double) -> Double { self == .oz ? oz : oz * Self.mlPerOz }
    public func toOz(_ v: Double) -> Double { self == .oz ? v : v / Self.mlPerOz }
    public func format(oz: Double) -> String {
        let v = fromOz(oz)
        return self == .oz ? "\(Int(v.rounded())) oz" : "\(Int(v.rounded())) ml"
    }

    /// One-decimal, signed amount, e.g. "+10.8 oz" / "−4 oz" / "+319.4 ml".
    public func formatSigned(oz: Double) -> String {
        let v = (fromOz(oz) * 10).rounded() / 10
        let body = v == v.rounded() ? String(Int(abs(v))) : String(format: "%.1f", abs(v))
        return "\(v < 0 ? "−" : "+")\(body) \(rawValue)"
    }
    /// "12 oz Energy drink · +10.8 oz hydration"
    public func describe(rawOz: Double, typeLabel: String, netOz: Double) -> String {
        "\(format(oz: rawOz)) \(typeLabel) · \(formatSigned(oz: netOz)) hydration"
    }
}
