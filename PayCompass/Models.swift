import Foundation

struct Card: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var rate: Double
    var unit: Int
    var owned: Bool = true
    var source: String
    var note: String
    var kind: String = "custom"
    var issuer: String?
    var pointsName: String?
    var annualFee: String?
    var annualFeeZH: String?
    var brands: String?
    var details: String?
    var detailsZH: String?
    var noteZH: String?
    var color: String?
    var artworkVariant: String?
}
struct Merchant: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var category: String
    var key: String = "general"
    var favorite: Bool?
    var aliases: String?
    var icon: String?
    var color: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var note: String = "通常のカード購入を想定。店舗・商品ごとの対象外条件を確認してください。"
}
struct Campaign: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var cardID: UUID
    var merchantID: UUID
    var bonus: Double
    var cap: Int
    var start: Date
    var end: Date
    var enabled: Bool = false
    var source: String
    var note: String
}
struct Database: Codable {
    var version = 1
    var cards: [Card]
    var merchants: [Merchant]
    var campaigns: [Campaign] = []
    var prime = false
    var paypayEligible = false
    var paypayStepMonth: String?
}
struct Quote: Identifiable {
    var id: UUID { card.id }
    let card: Card
    let rate: Double
    let base: Int
    let bonus: Int
    let reason: String
    var total: Int { base + bonus }
}
enum Seed {
    static var database: Database {
        var db = Database(cards: [
            Card(name: "PayPay Card", rate: 1, unit: 200, source: "https://www.paypay-card.co.jp/service/000263.html", note: "200円単位。アプリ登録・本人確認が必要。PayPayステップの追加分は含みません。", kind: "paypay"),
            Card(name: "Amazon Mastercard", rate: 1, unit: 100, source: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp", note: "一般加盟店の通常還元。コンビニ等の条件付き優遇は未計上。", kind: "amazon")
        ], merchants: [
            Merchant(name: "Amazon.co.jp", category: "オンライン", key: "amazon"),
            Merchant(name: "セブン‐イレブン", category: "コンビニ"),
            Merchant(name: "ローソン", category: "コンビニ"),
            Merchant(name: "ファミリーマート", category: "コンビニ"),
            Merchant(name: "すき家", category: "飲食"), Merchant(name: "吉野家", category: "飲食"),
            Merchant(name: "マクドナルド", category: "飲食"), Merchant(name: "スターバックス", category: "飲食"),
            Merchant(name: "イオン", category: "スーパー"), Merchant(name: "ライフ", category: "スーパー"),
            Merchant(name: "ウエルシア", category: "ドラッグストア"), Merchant(name: "マツモトキヨシ", category: "ドラッグストア"),
            Merchant(name: "ユニクロ", category: "ショッピング"), Merchant(name: "無印良品", category: "ショッピング"),
            Merchant(name: "ヨドバシカメラ", category: "家電"), Merchant(name: "ビックカメラ", category: "家電")
        ])
        Catalog.enrich(&db)
        return db
    }
}
