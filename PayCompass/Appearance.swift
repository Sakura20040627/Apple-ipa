import SwiftUI

enum L {
    static var isChinese: Bool {
        let value = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        return value == "zh-Hant" || (value == "system" && (Locale.preferredLanguages.first ?? "ja").hasPrefix("zh"))
    }
    static func t(_ ja: String, _ zh: String) -> String { isChinese ? zh : ja }
    static func category(_ value: String) -> String {
        let zh = ["すべて":"全部", "コンビニ":"便利商店", "スーパー":"超市", "飲食":"餐飲", "ドラッグストア":"藥妝", "ショッピング":"購物", "家電":"家電", "オンライン":"網路購物", "その他":"其他", "カフェ":"咖啡廳", "百貨店":"百貨公司"]
        return isChinese ? (zh[value] ?? value) : value
    }
    static var categories: [String] { ["すべて", "コンビニ", "スーパー", "飲食", "カフェ", "ドラッグストア", "ショッピング", "家電", "百貨店", "オンライン", "その他"] }
}
enum AppTheme: String, CaseIterable, Identifiable {
    case sakura, ocean, jade, violet, amber, coral, midnight, graphite
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .sakura: Color(hex: "CE447B")
        case .ocean: Color(hex: "217CC2")
        case .jade: Color(hex: "14856D")
        case .violet: Color(hex: "7961CE")
        case .amber: Color(hex: "A56B09")
        case .coral: Color(hex: "C34C3E")
        case .midnight: Color(hex: "475DA4")
        case .graphite: Color(hex: "68717A")
        }
    }
    var name: String {
        switch self {
        case .sakura: L.t("桜ピンク", "櫻花粉")
        case .ocean: L.t("オーシャン", "海洋藍")
        case .jade: L.t("翡翠", "翡翠綠")
        case .violet: L.t("バイオレット", "紫羅蘭")
        case .amber: L.t("アンバー", "琥珀金")
        case .coral: L.t("コーラル", "珊瑚橘")
        case .midnight: L.t("ミッドナイト", "午夜藍")
        case .graphite: L.t("グラファイト", "石墨黑")
        }
    }
}
extension Color {
    init(hex: String) {
        let value = UInt64(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xCE447B
        self.init(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255)
    }
}
struct MerchantBadge: View {
    let merchant: Merchant
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let asset = BrandAssets.image(for: merchant) {
                Image(asset).resizable().scaledToFit().background(.white)
            } else {
                Image(systemName: "storefront.fill").resizable().scaledToFit().padding(size * 0.22).foregroundStyle(.secondary).background(.quaternary)
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22)).accessibilityHidden(true)
    }
}
struct CardThumbnail: View {
    @EnvironmentObject private var store: Store
    let card: Card
    var width: CGFloat = 64
    var body: some View {
        Image(card.kind == "amazon" ? (store.db.prime ? "CardAmazonPrime" : "CardAmazon") : (["CardPayPayBlack", "CardPayPayLavender", "CardPayPayBlue", "CardPayPayPink"].contains(card.artworkVariant ?? "") ? card.artworkVariant! : "CardPayPayBlack"))
            .resizable().scaledToFit().frame(width: width).accessibilityLabel(card.name)
    }
}
struct CardArtwork: View {
    let card: Card
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardThumbnail(card: card, width: 280).frame(maxWidth: .infinity)
            Text(card.name).font(.title3.bold())
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
