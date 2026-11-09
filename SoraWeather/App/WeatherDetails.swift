import SwiftUI

struct AstronomyCard: View {
    let value: LocalAstronomy
    private func t(_ zh: String, _ ja: String) -> String { AppLanguage.code == "ja" ? ja : zh }
    private let symbols = ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"]
    private var phaseName: String {
        let zh = ["新月", "娥眉月", "上弦月", "盈凸月", "满月", "亏凸月", "下弦月", "残月"]
        let ja = ["新月", "三日月", "上弦の月", "満ちていく月", "満月", "欠けていく月", "下弦の月", "有明月"]
        return AppLanguage.code == "ja" ? ja[value.moonPhase] : zh[value.moonPhase]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("日出日落与月相", "日の出・日の入りと月")).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.65))
            HStack(alignment: .top) {
                event(t("日出", "日の出"), symbol: "sunrise.fill", date: value.sunrise)
                Spacer()
                event(t("日落", "日の入り"), symbol: "sunset.fill", date: value.sunset)
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: symbols[value.moonPhase]).symbolRenderingMode(.hierarchical).font(.title2)
                    Text(phaseName).font(.subheadline.weight(.medium))
                    Text("\(Int((value.illumination*100).rounded()))%").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
            }
        }.soraCard().accessibilityElement(children: .contain).accessibilityIdentifier("astronomyCard")
    }
    private func event(_ title: String, symbol: String, date: Date) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.title2)
            Text(date, style: .time).font(.title3.weight(.medium)).monospacedDigit().environment(\.timeZone, JapanTime.calendar.timeZone)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.65))
        }
    }
}
struct WarningBanner: View {
    let items: [DisasterItem]
    let action: () -> Void
    private var level: WarningLevel { items.map { WarningLevel.level(for: $0) }.max() ?? .advisory }
    private var title: String {
        let ja = AppLanguage.code == "ja"
        switch level {
        case .special: return ja ? "特別警報" : "特别警报"
        case .warning: return ja ? "気象警報" : "气象警报"
        case .advisory: return ja ? "気象注意報" : "气象注意报"
        }
    }
    static func color(_ level: WarningLevel) -> Color {
        switch level { case .advisory: return .yellow; case .warning: return Color(red: 0.9, green: 0.25, blue: 0.12); case .special: return Color(red: 0.68, green: 0.12, blue: 0.5) }
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("JMA · " + title).font(.subheadline.weight(.semibold))
                    Text(AppLanguage.code == "ja" ? "府県単位 · \(items.count)件" : "府县范围 · \(items.count)条").font(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.padding(13).foregroundStyle(level == .advisory ? Color.black : Color.white)
                .background(Self.color(level), in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityLabel("JMA，" + title + "，\(items.count)" + (AppLanguage.code == "ja" ? "件・府県単位" : "条，府县范围")).accessibilityHint(AppLanguage.code == "ja" ? "防災情報を開く" : "打开灾害预警详情").accessibilityIdentifier("warningBanner")
    }
}
