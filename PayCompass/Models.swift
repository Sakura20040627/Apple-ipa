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
enum Calculator {
    static func quotes(_ db: Database, merchant: Merchant, amount: Int, date: Date = .now) -> [Quote] {
        db.cards.filter(\.owned).map { card in
            var rate = card.rate
            var reason = L.isChinese ? (card.noteZH ?? card.note) : card.note
            if card.kind == "paypay" && !db.paypayEligible { rate = 0; reason = L.t("アプリ登録・本人確認が未確認のためポイント未計上。", "尚未確認完成 App 登錄與身分驗證，因此暫不計入點數。") }
            if card.kind == "amazon" && merchant.key == "amazon" { rate = db.prime ? 2 : 1.5; reason = L.t("Amazon.co.jp通常購入。寄付・対象外取引を除く。", "適用 Amazon.co.jp 一般購物；不含捐款及不適用交易。") }
            let safe = max(0, min(amount, 100_000_000))
            let base = Int((Double(safe / max(1, card.unit)) * Double(card.unit) * rate / 100).rounded(.down))
            let bonus = db.campaigns.filter { $0.enabled && $0.cardID == card.id && $0.merchantID == merchant.id && $0.start <= date && date <= $0.end }.map { min($0.cap, Int((Double(safe) * $0.bonus / 100).rounded(.down))) }.max() ?? 0
            return Quote(card: card, rate: rate, base: base, bonus: bonus, reason: reason)
        }.sorted { $0.total == $1.total ? $0.card.name < $1.card.name : $0.total > $1.total }
    }
}
enum Seed {
    static var database: Database {
        var db = Database(cards: [
            Card(name: "PayPay Card", rate: 1, unit: 200, source: "https://www.paypay-card.co.jp/service/000263.html", note: "200円単位。アプリ登録・本人確認が必要。PayPayステップの追加分は含みません。", kind: "paypay"),
            Card(name: "Amazon Mastercard", rate: 1, unit: 100, source: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp", note: "一般加盟店の通常還元。コンビニ等の条件付き優遇は未計上。", kind: "amazon"),
            Card(name: "楽天カード", rate: 1, unit: 100, owned: false, source: "https://www.rakuten-card.co.jp/point/", note: "通常購入100円単位。公共料金等の例外は対象外。"),
            Card(name: "JCB CARD W", rate: 1, unit: 200, owned: false, source: "https://www.jcb.co.jp/ordercard/kojin_card/os_card_w2.html", note: "月合計200円単位・1pt最大1円換算。この画面は単一購入の概算。")
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
