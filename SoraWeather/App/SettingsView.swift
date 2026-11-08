import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: WeatherModel
    private var language: String { AppLanguage.code }
    @AppStorage("rainEnabled") private var rainEnabled = false
    @AppStorage("autoLocation") private var autoLocation = true
    @AppStorage("yahooClientID") private var clientID = ""
    @State private var asking = false
    @State private var webpage: InternalPage?
    @Environment(\.dismiss) private var dismiss
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    var body: some View {
        NavigationStack {
            Form {
                Section(t("显示", "表示")) {
                    Text(t("语言跟随系统", "言語はシステム設定に従います"))
                    Picker(t("城市", "都市"), selection: Binding(get: { model.region.id }, set: { id in if let r = Region.supported.first(where: { $0.id == id }) { Task { await model.select(r) } } })) {
                        ForEach(Region.supported) { Text($0.name).tag($0.id) }
                    }
                    Toggle(t("启动时自动定位", "起動時に現在地を取得"), isOn: $autoLocation)
                    Button(t("重新定位", "現在地を再取得")) { model.locate() }
                }
                Section(t("普通天气提醒", "通常の天気通知")) {
                    Toggle(t("降雨提醒", "雨の通知"), isOn: $rainEnabled)
                    LabeledContent(t("系统通知权限", "通知の許可"), value: model.notificationAllowed ? t("已允许", "許可済み") : t("未允许", "未許可"))
                    Button(t("请求通知权限", "通知を許可する")) { Task { asking = true; model.notificationAllowed = await RainNotifications.shared.requestPermission(); await model.updateReminders(); asking = false } }.disabled(asking)
                    Link(t("打开系统设置", "システム設定を開く"), destination: URL(string: UIApplication.openSettingsURLString)!)
                    if !model.notificationError.isEmpty { Text(model.notificationError).foregroundStyle(.orange) }
                }
                Section(t("可选：短时降雨 API", "任意：短時間降雨API")) {
                    SecureField("Yahoo Developer Client ID", text: $clientID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Link(t("Yahoo 气象 API 文档", "Yahoo 気象API仕様"), destination: URL(string: "https://developer.yahoo.co.jp/webapi/map/openlocalplatform/v1/weather.html")!)
                    Button(t("保存并更新数据", "保存して更新")) { Task { await model.updateReminders(); await model.refresh() } }
                }
                Section {
                    NavigationLink(t("数据与隐私", "データとプライバシー")) {
                        Form {
                            Text(UserDefaults.standard.object(forKey: "yahooUnavailable." + model.region.id) == nil ? t("补充数据等待更新", "補完データの更新待ち") : UserDefaults.standard.bool(forKey: "yahooUnavailable." + model.region.id) ? t("Yahoo 暂不可用，目前使用 JMA 数据", "Yahoo取得不可・JMAデータを使用中") : t("JMA 主数据 · Yahoo 补充可用", "JMAメイン・Yahoo補完データ利用可")).font(.caption).foregroundStyle(.secondary)
                            Text(t("预报可能延迟或缺失；离线时显示本机缓存。Yahoo 缺字段时跳过该字段，JMA 仍正常显示。当前公开来源通常提供 3 小时气温、6 小时降水概率及 7–8 日预报；不补造逐小时、体感或未发布日期。", "予報に遅延・欠落がある場合があります。オフライン時は端末キャッシュを表示します。Yahooの欠損項目は省略しJMAを表示します。公開データは通常3時間気温・6時間降水確率・7〜8日予報です。未提供の1時間値・体感温度・日付は生成しません。"))
                            Text(t("气温显示为来源提供的时段预报，不是实测。定位选择45km以内的受支持城市预报区。", "気温は配信元の時間帯予報で、実況値ではありません。現在地から45km以内の対応予報区を選択します。"))
                            Text(t("后台刷新和通知由 iOS 调度，可能延迟或缺失，不能保证准确起雨时间。", "バックグラウンド更新・通知はiOSが制御し遅延・欠落があります。降り始めの正確な通知は保証しません。"))
                Section(t("紧急预警的区别", "緊急速報との違い")) {
                    Text(t("本 App 不提供实时地震预警、海啸警报推送、避难指示或 Critical Alerts。防灾页为 JMA 信息查看入口；不能作为避难或安全判断的唯一依据。", "緊急地震速報、津波警報のプッシュ、避難指示、Critical Alertsには対応しません。防災画面はJMA情報の閲覧用です。避難・安全判断の唯一の手段にしないでください。"))
                    Link(t("气象厅官方防灾信息", "気象庁の公式防災情報"), destination: URL(string: "https://www.jma.go.jp/bosai/")!)
                }
                Section(t("数据与隐私", "データとプライバシー")) {
                    Text(t("无广告、无追踪 SDK、无需注册。仅请求天气数据，不执行 Yahoo 页面脚本或加载广告。天气缓存保存在本机；定位用于选择附近预报区，坐标不会上传至本 App 服务器（本项目无服务器）。", "広告・追跡SDK・登録はありません。予報データのみ取得し、Yahooのスクリプトや広告は読み込みません。キャッシュは端末内です。位置情報は予報区の選択に使い、本アプリのサーバーには送信しません（サーバーなし）。")).font(.caption)
                    Text(t("启用可选 Yahoo 降雨 API 会向 Yahoo 发送所选预报区坐标与 Client ID。公开页面解析可能随网页变更失效；本项目未获 Yahoo 数据再分发授权。", "任意のYahoo降雨APIは予報区座標とClient IDをYahooへ送信します。公開ページの変更で取得不可になる場合があります。本プロジェクトはYahooデータの再配布許諾を受けていません。")).font(.caption)
                    Link("Yahoo! JAPAN / Weather Map", destination: model.region.yahooURL)
                    Link(t("气象厅数据使用条款", "気象庁ホームページ利用規約"), destination: URL(string: "https://www.jma.go.jp/jma/kishou/info/coment.html")!)
                }                        }.navigationTitle(t("数据与隐私", "データとプライバシー"))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("LaunchBackground").ignoresSafeArea(.all))
            .navigationTitle(t("设置", "設定"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("完成", "完了")) { dismiss() } } }
            .onChange(of: rainEnabled) { _, _ in Task { await model.updateReminders() } }

            .onChange(of: autoLocation) { _, enabled in if enabled { model.locate() } }
        }.presentationDetents([.large])
        .sheet(item: $webpage) { InternalBrowser(url: $0.url) }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "http" || url.scheme == "https" { webpage = InternalPage(url: url); return .handled }
            return .systemAction
        })
    }
}
