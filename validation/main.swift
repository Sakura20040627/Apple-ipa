import Foundation

@main struct CoreValidation {
    @MainActor static func main() throws {
        var checks = [String]()
        var db = Seed.database
        precondition(db.cards.count == 12 && db.merchants.count == 64)
        precondition(Set(db.cards.map(\.name)).count == 12)
        checks.append("12-card / 64-merchant catalog and unique names")
        let amazon = db.merchants[0]
        precondition(Calculator.quotes(db, merchant: amazon, amount: 10000).first?.total == 150)
        db.prime = true
        precondition(Calculator.quotes(db, merchant: amazon, amount: 10000).first?.total == 200)
        checks.append("Prime and non-Prime reward branches")
        let shop = db.merchants[1]
        precondition(Calculator.quotes(db, merchant: shop, amount: 399).first { $0.card.kind == "paypay" }?.total == 0)
        db.paypayEligible = true
        precondition(Calculator.quotes(db, merchant: shop, amount: 399).first { $0.card.kind == "paypay" }?.total == 2)
        checks.append("PayPay eligibility and 200-yen rounding")
        let now = Date()
        let campaign = Campaign(title: "Validation", cardID: db.cards[1].id, merchantID: shop.id, bonus: 5, cap: 20, start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60), enabled: true, source: "", note: "")
        db.campaigns = [campaign, campaign]
        precondition(Calculator.quotes(db, merchant: shop, amount: 1000, date: now).first?.total == 30)
        precondition(Calculator.quotes(db, merchant: shop, amount: 1000, date: now.addingTimeInterval(120)).first?.total == 10)
        checks.append("Campaign cap, expiry and no stacking")
        db.campaigns = []
        let family = db.merchants.first { $0.name == "ファミリーマート" }!
        precondition(Catalog.matches(family, query: "全家") && Catalog.matches(family, query: "FamilyMart"))
        checks.append("Traditional Chinese and English merchant aliases")
        var merchants = Array(db.merchants.prefix(3))
        merchants[2].favorite = true
        precondition(Catalog.sorted(merchants).map(\.id) == [merchants[2].id, merchants[0].id, merchants[1].id])
        checks.append("Favorites pinned with stable ordering")
        let encoded = try JSONEncoder().encode(db)
        let decoded = try Store.decode(encoded)
        precondition(decoded.cards == db.cards && decoded.merchants == db.merchants)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let cardKeys: Set<String> = ["id", "name", "rate", "unit", "owned", "source", "note", "kind"]
        let merchantKeys: Set<String> = ["id", "name", "category", "key", "note"]
        object["cards"] = (object["cards"] as! [[String: Any]]).map { $0.filter { cardKeys.contains($0.key) } }
        object["merchants"] = (object["merchants"] as! [[String: Any]]).map { $0.filter { merchantKeys.contains($0.key) } }
        let legacy = try Store.decode(JSONSerialization.data(withJSONObject: object))
        precondition(legacy.cards[0].name == db.cards[0].name && legacy.merchants[0].favorite == nil)
        checks.append("JSON round trip and v1 backup compatibility")
        var invalid = db; invalid.merchants[0].latitude = 999; invalid.merchants[0].longitude = 135
        do { _ = try Store.decode(JSONEncoder().encode(invalid)); fatalError("Invalid coordinate accepted") } catch { }
        invalid = db; invalid.cards.append(db.cards[0])
        do { _ = try Store.decode(JSONEncoder().encode(invalid)); fatalError("Duplicate ID accepted") } catch { }
        invalid = db; invalid.cards[0].unit = 0
        do { _ = try Store.decode(JSONEncoder().encode(invalid)); fatalError("Invalid calculation unit accepted") } catch { }
        checks.append("Import rejects invalid coordinates, duplicate IDs and invalid units")
        for item in checks { print("PASS: " + item) }
        print("CORE VALIDATION PASSED: \(checks.count) groups")
    }
}
