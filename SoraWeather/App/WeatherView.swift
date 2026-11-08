import SwiftUI
import UIKit
import Combine
import MapKit
import SafariServices

struct WeatherPageContent: View {
    @ObservedObject var model: WeatherModel
    var selectCity: ((String) -> Void)? = nil
    var requestLocation: (() -> Void)? = nil
    var cityID: String = CityPersistence.locationID
    var isActive: Bool = true
    @ObservedObject private var cityStore = CityStore.shared
    @State private var cities = false
    @State private var collapsed = false
    @State private var forecastMode = 0
    @State private var map = false
    @State private var settings = false
    @State private var showMap = false
    @State private var webpage: InternalPage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSafety = false
    @State private var showWarning = false
    @State private var refreshFeedback = 0
    #if DEBUG
    @State private var refreshTestState = "idle"
    #endif
    private var language: String { AppLanguage.code }
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    private var slots: [ForecastSlot] { model.weather?.slots.filter { $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() && $0.date < Date().addingTimeInterval(24*3600) } ?? [] }
    private var temperatureSlots: [ForecastSlot] { slots.filter { $0.temperature != nil } }
    private var displaySlots: [ForecastSlot] { temperatureSlots.isEmpty ? slots : temperatureSlots }
    private var current: ForecastSlot? { temperatureSlots.first { $0.date <= Date() && $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } }
    private var today: ForecastDay? { days.first { JapanTime.calendar.isDateInToday($0.date) } }
    private var summary: String { current?.condition ?? today?.condition ?? "" }
    private var days: [ForecastDay] { model.weather?.sevenDays(from: Date()) ?? [] }
    private var night: Bool { let h = JapanTime.calendar.component(.hour, from: Date()); return h < 6 || h >= 18 }
    private var displayWarnings: [DisasterItem] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-warning") { return [DisasterItem(id: "test-special", title: "JMA 大雨特別警報 · 発表", detail: "UI regression fixture", issued: Date())] }
        #endif
        return model.safety.warnings
    }
    private var probabilities: [ForecastSlot] { slots.filter { $0.probability != nil } }
    private var minTemp: Double { days.compactMap(\.low).min() ?? 0 }
    private var maxTemp: Double { days.compactMap(\.high).max() ?? 30 }
    var body: some View {
            ZStack {
                WeatherSky(night: night, condition: summary).equatable().ignoresSafeArea(.all)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        hero.padding(.top, 42).padding(.bottom, 48)
                        forecastCard
                        daysCard
                        if let value = LocalAstronomy.calculate(date: Date(), latitude: model.region.latitude, longitude: model.region.longitude) { AstronomyCard(value: value) }
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

                    }.padding(.horizontal, 20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }.contentMargins(.bottom, 110, for: .scrollContent).scrollIndicators(.hidden).refreshable { await pullRefresh() }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 220 } action: { _, value in collapsed = value }
                .overlay(alignment: .top) {
                    if collapsed {
                        VStack(spacing: 3) { Text(model.region.name).font(.system(size: 28, weight: .semibold)); Text(degree(current?.temperature) + " | " + condition(summary)).font(.system(size: 18, weight: .semibold)) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.black.opacity(0.65)).transition(.opacity)
                    }
                }
            }
            .background { if isActive { WindowSkyBackground(color: SkyAppearance.colors(condition: summary, night: night)[0]).allowsHitTesting(false) } }
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) { bottomBar.frame(height: 68) }
            .sheet(isPresented: $cities) { WeatherCities(model: model, selectCity: selectCity, requestLocation: requestLocation).presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28) }
            .fullScreenCover(isPresented: $map) { InternalWeatherMap(region: model.region, temperature: current?.temperature, condition: summary) }
            .sheet(isPresented: $showWarning) { WarningDetails(region: model.region, items: displayWarnings, fetched: model.safety.warningsFetched) }
            .sheet(isPresented: $settings) { SettingsView(model: model, onLocate: requestLocation) }
            .sheet(item: $webpage) { InternalBrowser(url: $0.url) }
            .environment(\.openURL, OpenURLAction { url in webpage = InternalPage(url: url); return .handled })
            .preferredColorScheme(.dark).tint(.white)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: refreshFeedback)
            .overlay(alignment: .topLeading) {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test-manual-network") { Text(refreshTestState).font(.caption2).accessibilityIdentifier("pullRefreshState") }
                #endif
            }
    }
    private func pullRefresh() async {
        #if DEBUG
        refreshTestState = "loading"
        defer { refreshTestState = "complete" }
        // Keep the offline UI suite offline for manual refreshes too.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") && !ProcessInfo.processInfo.arguments.contains("--ui-test-manual-network") {
            await Task.yield(); refreshFeedback += 1; return
        }
        #endif
        await model.refresh(); refreshFeedback += 1
    }
    private var hero: some View {
        VStack(spacing: 8) {
            Text(model.region.name).font(.system(size: 34, weight: .medium)).accessibilityIdentifier("cityTitle." + model.region.id)
            if !displayWarnings.isEmpty { WarningBanner(items: displayWarnings) { showWarning = true }.padding(.vertical, 6) }
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
                    Text(forecastMode == 0 ? t("气温 (°C)", "気温 (°C)") : t("降水", "降水")).font(.system(size: 12))
                }
                Spacer()
                Picker("", selection: $forecastMode) {
                    Image(systemName: "cloud.sun.fill").tag(0).accessibilityLabel(t("天气", "天気"))
                    Image(systemName: "drop.fill").tag(1).accessibilityLabel(t("降水", "降水"))
                }.pickerStyle(.segmented).frame(width: 104)
            }
            Divider().overlay(.white.opacity(0.12))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach((forecastMode == 1 && !probabilities.isEmpty ? probabilities : displaySlots).prefix(16)) { slot in
                        VStack(spacing: 18) {
                            Text(slot.date <= Date() ? t("现在", "現在") : format(slot.date, language == "ja" ? "H時" : "H时")).font(.system(size: 15, weight: .semibold))
                            if forecastMode == 1 { Image(systemName: "drop.fill").foregroundStyle(.cyan).font(.system(size: 25)).frame(height: 30) }
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
        guard let tomorrow = JapanTime.calendar.date(byAdding: .day, value: 1, to: Date()), let high = days.first(where: { $0.id == JapanTime.key(tomorrow) })?.high else { return t("下拉可更新天气。", "下に引いて更新できます。") }
        return t("明天最高气温 \(degree(high))。", "明日の最高気温は\(degree(high))。")
    }
    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("7日预报", "7日間の予報")).font(.caption).foregroundStyle(.white.opacity(0.55))
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
                Button { map = true } label: { Image(systemName: "map").font(.system(size: 24, weight: .medium)).frame(width: 50, height: 50) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("地图", "マップ")).accessibilityIdentifier("openMap")
                Spacer(minLength: 10)
                HStack(spacing: 8) {
                    Button { if let requestLocation { requestLocation() } else { model.locate() } } label: { Image(systemName: "location.fill").font(.system(size: 11)).frame(width: 20, height: 42) }.accessibilityLabel(t("定位", "現在地"))
                    if cityStore.cities.count > 6 {
                        Text("\((cityStore.cities.firstIndex { $0.id == cityID } ?? 0) + 1)/\(cityStore.cities.count)").font(.caption.weight(.semibold)).monospacedDigit().accessibilityIdentifier("cityPageCounter")
                    } else {
                        ForEach(cityStore.cities) { city in
                            Button { selectCity?(city.id) } label: {
                                Circle().fill(.white.opacity(city.id == cityID ? 1 : 0.35)).frame(width: 6, height: 6).frame(width: 12, height: 42)
                            }.accessibilityLabel(city.region.name)
                        }
                    }
                }.padding(.horizontal, 12).frame(minHeight: 42).glassEffect(.regular, in: .capsule)
                Spacer(minLength: 10)
                Button { cities = true } label: { Image(systemName: "list.bullet").font(.system(size: 24, weight: .medium)).frame(width: 50, height: 50) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("城市列表", "都市一覧")).accessibilityIdentifier("openCities")
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

private struct WeatherSky: View, Equatable {
    let night: Bool
    let condition: String
    var body: some View {
        ZStack {
            LinearGradient(colors: SkyAppearance.colors(condition: condition, night: night), startPoint: .top, endPoint: .bottom)
            if night { Image(uiImage: SkyAppearance.stars).resizable().scaledToFill().clipped().opacity(condition.contains("雨") ? 0.4 : 1) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct WeatherCities: View {
    @ObservedObject var model: WeatherModel
    var selectCity: ((String) -> Void)? = nil
    var requestLocation: (() -> Void)? = nil
    @ObservedObject private var store = CityStore.shared
    @State private var settings = false
    @State private var query = ""
    @State private var editMode: EditMode = .inactive
    @State private var cache: [String: WeatherSnapshot] = [:]
    @State private var places: [Region] = []
    @State private var searching = false
    @State private var searchMessage = ""
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    private var language: String { AppLanguage.code }
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    var body: some View {
        NavigationStack {
            ZStack {
                WeatherSky(night: JapanTime.calendar.component(.hour, from: Date()) < 6 || JapanTime.calendar.component(.hour, from: Date()) >= 18, condition: "").ignoresSafeArea(.all)
                VStack(spacing: 0) {
                    HStack {
                        Text(t("天气", "天気")).font(.system(size: 34, weight: .bold))
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 40, height: 40) }.glassEffect(.regular, in: .circle).accessibilityIdentifier("closeCities")
                        if editMode.isEditing { Button(t("完成", "完了")) { editMode = .inactive }.accessibilityIdentifier("finishEditingCities") }
                        Menu {
                            Button(t("编辑", "編集")) { editMode = .active }
                            Button(t("设置", "設定")) { settings = true }
                        } label: { Image(systemName: "ellipsis").font(.title2.weight(.bold)).frame(width: 46, height: 46) }.glassEffect(.regular, in: .circle).accessibilityIdentifier("cityMenu")
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
                    List {
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            ForEach(store.cities) { city in
                                Button { choose(city.id) } label: {
                                    CitySummaryCard(region: city.region, weather: city.region.id == model.region.id ? (model.weather ?? cache[city.region.id]) : cache[city.region.id], isLocation: city.isLocation)
                                }.buttonStyle(.plain).deleteDisabled(city.isLocation).moveDisabled(city.isLocation)
                                    .accessibilityIdentifier("cityRow." + city.region.id)
                                    .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }.onDelete(perform: store.remove).onMove(perform: store.move)
                        } else {
                            Section(t("JMA 预报区", "JMA予報区")) {
                                ForEach(Array(store.matches(query).prefix(30))) { region in searchRow(region) }
                            }
                            if searching { ProgressView(t("搜索中", "検索中")) }
                            if !places.isEmpty { Section(t("附近可用预报区", "最寄りの予報区")) { ForEach(places) { region in searchRow(region) } } }
                            if !searchMessage.isEmpty { Text(searchMessage).font(.subheadline).foregroundStyle(.white.opacity(0.8)) }
                            Button(t("搜索地名", "地名を検索")) { startSearch() }.accessibilityIdentifier("searchPlace")
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden).environment(\.editMode, $editMode)
                        .listRowSeparator(.hidden)
                        .contentMargins(.bottom, 16, for: .scrollContent).scrollDismissesKeyboard(.interactively)
                }
            }.foregroundStyle(.white).toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.title3.weight(.semibold))
                        TextField(t("搜索城市", "都市を検索"), text: $query, prompt: Text(t("搜索城市", "都市を検索")).foregroundStyle(.white.opacity(0.55))).font(.system(size: 17)).autocorrectionDisabled().submitLabel(.search).onSubmit { startSearch() }.accessibilityIdentifier("citySearch")
                    }.padding(.horizontal, 17).frame(height: 50).glassEffect(.regular, in: .capsule).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                }
                .sheet(isPresented: $settings) { SettingsView(model: model, onLocate: requestLocation) }
                .onChange(of: query) { _, _ in searchTask?.cancel(); searching = false; places = []; searchMessage = store.matches(query).isEmpty && !query.isEmpty ? t("没有匹配的预报区，可点搜索地名查找45km内的区域。", "一致する予報区はありません。地名検索で45km以内の予報区を探せます。") : "" }
                .onDisappear { searchTask?.cancel() }
                .task { for city in store.cities { if let value = await WeatherService.shared.cached(city.region) { cache[city.region.id] = value } } }
        }.preferredColorScheme(.dark).tint(.white)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: store.mutationFeedback)
    }
    private func choose(_ id: String) { store.select(id); selectCity?(id); dismiss() }
    private func searchRow(_ region: Region) -> some View {
        Button {
            store.add(region); choose(store.selectedID)
        } label: { HStack { VStack(alignment: .leading) { Text(region.name); Text("JMA · " + region.forecastArea).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "plus.circle.fill") } }.accessibilityIdentifier("addCity." + region.id)
    }
    private func startSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }
        searchTask?.cancel(); searching = true; places = []; searchMessage = ""
        searchTask = Task { @MainActor in
            let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
            request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36, longitude: 138), span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18))
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
                var seen = Set<String>(); var matches: [Region] = []
                for item in response.mapItems.prefix(20) {
                    let point = item.placemark.coordinate
                    guard let base = store.nearby(latitude: point.latitude, longitude: point.longitude) else { continue }
                    let id = "place-\(base.office)-\(String(format: "%.3f-%.3f", point.latitude, point.longitude))"
                    guard seen.insert(id).inserted else { continue }
                    matches.append(Region(id: id, name: item.name ?? base.name, latitude: point.latitude, longitude: point.longitude, yahooPath: base.yahooPath, pinpoint: base.pinpoint, office: base.office, forecastArea: base.forecastArea, station: base.station))
                }
                places = matches
                if matches.isEmpty { searchMessage = t("该地点45km内没有可用JMA预报区，请换一个城市名。", "45km以内に利用可能なJMA予報区がありません。別の地名をお試しください。") }
            } catch {
                if !Task.isCancelled { searchMessage = t("地名搜索暂不可用，请选择上方JMA预报区或稍后重试。", "地名検索を利用できません。上のJMA予報区を選ぶか、後でお試しください。") }
            }
            if !Task.isCancelled { searching = false }
        }
    }
}

private struct CitySummaryCard: View {
    let region: Region
    let weather: WeatherSnapshot?
    let isLocation: Bool
    private var language: String { AppLanguage.code }
    private var night: Bool { let hour = JapanTime.calendar.component(.hour, from: Date()); return hour < 6 || hour >= 18 }
    private var current: ForecastSlot? { weather?.slots.first { $0.temperature != nil && $0.date <= Date() && $0.date.addingTimeInterval(Double($0.durationHours)*3600) > Date() } }
    private var day: ForecastDay? { weather?.sevenDays(from: Date()).first { JapanTime.key($0.date) == JapanTime.key(Date()) } }
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
    @ObservedObject private var store = CityStore.shared
    @State private var pool = WeatherPagePool()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        NavigationStack {
            NativeCityPager(ids: store.cities.map(\.id), selected: store.selectedID, backdropModel: pool.model(for: store.selected), select: { store.select($0) }) { id in
                guard let city = store.cities.first(where: { $0.id == id }) else { return AnyView(Color.clear) }
                return AnyView(RetainedCityPage(city: city, model: pool.model(for: city), active: store.selectedID == city.id, locate: { model.locate(); store.select(CityPersistence.locationID) }) { store.select($0) }.id(city.id))
            }.ignoresSafeArea(.all)
                .toolbar(.hidden, for: .navigationBar)
        }.preferredColorScheme(.dark)
            .background(Color("LaunchBackground").ignoresSafeArea(.all))
            .sensoryFeedback(.selection, trigger: store.selectionFeedback)
            .onAppear { store.select(store.selectedID); pool.prune(cities: store.cities, selected: store.selectedID) }
            .onChange(of: store.selectedID) { _, _ in pool.prune(cities: store.cities, selected: store.selectedID) }
            .onChange(of: store.cities) { _, _ in pool.prune(cities: store.cities, selected: store.selectedID) }
            .onChange(of: model.locatedRegion) { _, region in if let region { store.updateRegion(region, for: CityPersistence.locationID) } }
            .onChange(of: phase) { _, value in if value == .active { refreshSelected() } }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SoraWeatherRefresh"))) { _ in refreshSelected() }
    }
    private func refreshSelected() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") { return }
        #endif
        let value = pool.model(for: store.selected); Task { await value.refresh(); await value.updateReminders() }
    }
}
private struct PageRefreshIdentity: Equatable {
    let active: Bool
    let region: Region
}
private struct RetainedCityPage: View {
    let city: SavedCity
    @ObservedObject var model: WeatherModel
    let active: Bool
    let locate: () -> Void
    let select: (String) -> Void
    #if DEBUG
    @State private var refreshScope = "pending"
    #endif
    var body: some View {
        WeatherPageContent(model: model, selectCity: select, requestLocation: locate, cityID: city.id, isActive: active)
            .task(id: PageRefreshIdentity(active: active, region: city.region)) {
                if active {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-location-change") { refreshScope = city.region.id }
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") { return }
                    #endif
                    await model.refresh()
                }
            }
            .overlay(alignment: .topTrailing) {
                #if DEBUG
                if active && ProcessInfo.processInfo.arguments.contains("--ui-test-location-change") {
                    VStack {
                        Button("Simulate Tokyo") { CityStore.shared.updateRegion(Region.supported[1], for: CityPersistence.locationID) }.accessibilityIdentifier("testLocationTokyo")
                        Text(refreshScope).accessibilityIdentifier("forecastLoadScope")
                    }.font(.caption).padding(8).background(.black).padding(.top, 110)
                }
                #endif
            }
            .onChange(of: model.locatedRegion) { _, region in if let region { CityStore.shared.updateRegion(region, for: CityPersistence.locationID) } }
            .onChange(of: model.region.id) { _, _ in if active { CityStore.shared.updateRegion(model.region, for: city.id) } }
    }
}

// Stable UIKit page controllers avoid replacing the pager's children when the retained model set changes.
private struct NativeCityPager: UIViewControllerRepresentable {
    let ids: [String]
    let selected: String
    let backdropModel: WeatherModel
    let select: (String) -> Void
    let content: (String) -> AnyView
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let page = SkyPageController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        page.paint(backdropModel)
        page.view.clipsToBounds = true
        for scroll in page.view.subviews.compactMap({ $0 as? UIScrollView }) { scroll.bounces = ids.count > 1; scroll.isScrollEnabled = ids.count > 1; scroll.backgroundColor = .clear }
        page.dataSource = context.coordinator; page.delegate = context.coordinator
        if ids.contains(selected) { page.setViewControllers([context.coordinator.controller(selected)], direction: .forward, animated: false) }
        return page
    }
    func updateUIViewController(_ page: UIPageViewController, context: Context) {
        (page as? SkyPageController)?.paint(backdropModel)
        for scroll in page.view.subviews.compactMap({ $0 as? UIScrollView }) { scroll.bounces = ids.count > 1; scroll.isScrollEnabled = ids.count > 1; scroll.backgroundColor = .clear }
        let coordinator = context.coordinator
        let changedOrder = coordinator.parent.ids != ids
        coordinator.parent = self
        for (id, host) in coordinator.hosts where ids.contains(id) { host.rootView = content(id) }
        guard !coordinator.transitioning, ids.contains(selected) else { return }
        let visible = page.viewControllers?.first.flatMap { coordinator.id(of: $0) }
        if visible != selected || changedOrder {
            let direction: UIPageViewController.NavigationDirection = (ids.firstIndex(of: selected) ?? 0) >= (visible.flatMap { ids.firstIndex(of: $0) } ?? 0) ? .forward : .reverse
            page.setViewControllers([coordinator.controller(selected)], direction: direction, animated: false)
        }
        coordinator.trim()
    }
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: NativeCityPager
        var hosts: [String: UIHostingController<AnyView>] = [:]
        var transitioning = false
        init(_ parent: NativeCityPager) { self.parent = parent }
        func id(of controller: UIViewController) -> String? { hosts.first { $0.value === controller }?.key }
        func controller(_ id: String) -> UIHostingController<AnyView> {
            if let host = hosts[id] { return host }
            let host = UIHostingController(rootView: parent.content(id)); host.view.backgroundColor = .clear
            hosts[id] = host; return host
        }
        func trim() {
            guard let index = parent.ids.firstIndex(of: parent.selected) else { return }
            let keep = Set(parent.ids.indices.filter { abs($0-index) <= 1 }.map { parent.ids[$0] })
            hosts = hosts.filter { keep.contains($0.key) }
        }
        func neighbor(_ controller: UIViewController, offset: Int) -> UIViewController? {
            guard let id = id(of: controller), let index = parent.ids.firstIndex(of: id), parent.ids.indices.contains(index+offset) else { return nil }
            return self.controller(parent.ids[index+offset])
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? { neighbor(viewController, offset: -1) }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? { neighbor(viewController, offset: 1) }
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) { transitioning = true }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            transitioning = false
            if completed, let visible = pageViewController.viewControllers?.first, let id = id(of: visible) { parent.select(id) }
        }
    }
}

@MainActor private final class SkyPageController: UIPageViewController {
    private let sky = CAGradientLayer()
    private let stars = CALayer()
    override func viewDidLoad() {
        super.viewDidLoad(); view.layer.insertSublayer(sky, at: 0); view.layer.insertSublayer(stars, at: 1)
        stars.contentsGravity = .resizeAspectFill; stars.masksToBounds = true
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true); sky.frame = view.bounds; stars.frame = view.bounds; CATransaction.commit()
    }
    func paint(_ model: WeatherModel) {
        loadViewIfNeeded()
        let now = Date(), hour = JapanTime.calendar.component(.hour, from: now), night = hour < 6 || hour >= 18
        let condition = model.weather?.slots.first { $0.date <= now && $0.date.addingTimeInterval(Double($0.durationHours)*3600) > now && !$0.condition.isEmpty }?.condition ?? model.weather?.sevenDays(from: now).first?.condition ?? ""
        let colors = SkyAppearance.colors(condition: condition, night: night).map { UIColor($0) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        sky.colors = colors.map(\.cgColor); stars.contents = night ? SkyAppearance.stars.cgImage : nil
        stars.opacity = condition.contains("雨") ? 0.4 : 1; view.backgroundColor = colors[0]
        CATransaction.commit()
    }
}
