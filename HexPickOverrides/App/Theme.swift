import SwiftUI
import UIKit
import HexPickCore

/// Semantic tokens: all text uses dynamic colors and scalable system typography.
enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let background = adaptive(0xF1F4F8, 0x0B111C)
    static let surface = adaptive(0xFFFFFF, 0x172231)
    static let text = adaptive(0x152235, 0xF1F5FA)
    static let secondary = adaptive(0x4E5E72, 0xB4C2D4)
    static let gold = adaptive(0x765200, 0xF1CA73)
    static let blue = adaptive(0x005D86, 0x73D4FA)
    static let positive = adaptive(0x14683F, 0x7DE2AE)
    static let negative = adaptive(0xAF263F, 0xFF9BAC)
    static let silver = adaptive(0x4B6079, 0xBDCDE3)
    static let prismatic = adaptive(0x7145AB, 0xD6B4FF)
    enum Space { static let small: CGFloat = 8; static let medium: CGFloat = 16; static let large: CGFloat = 24 }
    enum Radius { static let card: CGFloat = 24; static let small: CGFloat = 14 }
    enum TypeScale {
        static let title: Font = .largeTitle.bold()
        static let section: Font = .title2.bold()
        static let body: Font = .body
        static let number: Font = .title2.weight(.bold).monospacedDigit()
    }
    static func winColor(_ rate: Double?) -> Color {
        guard let rate else { return secondary }
        return rate > 0.5 ? positive : (rate < 0.5 ? negative : secondary)
    }
    static func rarityColor(_ rarity: String) -> Color {
        switch rarity { case "gold": return gold; case "prismatic": return prismatic; default: return silver }
    }
    static func rarityName(_ rarity: String) -> String {
        switch rarity { case "silver": return "白银"; case "gold": return "黄金"; case "prismatic": return "棱彩"; default: return "未分类" }
    }
    static func rarityGradient(_ rarity: String) -> LinearGradient {
        let c = rarityColor(rarity)
        return LinearGradient(colors: [surface, c.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let rarityOrder = ["silver", "gold", "prismatic"]
}

struct HexCard: ViewModifier {
    var rarity: String? = nil
    func body(content: Content) -> some View {
        content.padding(Theme.Space.medium)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.rarityGradient(rarity ?? ""))
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(rarity.map(Theme.rarityColor) ?? Theme.secondary.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}
extension View {
    func hexCard(rarity: String? = nil) -> some View { modifier(HexCard(rarity: rarity)) }
    func hexBackground() -> some View {
        background(Theme.background).scrollContentBackground(.hidden).foregroundStyle(Theme.text)
    }
}
func compactCount(_ count: Int) -> String {
    if count >= 100_000_000 { return String(format: "%.1f亿", Double(count) / 100_000_000) }
    if count >= 10_000 { return String(format: "%.1f万", Double(count) / 10_000) }
    return count.formatted()
}
/// Presentation-only 95% Wilson lower bound; never used by RecommendationEngine.
func wilsonLower(_ stat: Stat?) -> Double? {
    guard let stat, stat.games > 0 else { return nil }
    let n = Double(stat.games), p = Double(stat.wins) / n, z = 1.959963984540054
    return (p + z*z/(2*n) - z * sqrt(p*(1-p)/n + z*z/(4*n*n))) / (1 + z*z/n)
}

struct RankBadge: View {
    let rank: Int?
    var body: some View {
        Text(rank.map { "#\($0)" } ?? "—")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(rank == 1 ? Theme.gold : Theme.text)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((rank == 1 ? Theme.gold : rank == 2 ? Theme.silver : rank == 3 ? Theme.prismatic : Theme.secondary).opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(rank == 1 ? Theme.gold : rank == 2 ? Theme.silver : rank == 3 ? Theme.prismatic : .clear))
            .accessibilityLabel(rank.map { "排名第 \($0) 名" } ?? "暂无排名")
    }
}
struct WinRateView: View {
    let rate: Double?
    var title = "胜率"
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(percent(rate)).font(Theme.TypeScale.number).foregroundStyle(Theme.winColor(rate))
                if differentiate, let rate {
                    Image(systemName: rate > 0.5 ? "arrow.up" : rate < 0.5 ? "arrow.down" : "equal")
                        .font(.caption).foregroundStyle(Theme.winColor(rate))
                }
            }
            GeometryReader { geometry in
                Capsule().fill(Theme.secondary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.winColor(rate)).frame(width: geometry.size.width * min(1, max(0, rate ?? 0)))
                    }
            }.frame(width: 72, height: 5).accessibilityHidden(true)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title)，\(percent(rate))")
    }
}
struct LoadingSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("正在载入攻略").font(.title2.bold())
            ForEach(0..<4) { _ in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16).frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 12) {
                        Capsule().frame(width: 150, height: 16)
                        Capsule().frame(width: 100, height: 12)
                    }
                    Spacer()
                }.foregroundStyle(Theme.secondary.opacity(0.2)).hexCard()
            }
        }.padding(20).opacity(reduceMotion ? 1 : pulse ? 0.65 : 1)
            .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } } }
            .accessibilityElement(children: .ignore).accessibilityLabel("正在载入攻略数据，请稍候")
    }
}
