import Foundation

enum PurchaseType: String, CaseIterable, Identifiable {
    case shopping, utilities, amazonDonation, charge
    var id: String { rawValue }
    var name: String {
        switch self {
        case .shopping: L.t("通常のお買い物", "一般購物")
        case .utilities: L.t("電気・ガス・水道・税金", "水電瓦斯／稅金")
        case .amazonDonation: L.t("Amazonふるさと納税", "Amazon 故鄉納稅")
        case .charge: L.t("交通系IC等の対象外チャージ", "交通 IC 等不計點儲值")
        }
    }
}
struct PurchaseContext: Equatable {
    var type: PurchaseType = .shopping
    var amazonApplePay = false
    var tobacco = false
    var excludedConvenience = false
}
enum RewardRules {
    static func month(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let period = calendar.component(.day, from: date) == 1 ? calendar.date(byAdding: .month, value: -1, to: date)! : date
        let c = calendar.dateComponents([.year, .month], from: period)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }
    static func chain(_ merchant: Merchant) -> String {
        let all = (merchant.name + " " + (merchant.aliases ?? "")).lowercased()
        if all.contains("セブン") || all.contains("7-eleven") || all.contains("7 eleven") { return "seven" }
        if all.contains("ローソン") || all.contains("lawson") { return "lawson" }
        if all.contains("ファミリーマート") || all.contains("familymart") { return "family" }
        return "general"
    }
}
enum Calculator {
    static func quotes(_ db: Database, merchant: Merchant, amount: Int, date: Date = .now, context: PurchaseContext = .init()) -> [Quote] {
        let safe = max(0, min(amount, 100_000_000))
        let step = db.paypayStepMonth == RewardRules.month(date)
        let chain = RewardRules.chain(merchant)
        return db.cards.filter { $0.owned && ["paypay", "amazon"].contains($0.kind) }.map { card in
            var rate: Double = 1
            var unit = card.kind == "paypay" ? 200 : 100
            var reason = L.t("通常のカード払い", "一般刷卡支付")
            var extra = 0
            var extraRate: Double = 0
            if card.kind == "paypay" {
                rate = db.paypayEligible ? (step ? 1.5 : 1) : 0
                reason = !db.paypayEligible ? L.t("クレジット設定・本人確認を確認してください。", "請先確認信用支付設定與身分驗證。") : step ? L.t("PayPayステップ適用月：通常1%＋達成0.5%", "PayPay Step 當期資格：基本 1%＋加碼 0.5%") : L.t("通常1% · 200円単位", "一般消費 1% · 每 200 日圓計算")
                if context.type == .utilities {
                    rate = db.paypayEligible ? (step ? 1 : 0.5) : 0
                    reason = L.t("公共料金・税金：基本0.5%、適用月は+0.5%", "公共費用／稅金：基本 0.5%，當期 Step 可再加 0.5%")
                }
                if context.type == .amazonDonation {
                    rate = 0; reason = L.t("この寄付のPayPay付与条件は未確認のため未計上。", "此捐款的 PayPay 適用條件未確認，暫不計入回饋。")
                }
            } else {
                if merchant.key == "amazon" && context.type == .shopping {
                    rate = db.prime ? 2 : 1.5
                    reason = db.prime ? L.t("Amazon.co.jp · Prime会員2%", "Amazon.co.jp · Prime 會員 2%") : L.t("Amazon.co.jp · Prime以外1.5%", "Amazon.co.jp · 非 Prime 會員 1.5%")
                }
                if chain != "general" && context.type == .shopping && !context.excludedConvenience {
                    rate = 1.5; unit = 200
                    reason = L.t("対象コンビニ1.5% · 月間合計の概算", "指定便利商店 1.5% · 以月結規則概算")
                    if chain == "seven" && context.amazonApplePay && !context.tobacco {
                        extra = (safe / 200) * 11; extraRate = 5.5
                        reason = L.t("Apple PayのMastercardタッチ：通常1.5%＋5.5%。iD・現物タッチ不可。", "Apple Pay Mastercard 感應：基本 1.5%＋加碼 5.5%；不適用 iD 或實體卡感應。")
                    }
                }
                if context.type == .amazonDonation {
                    rate = 1; reason = L.t("Amazonふるさと納税：Primeにかかわらず1%", "Amazon 故鄉納稅：不論 Prime 資格均為 1%")
                }
                if context.type == .utilities { reason = L.t("通常の対象公共料金1%。国民年金等の対象外支払いは含みません。", "一般適用的公共費用 1%，不包含國民年金等不計點項目。") }
            }
            if context.type == .charge { rate = 0; extra = 0; extraRate = 0; reason = L.t("指定の交通系IC等チャージはポイント対象外。", "此處選定的交通 IC 等儲值不列入積分回饋。") }
            let base = Int((Double(safe / unit) * Double(unit) * rate / 100).rounded(.down))
            let manual = context.type == .shopping ? db.campaigns.filter { $0.enabled && $0.cardID == card.id && $0.merchantID == merchant.id && $0.start <= date && date <= $0.end }.map { min($0.cap, Int((Double(safe) * $0.bonus / 100).rounded(.down))) }.max() ?? 0 : 0
            // The documented 7-Eleven benefit and a manual offer are never blindly stacked.
            let bonus = max(extra, manual)
            let displayRate = rate + extraRate
            return Quote(card: card, rate: displayRate, base: base, bonus: bonus, reason: reason)
        }.sorted { $0.total == $1.total ? $0.card.name < $1.card.name : $0.total > $1.total }
    }
}
