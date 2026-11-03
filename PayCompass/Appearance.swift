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
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27).fill(Color(hex: merchant.color ?? "68717A").gradient)
            if let icon = merchant.icon, !icon.isEmpty {
                Text(icon).font(.system(size: icon.count > 4 ? size * 0.19 : size * 0.27, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5).padding(5).foregroundStyle(.white)
            } else { Image(systemName: categorySymbol).font(.system(size: size * 0.43)).foregroundStyle(.white) }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
    private var categorySymbol: String {
        switch merchant.category {
        case "飲食": "fork.knife"
        case "カフェ": "cup.and.saucer.fill"
        case "スーパー": "cart.fill"
        case "ドラッグストア": "cross.case.fill"
        case "家電": "desktopcomputer"
        default: "storefront.fill"
        }
    }
}
struct CardArtwork: View {
    let card: Card
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Image(systemName: "wave.3.right").font(.title2); Spacer(); Text("櫻卡").font(.headline) }
            Text(card.name).font(.title2.bold()).lineLimit(2).minimumScaleFactor(0.7)
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading) { Text(L.t("基本還元", "基本回饋")).font(.caption); Text("\(card.rate, specifier: "%.1f")%").font(.system(.largeTitle, design: .rounded).bold()) }
                Spacer()
                Text(card.brands ?? "CARD").font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
            }
        }.padding(22).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: card.color ?? "CE447B"), Color(hex: card.color ?? "CE447B").mix(with: .black, by: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
        .overlay(alignment: .topTrailing) { Circle().stroke(.white.opacity(0.12), lineWidth: 35).frame(width: 130, height: 130).offset(x: 25, y: -55).clipped() }.clipShape(RoundedRectangle(cornerRadius: 26))
    }
}
