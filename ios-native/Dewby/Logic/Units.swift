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
}
