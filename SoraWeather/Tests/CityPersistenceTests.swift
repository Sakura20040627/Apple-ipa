import XCTest
@testable import SoraWeatherCore
final class CityPersistenceTests: XCTestCase {
    func testFirstLaunchHasOnlyLocationAndOsaka() { let items = CityPersistence.normalized([]); XCTAssertEqual(items.count, 1); XCTAssertTrue(items[0].isLocation); XCTAssertEqual(items[0].region.id, "osaka") }
    func testLocationCannotBeDeleted() { let items = CityPersistence.deleting(["location"], from: []); XCTAssertEqual(items.count, 1); XCTAssertEqual(items[0].id, "location") }
    func testSavedCityCanBeDeleted() {
        let items = CityPersistence.normalized([SavedCity(id: "tokyo", region: Region.supported[1])])
        XCTAssertEqual(CityPersistence.deleting(["tokyo"], from: items).map(\.id), ["location"])
    }
    func testOrderSurvivesPersistence() throws {
        let items = CityPersistence.normalized([SavedCity(id: "b", region: Region.supported[2]), SavedCity(id: "a", region: .osaka)])
        let bytes = try JSONEncoder().encode(items); let decoded = try JSONDecoder().decode([SavedCity].self, from: bytes)
        XCTAssertEqual(CityPersistence.normalized(decoded).map(\.id), ["location", "b", "a"])
    }
    func testDuplicateIDsAreRemoved() { XCTAssertEqual(CityPersistence.normalized([SavedCity(id: "a", region: .osaka), SavedCity(id: "a", region: .osaka)]).count, 2) }
    func testLocationRemainsFirst() {
        let items = CityPersistence.normalized([SavedCity(id: "a", region: .osaka), SavedCity(id: "different", region: Region.supported[1], isLocation: true)])
        XCTAssertEqual(items.first?.id, "location"); XCTAssertEqual(items.first?.region.id, "tokyo")
    }
    func testMoreThanSixCitiesRemainDistinct() {
        let items = CityPersistence.normalized((0..<8).map { SavedCity(id: "city-\($0)", region: .osaka) })
        XCTAssertEqual(items.count, 9); XCTAssertEqual(Set(items.map(\.id)).count, 9)
    }
}
