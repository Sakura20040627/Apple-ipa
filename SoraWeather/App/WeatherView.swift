import SwiftUI
import MapKit
import SafariServices

struct WeatherView: View {
    @ObservedObject var model: WeatherModel
    @State private var cities = false
    @State private var collapsed = false
    @State private var forecastMode = 0
    @State private var map = false
    @State private var webpage: InternalPage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSafety = false
    @AppStorage("language") private var language = "zh-Hans"
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    private var slots: [ForecastSlot] { model.weather?.slots.filter { $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } ?? [] }
    private var temperatureSlots: [ForecastSlot] { slots.filter { $0.temperature != nil } }
    private var displaySlots: [ForecastSlot] { temperatureSlots.isEmpty ? slots : temperatureSlots }
    private var current: ForecastSlot? { temperatureSlots.first { $0.date <= Date() && $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } }
    private var today: ForecastDay? { model.weather?.tenDays(from: Date()).first }
    private var summary: String { current?.condition ?? today?.condition ?? "" }
    private var days: [ForecastDay] { model.weather?.tenDays(from: Date()) ?? [] }
    private var night: Bool { let h = JapanTime.calendar.component(.hour, from: Date()); return h < 6 || h >= 18 }
    private var probabilities: [ForecastSlot] { slots.filter { $0.probability != nil } }
    private var minTemp: Double { days.compactMap(\.low).min() ?? 0 }
    private var maxTemp: Double { days.compactMap(\.high).max() ?? 30 }
    var body: some View {
        NavigationStack {
            ZStack {
                WeatherSky(night: night, rainy: summary.contains("雨"))
                ScrollView {
                    VStack(spacing: 10) {
                        hero.padding(.top, 42).padding(.bottom, 48).contentShape(Rectangle()).gesture(citySwipe)
                        if model.weather == nil && !model.loading { status(t("暂时无法取得天气，下拉重试", "下に引いて再試行してください"), symbol: "wifi.slash") }
                        if model.cached || model.weather?.stale(at: Date()) == true { status(t("缓存预报 · 请核对发布时间", "キャッシュ予報 · 発表時刻をご確認ください"), symbol: "clock.arrow.circlepath") }
                        if !model.notice.isEmpty { Text(model.notice).font(.caption2).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center).padding(.bottom, 4) }
                        forecastCard
                        daysCard.contentShape(Rectangle()).gesture(citySwipe)
                        if !model.rain.isEmpty { rainCard }
                        metricGrid.contentShape(Rectangle()).gesture(citySwipe)
                        DisclosureGroup(isExpanded: $showSafety) {
                            safetyCard.padding(.top, 8)
                        } label: {
                            HStack { Label(t("气象与地震信息", "気象・地震情報"), systemImage: "exclamationmark.shield.fill"); Spacer(); Text(t("非实时", "速報ではありません")).font(.caption2).foregroundStyle(.white.opacity(0.6)) }.font(.subheadline)
                        }.tint(.white).padding(16).background(.black.opacity(night ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 20))
                        footer.padding(.vertical, 13)
                    }.padding(.horizontal, 20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden).refreshable { await model.refresh() }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 220 } action: { _, value in collapsed = value }
                .overlay(alignment: .top) {
                    if collapsed {
                        VStack(spacing: 3) { Text(model.region.name).font(.system(size: 28, weight: .semibold)); Text(degree(current?.temperature) + " | " + condition(summary)).font(.system(size: 18, weight: .semibold)) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(.ultraThinMaterial).transition(.opacity)
                    }
                }
            }
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .sheet(isPresented: $cities) { WeatherCities(model: model) }
            .sheet(isPresented: $map) { InternalWeatherMap(region: model.region) }
            .sheet(item: $webpage) { InternalBrowser(url: $0.url) }
            .environment(\.openURL, OpenURLAction { url in webpage = InternalPage(url: url); return .handled })

        }.preferredColorScheme(.dark)
    }
    private var citySwipe: some Gesture {
        DragGesture(minimumDistance: 25).onEnded { value in
            guard abs(value.translation.width) > 65, abs(value.translation.width) > abs(value.translation.height)*1.6 else { return }
            let regions = Region.supported
            guard let index = regions.firstIndex(where: { $0.id == model.region.id }) else { return }
            let next = index + (value.translation.width < 0 ? 1 : -1)
            guard regions.indices.contains(next) else { return }
            collapsed = false
            Task { await model.select(regions[next]) }
        }
    }
    private var hero: some View {
        VStack(spacing: 5) {
            Label(t("我的位置", "現在地"), systemImage: "location.fill").font(.system(size: 12, weight: .semibold))
            Text(model.region.name).font(.system(size: 34, weight: .medium))
            Text(degree(current?.temperature)).font(.system(size: 96, weight: .light)).tracking(-3).padding(.leading, 10).contentTransition(.numericText())
            HStack(spacing: 16) {
                highLow(t("最高", "最高"), value: today?.high)
                highLow(t("最低", "最低"), value: today?.low)
            }
            Text(condition(summary)).font(.system(size: 21, weight: .semibold)).padding(.top, 3)
            Text(t("时段预报 · 非实测", "時間帯の予報 · 実況ではありません")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
        }.frame(maxWidth: .infinity).shadow(color: .black.opacity(0.12), radius: 7, y: 2)
    }
    private func highLow(_ label: String, value: Double?) -> some View {
        HStack(spacing: 3) {
            Text(label.map(String.init).joined(separator: "\n")).font(.system(size: 15, weight: .medium)).lineSpacing(-3)
            Text(degree(value)).font(.system(size: 37, weight: .regular))
        }
    }
    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(t("天气状况", "天気の状況")).font(.system(size: 18, weight: .semibold))
                    Text(forecastMode == 0 ? t("气温 (°C)", "気温 (°C)") : t("降水概率 (%)", "降水確率 (%)")).font(.system(size: 12))
                }
                Spacer()
                Picker("", selection: $forecastMode) {
                    Image(systemName: "cloud.sun.fill").tag(0)
                    Image(systemName: "drop.fill").tag(1)
                }.pickerStyle(.segmented).frame(width: 122)
            }
            Divider().overlay(.white.opacity(0.12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 19) {
                    ForEach((forecastMode == 0 ? displaySlots : probabilities).prefix(16)) { slot in
                        VStack(spacing: 22) {
                            Text(slot.id == current?.id ? t("当前", "現在") : format(slot.date, "H時")).font(.system(size: 17, weight: .semibold))
                            weatherSymbol(slot.condition, at: slot.date).font(.system(size: 27)).frame(height: 32)
                            if let temperature = slot.temperature { Text(degree(temperature)).font(.system(size: 20, weight: .medium)) }
                            else { Text(slot.probability.map { "\($0)%" } ?? "—").font(.system(size: 18, weight: .medium)).foregroundStyle(.cyan) }
                        }.frame(minWidth: 42).accessibilityElement(children: .combine)
                    }
                }.padding(.vertical, 1)
            }
            if displaySlots.isEmpty { Text(t("暂无时段数据", "時間帯のデータは未提供です")).font(.subheadline).foregroundStyle(.white.opacity(0.6)) }
        }.soraCard()
    }
    private var forecastSummary: String {
        if model.weather == nil { return t("正在获取天气预报…", "天気予報を取得中…") }
        if let wet = temperatureSlots.first(where: { ($0.rainMM ?? 0) >= 0.5 }) {
            return t("\(format(wet.date, "d日H时"))起的预报时段可能有雨。", "\(format(wet.date, "d日H時"))以降の予報に雨が含まれています。")
        }
        return t("\(condition(today?.condition ?? ""))。\(nextDayText)", "\(condition(today?.condition ?? ""))。\(nextDayText)")
    }
    private var nextDayText: String {
        guard days.count > 1, let high = days[1].high else { return t("下拉可更新天气。", "下に引いて更新できます。") }
        return t("明天最高气温 \(degree(high))。", "明日の最高気温は\(degree(high))。")
    }
    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("10日预报", "10日間の予報")).font(.caption).foregroundStyle(.white.opacity(0.55))
            ForEach(days) { day in
                Divider().overlay(.white.opacity(0.08))
                HStack(spacing: 10) {
                    Text(dayName(day.date)).font(.system(size: 19, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7).frame(width: 56, alignment: .leading)
                    VStack(spacing: 2) {
                        Image(systemName: day.condition.isEmpty ? "minus" : Condition.symbol(day.condition)).symbolRenderingMode(.multicolor).font(.system(size: 20))
                        if let probability = day.probability { Text("\(probability)%").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(red: 0.46, green: 0.83, blue: 1)) }
                    }.frame(width: 30, height: 39)
                    Text(degree(day.low)).foregroundStyle(.white.opacity(0.55)).frame(width: 33, alignment: .trailing)
                    TemperatureTrack(low: day.low, high: day.high, minimum: minTemp, maximum: maxTemp, current: day.id == today?.id ? current?.temperature : nil).frame(maxWidth: .infinity).frame(height: 6)
                    Text(degree(day.high)).frame(width: 33, alignment: .trailing)
                }.font(.system(size: 20, weight: .medium)).monospacedDigit().frame(minHeight: 44)
                .accessibilityElement(children: .ignore).accessibilityLabel("\(dayName(day.date)) \(day.condition.isEmpty ? t("未提供", "未提供") : condition(day.condition)) \(degree(day.low))—\(degree(day.high))")
            }
            if days.isEmpty { Text(t("等待预报数据", "予報データを取得中")).font(.subheadline).padding(.vertical, 12) }
        }.soraCard()
    }
    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            metric(t("降水概率", "降水確率"), icon: "drop.fill", value: probabilities.first?.probability.map { "\($0)%" } ?? "—", note: probabilities.first.map { t("\(format($0.date, "H时"))起 6 小时", "\(format($0.date, "H時"))から6時間") } ?? t("来源未提供", "未提供"))
            metric(t("降水量", "降水量"), icon: "drop.degreesign.fill", value: current?.rainMM.map { "\($0.formatted(.number.precision(.fractionLength(0...1))))" } ?? "—", note: t("mm · 当前 3 小时预报", "mm · 現在の3時間予報"))
            metric(t("日温差", "気温差"), icon: "thermometer.medium", value: temperatureDifference, note: t("今日最高与最低之差", "今日の最高と最低の差"))
            metric(t("预报更新", "予報の発表"), icon: "clock", value: model.weather.map { format($0.issued, "HH:mm") } ?? "—", note: model.weather.map { "\($0.source) · \(format($0.issued, "M/d")) JST" } ?? t("等待更新", "更新待ち"))
        }
    }
    private var temperatureDifference: String { guard let high = today?.high, let low = today?.low else { return "—" }; return degree(high-low) }
    private func metric(_ title: String, icon: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(title, symbol: icon)
            Text(value).font(.system(size: 34, weight: .regular)).minimumScaleFactor(0.65).lineLimit(1)
            Spacer(minLength: 0)
            Text(note).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 119, alignment: .topLeading).soraCard()
    }
    private var rainCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            cardTitle(t("未来一小时降雨强度", "1時間先までの降水強度"), symbol: "cloud.rain.fill")
            ForEach(Array(model.rain.filter { $0.forecast && $0.date > Date() }.enumerated()), id: \.offset) { _, point in
                HStack {
                    Text(format(point.date, "HH:mm")).font(.caption).frame(width: 45, alignment: .leading)
                    GeometryReader { g in Capsule().fill(.cyan).frame(width: max(2, g.size.width*min(point.intensity/10, 1))) }.frame(height: 5)
                    Text("\(point.intensity.formatted(.number.precision(.fractionLength(0...1)))) mm/h").font(.caption).frame(width: 76, alignment: .trailing)
                }
            }
        }.soraCard()
    }
    private var bottomBar: some View {
        HStack {
            Button { map = true } label: { Image(systemName: "map").font(.system(size: 24, weight: .medium)).frame(width: 48, height: 48) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("天气地图", "天気マップ"))
            Spacer()
            HStack(spacing: 8) {
                ForEach(Region.supported) { region in
                    Button { Task { await model.select(region) } } label: {
                        Circle().fill(.white.opacity(region.id == model.region.id ? 1 : 0.35)).frame(width: 6, height: 6).frame(width: 12, height: 36)
                    }.accessibilityLabel(region.name)
                }
            }.padding(.horizontal, 12).glassEffect(.regular, in: .capsule)
            Spacer()
            Button { cities = true } label: { Image(systemName: "list.bullet").font(.system(size: 24, weight: .medium)).frame(width: 48, height: 48) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("城市与设置", "都市と設定"))
        }.padding(.horizontal, 26).padding(.vertical, 9)
    }
    private var footer: some View {
        VStack(spacing: 5) {
            Text(t("3 小时时段预报 · 未提供日期留空", "3時間ごとの予報 · 未提供の日は空欄"))
            if model.fallback { Text(t("Yahoo 暂不可用 · 已切换 JMA", "Yahoo取得不可 · JMAを使用")) }
            HStack(spacing: 14) {
                Link("Yahoo! JAPAN / Weather Map", destination: model.region.yahooURL)
                Link(t("气象厅（经整理）", "気象庁（加工）"), destination: URL(string: "https://www.jma.go.jp/bosai/")!)
            }
        }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
    }
    private func weatherSymbol(_ text: String, at date: Date) -> some View {
        let h = JapanTime.calendar.component(.hour, from: date)
        let symbol = Condition.symbol(text)
        let name = (h < 6 || h >= 18) ? symbol.replacingOccurrences(of: "sun.max", with: "moon").replacingOccurrences(of: "cloud.sun", with: "cloud.moon") : symbol
        return Image(systemName: name).symbolRenderingMode(.multicolor)
    }
    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            cardTitle(t("防灾信息", "防災情報"), symbol: "exclamationmark.shield")
            Text(t("非实时紧急预警", "リアルタイムの緊急速報ではありません")).font(.caption).foregroundStyle(.orange.opacity(0.95))
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
    private func dayName(_ date: Date) -> String { JapanTime.calendar.isDate(date, inSameDayAs: Date()) ? t("今天", "今日") : format(date, "EEEE") }
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

private struct TemperatureTrack: View {
    let low: Double?
    let high: Double?
    let minimum: Double
    let maximum: Double
    let current: Double?
    var body: some View {
        GeometryReader { geometry in
            let total = max(maximum-minimum, 1)
            let start = min(max(((low ?? minimum)-minimum)/total, 0), 1)
            let end = min(max(((high ?? minimum)-minimum)/total, start), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.14))
                if low != nil && high != nil {
                    Capsule().fill(LinearGradient(colors: [.cyan, Color(red: 0.54, green: 0.83, blue: 0.56), .yellow.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geometry.size.width*(end-start))).offset(x: geometry.size.width*start)
                    if let current {
                        let position = min(max((current-minimum)/total, start), end)
                        Circle().fill(.white).frame(width: 5, height: 5).overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 1)).offset(x: max(0, geometry.size.width*position-2.5))
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
private struct SoraCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.padding(15)
            .background(reduceTransparency ? Color(red: 0.15, green: 0.25, blue: 0.37) : Color(red: 0.29, green: 0.38, blue: 0.47).opacity(0.68), in: RoundedRectangle(cornerRadius: 20))

            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.035), lineWidth: 0.5))
    }
}
extension View { func soraCard() -> some View { modifier(SoraCard()) } }

private struct WeatherSky: View {
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let night: Bool
    let rainy: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: night ? [Color(red: 0.035, green: 0.085, blue: 0.19), Color(red: 0.12, green: 0.23, blue: 0.39), Color(red: 0.23, green: 0.36, blue: 0.49)] : [Color(red: 0.56, green: 0.64, blue: 0.71), Color(red: 0.52, green: 0.61, blue: 0.69), Color(red: 0.48, green: 0.57, blue: 0.65)], startPoint: .top, endPoint: .bottom)
            if night {
                Canvas { context, size in
                    for i in 0..<57 {
                        let x = CGFloat((i*73+19)%997)/997*size.width
                        let y = CGFloat((i*137+41)%769)/769*size.height*0.76
                        let r: CGFloat = i%7 == 0 ? 1.1 : 0.65
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r*2, height: r*2)), with: .color(.white.opacity(i%3 == 0 ? 0.55 : 0.28)))
                    }
                }
                Circle().fill(Color(red: 0.91, green: 0.94, blue: 0.97).opacity(0.8)).frame(width: 44, height: 44).blur(radius: 0.8).offset(x: 114, y: -230)
                Circle().fill(.white.opacity(0.12)).frame(width: 130, height: 130).blur(radius: 30).offset(x: 114, y: -230)
            }
            GeometryReader { g in
                ZStack {
                    Ellipse().fill(.white.opacity(night ? 0.07 : 0.14)).frame(width: g.size.width*1.6, height: 105).blur(radius: 22).offset(x: -70, y: g.size.height*0.38)
                    Ellipse().fill(.white.opacity(night ? 0.045 : 0.09)).frame(width: g.size.width*1.5, height: 140).blur(radius: 30).offset(x: 70, y: g.size.height*0.65)
                }
            }
            if rainy { Color.gray.opacity(0.14) }
        }.drawingGroup().ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)

    }
}

private struct WeatherCities: View {
    @ObservedObject var model: WeatherModel
    @State private var settings = false
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @AppStorage("language") private var language = "zh-Hans"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    ForEach(Region.supported.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { region in
                        Button {
                            Task { await model.select(region) }; dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(region.name).font(.system(size: 28, weight: .semibold))
                                    Text(region.id == model.region.id ? (language == "ja" ? "選択中の都市" : "当前城市") : (language == "ja" ? "タップして予報を表示" : "轻点查看预报")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                                }
                                Spacer()
                                if region.id == model.region.id {
                                    VStack(alignment: .trailing, spacing: 15) {
                                        Text(model.weather?.slots.first(where: { $0.temperature != nil && $0.date <= Date() && $0.date.addingTimeInterval(10800) > Date() })?.temperature.map { "\(Int($0))°" } ?? "—").font(.system(size: 48, weight: .light))
                                        if let day = model.weather?.tenDays(from: Date()).first { Text("↑ \(day.high.map { String(Int($0)) } ?? "—")° ↓ \(day.low.map { String(Int($0)) } ?? "—")°").font(.subheadline) }
                                    }
                                }
                            }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                                .background(LinearGradient(colors: [Color(red: 0.17, green: 0.32, blue: 0.53), Color(red: 0.37, green: 0.55, blue: 0.71)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }.padding(18)
            }.background(Color(red: 0.32, green: 0.36, blue: 0.41))
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: language == "ja" ? "都市を検索" : "搜索城市")
                .navigationTitle(language == "ja" ? "天気" : "天气")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button(language == "ja" ? "完了" : "完成") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel(language == "ja" ? "設定" : "设置") }
                }.sheet(isPresented: $settings) { SettingsView(model: model) }
        }.preferredColorScheme(.dark)
    }
}

struct InternalPage: Identifiable { let id = UUID(); let url: URL }
struct InternalBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
private struct InternalWeatherMap: View {
    let region: Region
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))) {
                Marker(region.name, coordinate: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude))
            }.mapStyle(.standard(elevation: .realistic))
                .safeAreaInset(edge: .bottom) { Text("预报区域地图 · 暂无雷达图层 / 予報エリア・雨雲レイヤー未提供").font(.caption).padding().frame(maxWidth: .infinity).background(.regularMaterial) }
                .navigationTitle(region.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成 / 完了") { dismiss() } } }
        }
    }
}
