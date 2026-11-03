import XCTest
@testable import PayCompass
final class CalculatorTests: XCTestCase {
    func testPrimeAndEligibility() {
        var db = Seed.database
        let shop = db.merchants[0]
        XCTAssertEqual(Calculator.quotes(db, merchant: shop, amount: 10000).first?.total, 150)
        db.prime = true
        XCTAssertEqual(Calculator.quotes(db, merchant: shop, amount: 10000).first?.total, 200)
        let pp = Calculator.quotes(db, merchant: db.merchants[1], amount: 199).first { $0.card.kind == "paypay" }
        XCTAssertEqual(pp?.total, 0)
        db.paypayEligible = true
        XCTAssertEqual(Calculator.quotes(db, merchant: db.merchants[1], amount: 399).first { $0.card.kind == "paypay" }?.total, 2)
    }
    func testCampaignCapExpiryAndNoStacking() {
        var db = Seed.database
        let now = Date()
        let c = db.cards[1], m = db.merchants[1]
        db.campaigns = [Campaign(title: "Test", cardID: c.id, merchantID: m.id, bonus: 5, cap: 20, start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60), enabled: true, source: "", note: "")]
        XCTAssertEqual(Calculator.quotes(db, merchant: m, amount: 1000, date: now).first?.total, 30)
        db.campaigns.append(db.campaigns[0])
        XCTAssertEqual(Calculator.quotes(db, merchant: m, amount: 1000, date: now).first?.total, 30)
        XCTAssertEqual(Calculator.quotes(db, merchant: m, amount: 1000, date: now.addingTimeInterval(120)).first?.total, 10)
        XCTAssertEqual(Calculator.quotes(db, merchant: m, amount: -1).first?.total, 0)
    }
    @MainActor func testImportValidationAndRoundTrip() async throws {
        let db = Seed.database
        let data = try JSONEncoder().encode(db)
        XCTAssertEqual(try Store.decode(data).cards, db.cards)
        var invalid = db
        invalid.cards[0].unit = 0
        XCTAssertThrowsError(try Store.decode(JSONEncoder().encode(invalid)))
        invalid = db; invalid.cards.append(db.cards[0])
        XCTAssertThrowsError(try Store.decode(JSONEncoder().encode(invalid)))
        XCTAssertThrowsError(try Store.decode(Data("{}".utf8)))
    }
    func testCatalogAndFavoriteSearch() {
        let db = Seed.database
        XCTAssertEqual(db.cards.count, 12)
        XCTAssertEqual(Set(db.cards.map(\.name)).count, db.cards.count)
        XCTAssertGreaterThan(db.merchants.count, 60)
        let family = db.merchants.first { $0.name == "ファミリーマート" }!
        XCTAssertTrue(Catalog.matches(family, query: "全家"))
        XCTAssertTrue(Catalog.matches(family, query: "FamilyMart"))
        var merchants = Array(db.merchants.prefix(3))
        merchants[2].favorite = true
        XCTAssertEqual(Catalog.sorted(merchants).first?.id, merchants[2].id)
        XCTAssertEqual(Catalog.sorted(merchants)[1].id, merchants[0].id)
    }
    @MainActor func testLegacyBackupAndCoordinates() async throws {
        let db = Seed.database
        let encoded = try JSONEncoder().encode(db)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let cardKeys: Set<String> = ["id", "name", "rate", "unit", "owned", "source", "note", "kind"]
        let merchantKeys: Set<String> = ["id", "name", "category", "key", "note"]
        object["cards"] = (object["cards"] as! [[String: Any]]).map { $0.filter { cardKeys.contains($0.key) } }
        object["merchants"] = (object["merchants"] as! [[String: Any]]).map { $0.filter { merchantKeys.contains($0.key) } }
        let legacy = try Store.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.cards[0].name, db.cards[0].name)
        XCTAssertNil(legacy.merchants[0].favorite)
        var invalid = db
        invalid.merchants[0].latitude = 999
        invalid.merchants[0].longitude = 135
        XCTAssertThrowsError(try Store.decode(JSONEncoder().encode(invalid)))
    }
}
