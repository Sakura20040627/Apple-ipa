import Foundation

public struct SavedCity: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var region: Region
    public let isLocation: Bool
    public init(id: String, region: Region, isLocation: Bool = false) { self.id = id; self.region = region; self.isLocation = isLocation }
}
public enum CityPersistence {
    public static let locationID = "location"
    public static func normalized(_ values: [SavedCity]) -> [SavedCity] {
        let location = values.first(where: { $0.isLocation })?.region ?? .osaka
        var seen = Set<String>([locationID])
        return [SavedCity(id: locationID, region: location, isLocation: true)] + values.filter { !$0.isLocation && seen.insert($0.id).inserted }
    }
    public static func deleting(_ ids: Set<String>, from values: [SavedCity]) -> [SavedCity] { normalized(values.filter { $0.isLocation || !ids.contains($0.id) }) }
}
