import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var model: WeatherModel
    @AppStorage("language") private var language = "zh-Hans"
    @AppStorage("rainEnabled") private var rainEnabled = false
    @AppStorage("autoLocation") private var autoLocation = true
    @AppStorage("yahooClientID") private var clientID = ""
    @State private var asking = false
    @Environment(\.dismiss) private var dismiss
    private func t(_ zh: String, _ ja: String) -> String { language == "ja" ? ja : zh }
    var body: some View {
        NavigationStack {
            Form {
                Section(t("显示", "表示")) {
                    Picker(t("语言", "言語"), selection: $language) { Text("简体中文").tag("zh-Hans"); Text("日本語").tag("ja") }
                    Picker(t("城市", "都市"), selection: Binding(get: { model.region.id }, set: { id in if let r = Region.supported.first(where: { $0.id == id }) { Task { await model.select(r) } } })) {
                        ForEach(Region.supported) { Text($0.name).tag($0.id) }
                    }
                    Toggle(t("启动时自动定位", "起動時に現在地を取得"), isOn: $autoLocation)
                    Button(t("重新定位", "現在地を再取得")) { model.locate() }
                    Text(t("自动选择 45 km 内最近的受支持城市；超出范围保留所选城市。大阪的 3 小时预报采用住吉区，其他城市采用中心区。", "45km以内の対応都市を選択します。対象外では選択都市を維持します。大阪の3時間予報は住吉区、他都市は中心区を使用します。")).font(.caption).foregroundStyle(.secondary)
                }
                Section(t("普通天气提醒", "通常の天気通知")) {
                    Toggle(t("降雨提醒", "雨の通知"), isOn: $rainEnabled)
                    LabeledContent(t("系统通知权限", "通知の許可"), value: model.notificationAllowed ? t("已允许", "許可済み") : t("未允许", "未許可"))
                    Button(t("请求通知权限", "通知を許可する")) { Task { asking = true; model.notificationAllowed = await RainNotifications.shared.requestPermission(); await model.updateReminders(); asking = false } }.disabled(asking)
                    Link(t("打开系统设置", "システム設定を開く"), destination: URL(string: UIApplication.openSettingsURLString)!)
                    Text(t("无需密钥时，根据下一预报时段的降水量或降雨概率提醒。后台刷新由 iOS 决定；App 关闭、低电量、网络或专注模式可能使提醒延迟或缺失。已预约的提醒也可能因预报改变而失准。", "キー未設定時は次の予報時間帯の降水量・降水確率で通知します。バックグラウンド更新はiOSが決定し、終了・省電力・通信・集中モード等により遅延・欠落します。予約済み通知も予報の変化で外れる場合があります。")).font(.caption).foregroundStyle(.secondary)
                    if !model.notificationError.isEmpty { Text(model.notificationError).foregroundStyle(.orange) }
                }
                Section(t("可选：短时降雨 API", "任意：短時間降雨API")) {
                    SecureField("Yahoo Developer Client ID", text: $clientID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text(t("终端用户无需 Yahoo 账号。开发者 Client ID 需由开发者另行申请；留空也可查看天气并使用时段提醒。Client ID 存于设备，不应填入账户密码。", "利用者のYahooログインは不要です。開発者のClient IDは別途取得が必要です。空欄でも予報と時間帯通知を利用できます。端末に保存されます。パスワードは入力しないでください。")).font(.caption).foregroundStyle(.secondary)
                    Link(t("Yahoo 气象 API 文档", "Yahoo 気象API仕様"), destination: URL(string: "https://developer.yahoo.co.jp/webapi/map/openlocalplatform/v1/weather.html")!)
                    Button(t("保存并更新数据", "保存して更新")) { Task { await model.updateReminders(); await model.select(model.region) } }
                }
                Section(t("紧急预警的区别", "緊急速報との違い")) {
                    Text(t("本 App 不提供实时地震预警、海啸警报推送、避难指示或 Critical Alerts。防灾页为 JMA 信息查看入口；不能作为避难或安全判断的唯一依据。", "緊急地震速報、津波警報のプッシュ、避難指示、Critical Alertsには対応しません。防災画面はJMA情報の閲覧用です。避難・安全判断の唯一の手段にしないでください。"))
                    Link(t("气象厅官方防灾信息", "気象庁の公式防災情報"), destination: URL(string: "https://www.jma.go.jp/bosai/")!)
                }
                Section(t("数据与隐私", "データとプライバシー")) {
                    Text(t("无广告、无追踪 SDK、无需注册。仅请求天气数据，不执行 Yahoo 页面脚本或加载广告。天气缓存保存在本机；定位用于选择附近预报区，坐标不会上传至本 App 服务器（本项目无服务器）。", "広告・追跡SDK・登録はありません。予報データのみ取得し、Yahooのスクリプトや広告は読み込みません。キャッシュは端末内です。位置情報は予報区の選択に使い、本アプリのサーバーには送信しません（サーバーなし）。")).font(.caption)
                    Text(t("启用可选 Yahoo 降雨 API 会向 Yahoo 发送所选预报区坐标与 Client ID。公开页面解析可能随网页变更失效；本项目未获 Yahoo 数据再分发授权。", "任意のYahoo降雨APIは予報区座標とClient IDをYahooへ送信します。公開ページの変更で取得不可になる場合があります。本プロジェクトはYahooデータの再配布許諾を受けていません。")).font(.caption)
                    Link("Yahoo! JAPAN / Weather Map", destination: model.region.yahooURL)
                    Link(t("气象厅数据使用条款", "気象庁ホームページ利用規約"), destination: URL(string: "https://www.jma.go.jp/jma/kishou/info/coment.html")!)
                }
            }
            .navigationTitle(t("设置", "設定"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("完成", "完了")) { dismiss() } } }
            .onChange(of: rainEnabled) { _, _ in Task { await model.updateReminders() } }
            .onChange(of: language) { _, _ in Task { await model.updateReminders() } }
            .onChange(of: autoLocation) { _, enabled in if enabled { model.locate() } }
        }.presentationDetents([.large])
    }
}
