import Foundation

@main struct CoreValidation {
    @MainActor static func main() throws {
        var checks = [String]()
        var db = Seed.database
        precondition(db.cards.count == 2 && db.merchants.count == 64)
        precondition(Set(db.cards.map(\.name)).count == 2)
        checks.append("2-card / 64-merchant catalog and unique names")
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
        precondition(Calculator.quotes(db, merchant: shop, amount: 1000, date: now).first?.total == 35)
        precondition(Calculator.quotes(db, merchant: shop, amount: 1000, date: now.addingTimeInterval(120)).first?.total == 15)
        checks.append("Campaign cap, expiry and no stacking")
        db.campaigns = []
        var context = PurchaseContext()
        let seven = shop
        func amazonTotal(_ amount: Int, _ c: PurchaseContext) -> Int { Calculator.quotes(db, merchant: seven, amount: amount, context: c).first { $0.card.kind == "amazon" }!.total }
        precondition(amazonTotal(10000, context) == 150)
        context.amazonApplePay = true
        precondition(amazonTotal(10000, context) == 700)
        precondition(amazonTotal(199, context) == 0)
        context.tobacco = true
        precondition(amazonTotal(10000, context) == 150)
        context.tobacco = false; context.excludedConvenience = true
        precondition(amazonTotal(10000, context) == 100)
        context.type = .charge
        precondition(Calculator.quotes(db, merchant: seven, amount: 10000, context: context).allSatisfy { $0.total == 0 })
        checks.append("Seven Apple Pay / physical / tobacco / excluded branch / charge conditions")
        let formatter = ISO8601DateFormatter()
        let first = formatter.date(from: "2026-12-01T14:59:59Z")!
        let second = formatter.date(from: "2026-12-01T15:00:00Z")!
        precondition(RewardRules.month(first) == "2026-11" && RewardRules.month(second) == "2026-12")
        db.paypayStepMonth = "2026-11"
        precondition(Calculator.quotes(db, merchant: seven, amount: 10000, date: first).first { $0.card.kind == "paypay" }?.total == 150)
        precondition(Calculator.quotes(db, merchant: seven, amount: 10000, date: second).first { $0.card.kind == "paypay" }?.total == 100)
        context.type = .utilities
        precondition(Calculator.quotes(db, merchant: seven, amount: 10000, date: second, context: context).first { $0.card.kind == "paypay" }?.total == 50)
        checks.append("Tokyo Step period boundary and utility rate")
        db.paypayStepMonth = nil
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
        var old = db
        old.cards.append(Card(name: "Other card", rate: 1, unit: 100, source: "", note: ""))
        old.merchants[1].favorite = true
        let migrated = try Store.decode(JSONEncoder().encode(old))
        precondition(migrated.cards.count == 2 && migrated.merchants[1].favorite == true)
        precondition(migrated.cards[0].id == db.cards[0].id)
        checks.append("Old catalog migration preserves ownership IDs and favorites")
        for item in checks { print("PASS: " + item) }
        print("CORE VALIDATION PASSED: \(checks.count) groups")
    }
}
