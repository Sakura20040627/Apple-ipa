import SwiftUI
import MapKit
import SafariServices

struct WeatherPageContent: View {
    @ObservedObject var model: WeatherModel
    var selectCity: ((Region) -> Void)? = nil
    @State private var cities = false
    @State private var collapsed = false
    @State private var forecastMode = 0
    @State private var map = false
    @State private var settings = false
    @State private var showMap = false
    @State private var webpage: InternalPage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSafety = false
    private var language: String { AppLanguage.code }
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    private var slots: [ForecastSlot] { model.weather?.slots.filter { $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() && $0.date < Date().addingTimeInterval(24*3600) } ?? [] }
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
                WeatherSky(night: night, condition: summary).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        hero.padding(.top, 42).padding(.bottom, 48)
                        forecastCard
                        daysCard
                        DisclosureGroup(isExpanded: $showMap) {
                            Button(t("打开雨云地图", "雨雲マップを開く")) { map = true }.padding(.vertical, 12)
                            if !model.rain.isEmpty { rainCard }
                        } label: { Label(t("雨云地图", "雨雲マップ"), systemImage: "map") }.soraCard().tint(.white)
                        metricGrid
                        DisclosureGroup(isExpanded: $showSafety) {
                            safetyCard.padding(.top, 8)
                        } label: {
                            HStack { Label(t("气象与地震信息", "気象・地震情報"), systemImage: "exclamationmark.shield.fill"); Spacer() }.font(.subheadline)
                        }.tint(.white).padding(16).background(.black.opacity(night ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 28))
                        footer.padding(.vertical, 13)
                        Color.clear.frame(height: 78)
                    }.padding(.horizontal, 20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden).refreshable { await model.refresh() }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 220 } action: { _, value in collapsed = value }
                .overlay(alignment: .top) {
                    if collapsed {
                        VStack(spacing: 3) { Text(model.region.name).font(.system(size: 28, weight: .semibold)); Text(degree(current?.temperature) + " | " + condition(summary)).font(.system(size: 18, weight: .semibold)) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.black.opacity(0.65)).transition(.opacity)
                    }
                }
            }
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) { bottomBar }
            .sheet(isPresented: $cities) { WeatherCities(model: model) }
            .sheet(isPresented: $map) { InternalWeatherMap(region: model.region, temperature: current?.temperature, condition: summary) }
            .sheet(isPresented: $settings) { SettingsView(model: model) }
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
        VStack(spacing: 8) {
            Text(model.region.name).font(.system(size: 34, weight: .medium))
            Text(current?.temperature.map { degree($0) } ?? "—°").font(.system(size: 96, weight: .thin)).tracking(-3).padding(.leading, 10).contentTransition(.numericText())
            HStack(spacing: 18) { highLow(t("最高", "最高"), value: today?.high); highLow(t("最低", "最低"), value: today?.low) }
            Text(condition(summary)).font(.system(size: 21, weight: .semibold))
            if model.loading && model.weather == nil { ProgressView().tint(.white) }
        }.frame(maxWidth: .infinity)
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
                    Text(t("未来24小时", "今後24時間")).font(.system(size: 18, weight: .semibold))
                    Text(forecastMode == 0 ? t("气温 (°C)", "気温 (°C)") : forecastMode == 1 ? t("降水", "降水") : t("风", "風")).font(.system(size: 12))
                }
                Spacer()
                Picker("", selection: $forecastMode) {
                    Image(systemName: "cloud.sun.fill").tag(0)
                    Image(systemName: "drop.fill").tag(1)
                    Image(systemName: "wind").tag(2)
                }.pickerStyle(.segmented).frame(width: 144)
            }
            Divider().overlay(.white.opacity(0.12))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach((forecastMode == 1 && !probabilities.isEmpty ? probabilities : displaySlots).prefix(16)) { slot in
                        VStack(spacing: 18) {
                            Text(slot.date <= Date() ? t("现在", "現在") : format(slot.date, language == "ja" ? "H時" : "H时")).font(.system(size: 15, weight: .semibold))
                            if forecastMode == 2 { Image(systemName: "wind").font(.system(size: 25)).frame(height: 30) }
                            else if forecastMode == 1 { Image(systemName: "drop.fill").foregroundStyle(.cyan).font(.system(size: 25)).frame(height: 30) }
                            else { weatherSymbol(slot.condition, at: slot.date).font(.system(size: 25)).frame(height: 30) }
                            Text(forecastValue(slot)).font(.system(size: 18, weight: .semibold)).foregroundStyle(forecastMode == 1 ? Color.cyan : Color.white).minimumScaleFactor(0.7).lineLimit(1)
                        }.containerRelativeFrame(.horizontal, count: 6, spacing: 0).accessibilityElement(children: .combine)
                    }
                }.padding(.vertical, 4)
            }
            if displaySlots.isEmpty { Text(t("暂无时段数据", "時間帯のデータは未提供です")).font(.subheadline).foregroundStyle(.white.opacity(0.6)) }
        }.soraCard()
    }
    private func forecastValue(_ slot: ForecastSlot) -> String {
        if forecastMode == 2 { return t("未提供", "未提供") }
        if forecastMode == 1 {
            if let probability = slot.probability { return "\(probability)%" }
            if let rain = slot.rainMM { return "\(rain.formatted(.number.precision(.fractionLength(0...1))))mm" }
            return "—"
        }
        return degree(slot.temperature)
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
                    Text(day.low == nil ? "—" : degree(day.low)).foregroundStyle(.white.opacity(0.55)).frame(width: 44, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.55)
                    TemperatureTrack(low: day.low, high: day.high, minimum: minTemp, maximum: maxTemp, current: day.id == today?.id ? current?.temperature : nil).frame(maxWidth: .infinity).frame(height: 6)
                    Text(day.high == nil ? "—" : degree(day.high)).frame(width: 44, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.55)
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
        GlassEffectContainer(spacing: 22) {
            HStack {
                Button { map = true } label: { Image(systemName: "map").font(.system(size: 24, weight: .medium)).frame(width: 50, height: 50) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("地图", "マップ"))
                Spacer(minLength: 10)
                HStack(spacing: 8) {
                    Button { model.locate() } label: { Image(systemName: "location.fill").font(.system(size: 11)).frame(width: 20, height: 42) }.accessibilityLabel(t("定位", "現在地"))
                    ForEach(Region.supported) { region in
                        Button { if let selectCity { selectCity(region) } else { Task { await model.select(region) } } } label: {
                            Circle().fill(.white.opacity(region.id == model.region.id ? 1 : 0.35)).frame(width: 6, height: 6).frame(width: 12, height: 42)
                        }.accessibilityLabel(region.name)
                    }
                }.padding(.horizontal, 12).glassEffect(.regular, in: .capsule)
                Spacer(minLength: 10)
                Button { cities = true } label: { Image(systemName: "list.bullet").font(.system(size: 24, weight: .medium)).frame(width: 50, height: 50) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("城市列表", "都市一覧"))
            }
        }.padding(.horizontal, 24).padding(.bottom, 10).padding(.top, 8)
    }
    private var footer: some View {
        Text(model.weather.map { t("更新于 ", "更新 ") + format($0.fetched, "HH:mm") } ?? t("等待更新", "更新待ち")).font(.caption).foregroundStyle(.white.opacity(0.7))
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
            Divider()
            Text("\(model.region.name) · " + t("府县级气象警报 / 注意报", "府県単位の警報・注意報")).font(.subheadline.weight(.medium))
            if let fetched = model.safety.warningsFetched {
                Text(t("获取", "取得") + " \(stamp(fetched)) JST").font(.caption2).foregroundStyle(.secondary)
                if let issued = model.safety.warningsIssued { Text(t("发布", "発表") + " \(stamp(issued)) JST").font(.caption2).foregroundStyle(.secondary) }
                if model.safety.warnings.isEmpty { Text(t("当前无有效警报记录", "有効な警報の記録はありません。")).font(.caption) }
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
    private func format(_ date: Date, _ pattern: String) -> String { return WeatherDateStrings.string(date, pattern: pattern, language: language) }
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
            .background(reduceTransparency ? Color(red: 0.15, green: 0.25, blue: 0.37) : Color(red: 0.06, green: 0.10, blue: 0.16).opacity(0.8), in: RoundedRectangle(cornerRadius: 28))

            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.035), lineWidth: 0.5))
    }
}
extension View { func soraCard() -> some View { modifier(SoraCard()) } }

private struct WeatherSky: View {
    let night: Bool
    let condition: String
    private var cloudy: Bool { condition.contains("曇") || condition.contains("くもり") || condition.contains("雨") || condition.isEmpty }
    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .top, endPoint: .bottom)
            if night {
                Canvas { context, size in
                    for i in 0..<45 {
                        let x = CGFloat((i*73+19)%997)/997*size.width
                        let y = CGFloat((i*137+41)%769)/769*size.height*0.85
                        let radius: CGFloat = i%7 == 0 ? 1 : 0.6
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius*2, height: radius*2)), with: .color(.white.opacity(cloudy ? 0.22 : 0.55)))
                    }
                }
            }
            if cloudy {
                Canvas { context, size in
                    for i in 0..<5 {
                        let y = size.height*(0.12+Double(i)*0.19)
                        context.fill(Path(ellipseIn: CGRect(x: -size.width*0.2, y: y, width: size.width*1.5, height: max(25,size.height*0.09))), with: .color(.white.opacity(night ? 0.035 : 0.065)))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private var palette: [Color] {
        if night { return [Color(red: 0.025, green: 0.055, blue: 0.14), Color(red: 0.12, green: 0.22, blue: 0.36)] }
        if condition.contains("雪") { return [Color(red: 0.51, green: 0.62, blue: 0.71), Color(red: 0.72, green: 0.77, blue: 0.81)] }
        if cloudy { return [Color(red: 0.44, green: 0.53, blue: 0.62), Color(red: 0.59, green: 0.67, blue: 0.74)] }
        return [Color(red: 0.06, green: 0.35, blue: 0.65), Color(red: 0.36, green: 0.64, blue: 0.83)]
    }
}

private struct WeatherCities: View {
    @ObservedObject var model: WeatherModel
    @State private var settings = false
    @State private var query = ""
    @State private var cache: [String: WeatherSnapshot] = [:]
    @Environment(\.dismiss) private var dismiss
    private var language: String { AppLanguage.code }
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.24, green: 0.28, blue: 0.34).ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        HStack {
                            Text(t("天气", "天気")).font(.system(size: 34, weight: .bold))
                            Spacer()
                            Button { settings = true } label: { Image(systemName: "ellipsis").font(.title2.weight(.bold)).frame(width: 46, height: 46) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("设置", "設定"))
                        }.padding(.bottom, 8)
                        ForEach(Region.supported.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { region in
                            Button { Task { await model.select(region) }; dismiss() } label: {
                                CitySummaryCard(region: region, weather: region.id == model.region.id ? model.weather : cache[region.id], isLocation: region.id == model.region.id && (model.notice.contains("定位至") || model.notice.contains("最寄り")))
                            }.buttonStyle(.plain)
                        }
                        Color.clear.frame(height: 90)
                    }.padding(.horizontal, 16).padding(.top, 12)
                }.scrollIndicators(.hidden)
            }.foregroundStyle(.white)
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.title3.weight(.semibold))
                        TextField(t("搜索城市", "都市を検索"), text: $query).font(.body).autocorrectionDisabled()
                    }.padding(.horizontal, 19).frame(height: 52).glassEffect(.regular, in: .capsule).padding(.horizontal, 24).padding(.bottom, 12)
                }
                .sheet(isPresented: $settings) { SettingsView(model: model) }
                .task {
                    // Read existing snapshots only. Network fetch and merge policy are unchanged.
                    for region in Region.supported {
                        if let value = await WeatherService.shared.cached(region) { cache[region.id] = value }
                    }
                }
        }.preferredColorScheme(.dark)
    }
}
private struct CitySummaryCard: View {
    let region: Region
    let weather: WeatherSnapshot?
    let isLocation: Bool
    private var language: String { AppLanguage.code }
    private var night: Bool { let hour = JapanTime.calendar.component(.hour, from: Date()); return hour < 6 || hour >= 18 }
    private var current: ForecastSlot? { weather?.slots.first { $0.temperature != nil && $0.date <= Date() && $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } }
    private var day: ForecastDay? { weather?.tenDays(from: Date()).first }
    private var description: String {
        let text = current?.condition ?? day?.condition ?? ""
        if text.isEmpty { return language == "ja" ? "更新待ち" : "等待更新" }
        if language == "ja" { return text }
        if text.contains("雪") { return "有雪" }; if text.contains("雨") { return "有雨" }
        if text.contains("晴") && (text.contains("曇") || text.contains("くもり")) { return "晴间多云" }
        return text.contains("晴") ? "晴" : "多云"
    }
    private func degree(_ number: Double?) -> String { number.map { "\(Int($0))°" } ?? "—" }
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(region.name).font(.system(size: 23, weight: .bold))
                Text(isLocation ? (language == "ja" ? "現在地" : "我的位置") : WeatherDateStrings.string(Date(), pattern: "H:mm", language: language)).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 4)
                Text(description).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(degree(current?.temperature)).font(.system(size: 52, weight: .thin)).tracking(-1)
                Spacer(minLength: 0)
                Text((language == "ja" ? "最高" : "最高") + degree(day?.high) + " " + (language == "ja" ? "最低" : "最低") + degree(day?.low)).font(.system(size: 12, weight: .medium))
            }
        }.padding(.horizontal, 18).padding(.vertical, 13).frame(height: 110)
            .background { WeatherSky(night: night, condition: current?.condition ?? day?.condition ?? "") }
            .clipShape(RoundedRectangle(cornerRadius: 28)).foregroundStyle(.white)
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
    let temperature: Double?
    let condition: String
    @State private var camera: MapCameraPosition
    @State private var satellite = false
    @State private var layers = false
    @Environment(\.dismiss) private var dismiss
    init(region: Region, temperature: Double?, condition: String) {
        self.region = region; self.temperature = temperature; self.condition = condition
        _camera = State(initialValue: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude), span: MKCoordinateSpan(latitudeDelta: 0.65, longitudeDelta: 0.65))))
    }
    private var japanese: Bool { AppLanguage.code == "ja" }
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                Annotation(region.name, coordinate: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude), anchor: .bottom) {
                    VStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text(temperature.map { "\(Int($0))°" } ?? "—°").font(.system(size: 26, weight: .bold))
                            Image(systemName: Condition.symbol(condition)).symbolRenderingMode(.multicolor).font(.title3)
                        }.frame(width: 64, height: 64).background(Color(red: 0.4, green: 0.49, blue: 0.61), in: .circle).overlay(Circle().stroke(.black.opacity(0.8), lineWidth: 2))
                        Image(systemName: "arrowtriangle.down.fill").font(.system(size: 12)).foregroundStyle(Color(red: 0.4, green: 0.49, blue: 0.61)).offset(y: -2)
                    }.foregroundStyle(.white)
                }
            }.mapStyle(satellite ? .imagery(elevation: .flat) : .standard(elevation: .flat, emphasis: .muted)).ignoresSafeArea()
            GlassEffectContainer(spacing: 18) {
                HStack(alignment: .top) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).frame(width: 46, height: 46) }.glassEffect(.regular, in: .circle).accessibilityLabel(japanese ? "閉じる" : "关闭")
                    Spacer()
                    VStack(spacing: 0) {
                        Button { layers = true } label: { Image(systemName: "square.3.layers.3d").font(.title3).frame(width: 46, height: 48) }.accessibilityLabel(japanese ? "レイヤー" : "图层")
                        Divider().padding(.horizontal, 11)
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) { camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude), span: MKCoordinateSpan(latitudeDelta: 0.65, longitudeDelta: 0.65))) }
                        } label: { Image(systemName: "location").font(.title3).frame(width: 46, height: 48) }.accessibilityLabel(japanese ? "予報地点に戻る" : "返回预报地点")
                    }.frame(width: 46).glassEffect(.regular, in: .capsule)
                }
            }.padding(.horizontal, 18).padding(.top, 12)
            // No map-layer payload exists in the current model. Do not create a fake legend, rain overlay or playback timeline from point forecasts.
        }.preferredColorScheme(.dark)
            .confirmationDialog(japanese ? "地図の種類" : "地图图层", isPresented: $layers) {
                Button(japanese ? "標準地図" : "标准地图") { satellite = false }
                Button(japanese ? "衛星画像" : "卫星地图") { satellite = true }
                Button(japanese ? "キャンセル" : "取消", role: .cancel) {}
            }
    }
}

@MainActor private enum WeatherDateStrings {
    static var formatters: [String: DateFormatter] = [:]
    static func string(_ date: Date, pattern: String, language: String) -> String {
        let key = language + pattern
        if let f = formatters[key] { return f.string(from: date) }
        let f = DateFormatter(); f.locale = Locale(identifier: language); f.timeZone = JapanTime.calendar.timeZone; f.dateFormat = pattern
        formatters[key] = f; return f.string(from: date)
    }
}
struct WeatherView: View {
    @ObservedObject var model: WeatherModel
    @State private var selected: String
    init(model: WeatherModel) { self.model = model; _selected = State(initialValue: model.region.id) }
    var body: some View {
        TabView(selection: $selected) {
            ForEach(Region.supported) { region in
                CityWeatherPage(region: region, active: selected == region.id) { selected = $0.id }.tag(region.id)
            }
        }.tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selected) { _, id in
                UserDefaults.standard.set(id, forKey: "region")
                if let region = Region.supported.first(where: { $0.id == id }) { Task { await model.select(region) } }
            }
            .onChange(of: model.region.id) { _, id in if selected != id { selected = id } }
    }
}
private struct CityWeatherPage: View {
    @StateObject private var model: WeatherModel
    let region: Region
    let active: Bool
    let select: (Region) -> Void
    init(region: Region, active: Bool, select: @escaping (Region) -> Void) {
        _model = StateObject(wrappedValue: WeatherModel(initialRegion: region)); self.region = region; self.active = active; self.select = select
    }
    var body: some View {
        WeatherPageContent(model: model, selectCity: select)
            .task(id: active) {
                if active {
                    if model.region.id != region.id { await model.select(region) } else { await model.refresh() }
                }
            }
            .onChange(of: model.region.id) { _, _ in if active { select(model.region) } }
    }
}
