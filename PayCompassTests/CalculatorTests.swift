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
    @MainActor func testImportValidationAndRoundTrip() throws {
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
}
