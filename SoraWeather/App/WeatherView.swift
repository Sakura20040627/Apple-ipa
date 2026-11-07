import SwiftUI

struct WeatherView: View {
    @ObservedObject var model: WeatherModel
    @State private var settings = false
    @AppStorage("language") private var language = "zh-Hans"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    private var slots: [ForecastSlot] { model.weather?.slots.filter { $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } ?? [] }
    private var today: ForecastDay? { model.weather?.tenDays(from: Date()).first }
    private var summary: String { today?.condition ?? "" }
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.10, blue: 0.25), Color(red: 0.16, green: 0.29, blue: 0.48), Color(red: 0.37, green: 0.46, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                GeometryReader { g in
                    Circle().fill(.white.opacity(0.10)).frame(width: 230).blur(radius: 28).offset(x: g.size.width*0.48, y: 70)
                    Circle().fill(.cyan.opacity(0.08)).frame(width: 320).blur(radius: 60).offset(x: -130, y: 360)
                }.allowsHitTesting(false).accessibilityHidden(true)
                ScrollView {
                    VStack(spacing: 18) {
                        hero.padding(.vertical, 12)
                        if !model.notice.isEmpty { status(model.notice, symbol: "location.fill") }
                        if model.weather == nil && !model.loading { status(t("暂时无法取得天气，下拉重试", "天気を取得できません。下に引いて再試行"), symbol: "wifi.slash") }
                        if model.cached { status(t("离线缓存 · 请核对发布时间", "キャッシュ表示 · 発表時刻をご確認ください"), symbol: "clock.arrow.circlepath") }
                        if model.fallback { status(t("Yahoo 暂不可用，已尝试 JMA 备用数据", "Yahoo取得不可 · JMAの予報を使用します"), symbol: "arrow.triangle.2.circlepath") }
                        if model.weather?.stale(at: Date()) == true { status(t("预报已过期，请勿据此判断当前天气", "予報が古くなっています。現在の状況とは異なる場合があります"), symbol: "exclamationmark.triangle.fill") }
                        forecastCard
                        if !model.rain.isEmpty { rainCard }
                        daysCard
                        safetyCard
                        footer
                    }.padding(.horizontal, 20).padding(.bottom, 24).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }.refreshable { await model.refresh() }
            }
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Text("SORA").font(.system(.caption, design: .rounded).weight(.semibold)).tracking(4).foregroundStyle(.white.opacity(0.8)) }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.loading { ProgressView().tint(.white).accessibilityLabel(t("更新中", "更新中")) }
                    Button { model.locate() } label: { Image(systemName: "location") }.accessibilityLabel(t("使用当前位置", "現在地を使用"))
                    Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel(t("设置", "設定"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $settings) { SettingsView(model: model) }
        }.preferredColorScheme(.dark)
    }
    private var hero: some View {
        VStack(spacing: 5) {
            Label(model.region.name, systemImage: "location.fill").font(.title2.weight(.medium))
            Text(t("地区预报", "地域の予報")).font(.caption).foregroundStyle(.white.opacity(0.7))
            Image(systemName: Condition.symbol(summary)).symbolRenderingMode(.multicolor).font(.system(size: 62)).padding(.top, 18).accessibilityHidden(true)
            Text(range(today)).font(.system(size: 66, weight: .thin, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
            Text(condition(summary)).font(.title3).foregroundStyle(.white.opacity(0.9))
            Text(t("最低 / 最高 · 预报气温", "最低 / 最高 · 予想気温")).font(.caption).foregroundStyle(.white.opacity(0.65))
            if let w = model.weather { Text("\(w.source) · \(t("发布", "発表")) \(stamp(w.issued)) JST").font(.caption2).foregroundStyle(.white.opacity(0.65)).padding(.top, 10) }
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(t("逐小时", "時間ごと"), symbol: "clock")
            Text(t("Yahoo 为 3 小时预报与 6 小时降雨概率，JMA 为 6 小时降雨概率；未提供逐小时值。", "Yahooは3時間予報と6時間降水確率、JMAは6時間降水確率です。1時間値は未提供です。")).font(.caption).foregroundStyle(.white.opacity(0.75))
            if slots.isEmpty { Text(t("此来源暂未提供时段数据", "時間帯のデータは未提供です")).font(.subheadline) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(slots) { slot in
                        VStack(spacing: 9) {
                            Text(shortTime(slot.date)).font(.caption.weight(.medium))
                            Image(systemName: Condition.symbol(slot.condition)).symbolRenderingMode(.multicolor).font(.title3).frame(height: 28)
                            Text(slot.temperature.map { "\(Int($0))°" } ?? "—").font(.title3.weight(.medium))
                            Text(slot.probability.map { "\($0)%" } ?? slot.rainMM.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) mm" } ?? "—").font(.caption2).foregroundStyle(.cyan.opacity(0.9))
                            Text("\(slot.durationHours)h").font(.caption2).foregroundStyle(.white.opacity(0.55))
                        }.frame(minWidth: 46).accessibilityElement(children: .combine)
                    }
                }
            }
        }.soraCard()
    }
    private var rainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(t("未来一小时降雨强度", "1時間先までの降水強度"), symbol: "cloud.rain")
            ForEach(Array(model.rain.filter { $0.forecast && $0.date > Date() }.enumerated()), id: \.offset) { _, point in
                HStack {
                    Text(shortTime(point.date)).font(.caption).frame(width: 58, alignment: .leading)
                    GeometryReader { g in Capsule().fill(.cyan.opacity(0.8)).frame(width: max(2, g.size.width * min(point.intensity/10, 1))) }.frame(height: 5)
                    Text("\(point.intensity.formatted(.number.precision(.fractionLength(0...1)))) mm/h").font(.caption.monospacedDigit()).frame(width: 78, alignment: .trailing)
                }
            }
            Text("Yahoo! JAPAN · " + t("预报可能变化", "予測は変わる場合があります")).font(.caption2).foregroundStyle(.secondary)
        }.soraCard()
    }
    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(t("10 日预报", "10日間の予報"), symbol: "calendar")
            Text(t("免费来源目前通常覆盖 7–8 日，未提供的日期留空。", "無料データは通常7〜8日分です。未提供の日は空欄です。")).font(.caption).foregroundStyle(.white.opacity(0.7))
            if let w = model.weather {
                ForEach(w.tenDays(from: Date())) { day in
                    HStack(spacing: 12) {
                        Text(dayName(day.date)).font(.subheadline).frame(width: 58, alignment: .leading)
                        Image(systemName: day.condition.isEmpty ? "minus" : Condition.symbol(day.condition)).symbolRenderingMode(.multicolor).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.condition.isEmpty ? t("未提供", "未提供") : condition(day.condition)).font(.caption).lineLimit(2)
                            if let probability = day.probability { Text("\(probability)%").font(.caption2).foregroundStyle(.cyan) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(degree(day.low)).foregroundStyle(.white.opacity(0.65))
                        Capsule().fill(LinearGradient(colors: [.cyan.opacity(0.8), .orange.opacity(0.85)], startPoint: .leading, endPoint: .trailing)).frame(width: 42, height: 4).opacity(day.high == nil ? 0.2 : 1).accessibilityHidden(true)
                        Text(degree(day.high)).frame(minWidth: 30, alignment: .trailing)
                    }.font(.subheadline.monospacedDigit()).padding(.vertical, 5).accessibilityElement(children: .combine)
                    if day.id != w.tenDays(from: Date()).last?.id { Divider().overlay(.white.opacity(0.08)) }
                }
            }
        }.soraCard()
    }
    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            cardTitle(t("防灾信息", "防災情報"), symbol: "exclamationmark.shield")
            Text(t("非实时紧急预警", "リアルタイムの緊急速報ではありません")).font(.headline).foregroundStyle(.orange.opacity(0.95))
            Text(t("气象与地震信息仅在刷新时获取，可能延迟或缺失。请保留 iPhone 系统紧急警报；本 App 不发送地震预警或避难指示。", "気象・地震情報は更新時に取得し、遅延や欠落があります。iPhoneの緊急速報を有効にしてください。本アプリは緊急地震速報や避難指示を配信しません。")).font(.caption).foregroundStyle(.white.opacity(0.8))
            Divider()
            Text("\(model.region.name) · " + t("府县级气象警报 / 注意报", "府県単位の警報・注意報")).font(.subheadline.weight(.medium))
            if let fetched = model.safety.warningsFetched {
                Text(t("获取", "取得") + " \(stamp(fetched)) JST").font(.caption2).foregroundStyle(.secondary)
                if let issued = model.safety.warningsIssued { Text(t("发布", "発表") + " \(stamp(issued)) JST").font(.caption2).foregroundStyle(.secondary) }
                if model.safety.warnings.isEmpty { Text(t("本次响应未列出有效警报；不代表当前安全，请核对官方页面。", "今回の応答に有効な警報はありません。安全を保証するものではありません。公式情報をご確認ください。")).font(.caption) }
                ForEach(model.safety.warnings) { item in itemView(item) }
            } else { Text(t("气象警报获取失败 / 尚未刷新", "警報情報は未取得です")).font(.caption) }
            Divider()
            Text(t("日本近期地震（全国）", "最近の地震（全国）")).font(.subheadline.weight(.medium))
            if let fetched = model.safety.quakesFetched {
                Text(t("获取", "取得") + " \(stamp(fetched)) JST").font(.caption2).foregroundStyle(.secondary)
                ForEach(model.safety.quakes.prefix(4)) { item in itemView(item) }
                if model.safety.quakes.isEmpty { Text(t("本次响应无地震记录", "今回の応答に地震記録はありません")).font(.caption) }
            } else { Text(t("地震信息获取失败 / 尚未刷新", "地震情報は未取得です")).font(.caption) }
            Link(t("打开 JMA 官方防灾信息", "気象庁の防災情報を開く"), destination: URL(string: "https://www.jma.go.jp/bosai/")!).font(.subheadline)
        }.soraCard()
    }
    private var footer: some View {
        VStack(spacing: 8) {
            Text(t("下拉刷新 · 无广告 · 无需 Yahoo 账号", "下に引いて更新 · 広告なし · Yahooログイン不要")).font(.caption)
            if let fetched = model.weather?.fetched { Text(t("获取于", "取得") + " \(stamp(fetched)) JST").font(.caption2) }
            Link("Yahoo! JAPAN / Weather Map", destination: model.region.yahooURL)
            Link(t("来源：气象厅（经本 App 整理）", "出典：気象庁（本アプリで加工）"), destination: URL(string: "https://www.jma.go.jp/bosai/")!)
        }.font(.caption2).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center).padding(.top, 4)
    }
    private func itemView(_ item: DisasterItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.subheadline)
            Text(item.detail).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(stamp(item.issued) + " JST").font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 3)
    }
    private func cardTitle(_ title: String, symbol: String) -> some View { Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.65)) }
    private func status(_ text: String, symbol: String) -> some View { Label(text, systemImage: symbol).font(.caption).frame(maxWidth: .infinity, alignment: .leading).soraCard() }
    private func degree(_ v: Double?) -> String { v.map { "\(Int($0))°" } ?? "—" }
    private func range(_ day: ForecastDay?) -> String { "\(degree(day?.low)) / \(degree(day?.high))" }
    private func stamp(_ date: Date) -> String { format(date, "M/d HH:mm") }
    private func shortTime(_ date: Date) -> String { format(date, "d日 HH:mm") }
    private func dayName(_ date: Date) -> String { JapanTime.calendar.isDate(date, inSameDayAs: Date()) ? t("今天", "今日") : format(date, "M/d E") }
    private func format(_ date: Date, _ pattern: String) -> String { let f = DateFormatter(); f.locale = Locale(identifier: language); f.timeZone = JapanTime.calendar.timeZone; f.dateFormat = pattern; return f.string(from: date) }
    private func condition(_ s: String) -> String {
        guard !s.isEmpty else { return t("等待天气数据", "データ取得待ち") }
        if language == "ja" { return s }
        if s.contains("天気コード") { return s.replacingOccurrences(of: "天気コード", with: "天气代码") }
        // Preserve source wording in Japanese in the safety section; summarize only weather labels.
        if s.contains("雪") { return "有雪" }; if s.contains("雨") { return "有雨" }
        if s.contains("晴") && (s.contains("曇") || s.contains("くもり")) { return "晴间多云" }
        if s.contains("晴") { return "晴" }; return "多云"
    }
}
private struct SoraCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency { content.padding(16).background(Color(red: 0.14, green: 0.22, blue: 0.34), in: RoundedRectangle(cornerRadius: 24)) }
        else { content.padding(16).glassEffect(.regular, in: .rect(cornerRadius: 24)) }
    }
}
extension View { func soraCard() -> some View { modifier(SoraCard()) } }
