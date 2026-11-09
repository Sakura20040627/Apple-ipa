import SwiftUI

struct DisasterWarningsView: View {
    let region: Region
    let condition: String
    let cityID: String
    let selectCity: (String) -> Void
    @ObservedObject private var center = SafetyCenter.shared
    @ObservedObject private var cities = CityStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var expanded = Set<String>()
    @State private var source = false
    @State private var feedback = 0
    private func t(_ zh: String, _ ja: String) -> String { AppLanguage.code == "ja" ? ja : zh }
    private var record: SafetyRecord { center.record(region) }
    private var night: Bool { let hour = JapanTime.calendar.component(.hour, from: Date()); return hour < 6 || hour >= 18 }
    private var otherCities: [SavedCity] { cities.cities.filter { $0.id != cityID && !center.record($0.region).warnings.isEmpty } }
    private var quakeRecord: SafetyRecord { center.records.values.filter { $0.quakesFetched != nil }.max { ($0.quakesFetched ?? .distantPast) < ($1.quakesFetched ?? .distantPast) } ?? record }
    private var scope: String {
        let names = ["270000": "大阪府", "130000": "東京都", "260000": "京都府", "280000": "兵庫県", "230000": "愛知県", "400000": "福岡県"]
        let name = names[region.office] ?? "JMA \(region.office)"
        return name + t(" · 府县范围", " · 府県単位")
    }
    var body: some View {
        ZStack {
            WeatherSky(night: night, condition: condition).ignoresSafeArea(.all)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text(t("灾害预警", "防災情報")).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader).accessibilityIdentifier("safetyTitle")
                    Text(t("当前城市", "現在の都市") + " · " + region.name).font(.title2.bold()).accessibilityIdentifier("safetyCityName").accessibilityAddTraits(.isHeader)
                    if record.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(t("当前没有生效的警报", "現在、有効な警報はありません"), systemImage: "checkmark.shield").font(.headline)
                            Text(record.warningsFetched == nil ? t("尚未取得最新资料，请下拉刷新。", "最新情報は未取得です。下に引いて更新してください。") : scope).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        }.frame(maxWidth: .infinity, alignment: .leading).soraCard().accessibilityElement(children: .combine).accessibilityIdentifier("safetyEmpty")
                    }
                    ForEach(WarningLevel.allCases.reversed(), id: \.rawValue) { level in
                        let items = record.warnings.filter { WarningLevel.level(for: $0) == level }
                        if !items.isEmpty {
                            Text(level.name).font(.headline).foregroundStyle(WarningBanner.color(level)).accessibilityAddTraits(.isHeader)
                            ForEach(items) { warning in warningRow(warning, level: level) }
                        }
                    }
                    Text(t("其他城市", "ほかの都市")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    if otherCities.isEmpty { Text(t("其他已保存城市暂无警报记录", "保存したほかの都市に警報の記録はありません")).font(.subheadline).soraCard() }
                    ForEach(otherCities) { city in otherRow(city) }
                    Text(t("最近地震", "最近の地震")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    if quakeRecord.quakes.isEmpty { Text(t("暂无地震资料，请下拉刷新", "地震情報は未取得です。下に引いて更新してください")).font(.subheadline).soraCard() }
                    if quakeRecord.quakesOffline, let date = quakeRecord.quakesFetched {
                        Text(t("地震：离线数据，更新于 ", "地震：オフライン情報・更新 ") + stamp(date)).font(.caption).foregroundStyle(.white.opacity(0.75))
                    }
                    ForEach(quakeRecord.quakes.prefix(10)) { item in quakeRow(item) }
                    Button { source = true } label: {
                        Label(t("以气象厅发布为准", "気象庁の発表をご確認ください"), systemImage: "arrow.up.right.square").font(.footnote).fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.7)).accessibilityHint(t("在应用内打开 JMA 官方防灾资料", "アプリ内で気象庁の防災情報を開きます"))
                }.padding(.horizontal, 20).padding(.top, 16).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.contentMargins(.bottom, 110, for: .scrollContent).scrollIndicators(.hidden)
                .refreshable { await refresh(); feedback += 1 }
        }.safeAreaInset(edge: .top, spacing: 0) { controls }
            .foregroundStyle(.white).tint(.white).preferredColorScheme(.dark)
            .task(id: region.office) { await refresh() }
            .sheet(isPresented: $source) { InternalBrowser(url: URL(string: "https://www.jma.go.jp/bosai/")!) }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: feedback)
    }
    private var controls: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).frame(width: 46, height: 46) }.glassEffect(.regular, in: .circle).accessibilityLabel(t("关闭灾害预警", "防災情報を閉じる")).accessibilityIdentifier("closeSafety")
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                if center.refreshing { ProgressView().tint(.white).accessibilityLabel(t("正在刷新", "更新中")) }
                Text(record.updated.map { (record.offline ? t("离线数据，更新于 ", "オフライン情報・更新 ") : t("更新于 ", "更新 ")) + shortStamp($0) } ?? t("尚未更新", "未更新"))
                    .font(.caption).multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("safetyUpdated")
            }
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
    }
    private func warningRow(_ item: DisasterItem, level: WarningLevel) -> some View {
        DisclosureGroup(isExpanded: binding(item.id)) {
            Text(item.detail.isEmpty ? t("本次公告未附详细说明，请查看 JMA 发布。", "この発表には詳細文がありません。気象庁の発表をご確認ください。") : item.detail).font(.body).textSelection(.enabled).padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title).font(.headline).foregroundStyle(WarningBanner.color(level))
                Text(t("发布于 ", "発表 ") + stamp(item.issued)).font(.subheadline)
                Text(t("适用区域：", "対象地域：") + scope).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                if record.warningsOffline { Text(t("离线公告，待核实", "オフラインの発表・要確認")).font(.caption).foregroundStyle(.yellow) }
            }.fixedSize(horizontal: false, vertical: true)
        }.soraCard().accessibilityLabel(item.title + "，" + stamp(item.issued) + "，" + scope).accessibilityIdentifier("warningRow." + item.id)
    }
    private func otherRow(_ city: SavedCity) -> some View {
        let data = center.record(city.region)
        let level = data.warnings.map { WarningLevel.level(for: $0) }.max() ?? .advisory
        return Button { selectCity(city.id); dismiss() } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(city.region.name).font(.headline)
                Text(level.name + " · \(data.warnings.count)" + t("条", "件")).font(.subheadline).foregroundStyle(WarningBanner.color(level))
                if data.warningsOffline { Text(t("离线数据", "オフライン情報")).font(.caption) }
            }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).soraCard()
        }.buttonStyle(.plain).accessibilityLabel(city.region.name + "，" + level.name + "，\(data.warnings.count)" + t("条警报", "件の警報")).accessibilityIdentifier("otherSafety." + city.region.id)
    }
    private func quakeRow(_ item: DisasterItem) -> some View {
        let quake = EarthquakePresentation(item)
        return DisclosureGroup(isExpanded: binding("quake." + item.id)) {
            Text(item.detail).font(.body).textSelection(.enabled).padding(.top, 8)
            Text(t("资料发布于 ", "情報発表 ") + stamp(item.issued)).font(.caption)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(quake.location).font(.headline)
                Text(quake.occurred.map { stamp($0) } ?? t("发生时间未提供", "発生時刻は未提供")).font(.subheadline)
                ViewThatFits(in: .horizontal) {
                    HStack { Text(t("震级 ", "マグニチュード ") + quake.magnitude); intensity(quake) }
                    VStack(alignment: .leading) { Text(t("震级 ", "マグニチュード ") + quake.magnitude); intensity(quake) }
                }.font(.subheadline)
            }.fixedSize(horizontal: false, vertical: true)
        }.soraCard().accessibilityLabel(quake.location + "，" + (quake.occurred.map { stamp($0) } ?? "") + "，" + t("震级", "マグニチュード") + quake.magnitude + "，" + t("最大震度", "最大震度") + quake.intensityLabel).accessibilityIdentifier("quakeRow." + item.id)
    }
    private func intensity(_ quake: EarthquakePresentation) -> some View {
        Text(t("最大震度 ", "最大震度 ") + quake.intensityLabel).font(.subheadline.bold()).padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(quake.intensityRank >= 6 ? Color.white : Color.black)
            .background(intensityColor(quake.intensityRank), in: RoundedRectangle(cornerRadius: 8))
    }
    private func intensityColor(_ rank: Int) -> Color {
        switch rank { case 0: return .gray; case 1...2: return .cyan; case 3...4: return .yellow; case 5: return .orange; case 6...7: return .red; default: return .purple }
    }
    private func binding(_ id: String) -> Binding<Bool> { Binding(get: { expanded.contains(id) }, set: { if $0 { expanded.insert(id) } else { expanded.remove(id) } }) }
    private func stamp(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .numeric, time: .shortened)
        style.locale = Locale(identifier: AppLanguage.code); style.timeZone = JapanTime.calendar.timeZone
        return date.formatted(style)
    }
    private func shortStamp(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: AppLanguage.code); formatter.timeZone = JapanTime.calendar.timeZone; formatter.dateFormat = "HH:mm"; return formatter.string(from: date)
    }
    private func refresh() async { await center.refresh(current: region, cities: cities.cities) }
}
