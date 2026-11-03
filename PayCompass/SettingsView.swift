import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("appLanguage") private var language = "system"
    @AppStorage("appTheme") private var theme = "sakura"
    @AppStorage("colorScheme") private var scheme = "system"
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmImport = false
    @State private var confirmReset = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 15) {
                    Image("AppLogo").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 5) { Text("櫻卡").font(.title.bold()); Text("SAKURA CARD · 2.0").font(.caption).tracking(1.5).foregroundStyle(.secondary) }
                }.padding(.vertical, 10)
            }
            Section(L.t("外観・言語", "外觀與語言")) {
                Picker(L.t("言語 / 語言", "語言 / 言語"), selection: $language) {
                    Text(L.t("システムに合わせる", "跟隨系統")).tag("system")
                    Text("日本語").tag("ja"); Text("繁體中文").tag("zh-Hant")
                }
                Picker(L.t("表示モード", "顯示模式"), selection: $scheme) { Text(L.t("システム", "跟隨系統")).tag("system"); Text(L.t("ライト", "淺色")).tag("light"); Text(L.t("ダーク", "深色")).tag("dark") }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 16) {
                    ForEach(AppTheme.allCases) { value in
                        Button { theme = value.rawValue } label: {
                            VStack(spacing: 7) { Circle().fill(value.color.gradient).frame(width: 42, height: 42).overlay { if theme == value.rawValue { Image(systemName: "checkmark").foregroundStyle(.white).font(.headline) } }; Text(value.name).font(.caption).foregroundStyle(.primary) }.frame(maxWidth: .infinity).padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityLabel(value.name).accessibilityAddTraits(theme == value.rawValue ? .isSelected : [])
                    }
                }.padding(.vertical, 8)
            }
            Section(L.t("計算条件", "回饋計算條件")) {
                Toggle(L.t("Amazon Prime 会員", "Amazon Prime 會員"), isOn: $store.db.prime)
                Toggle(L.t("PayPayアプリ登録・本人確認済み", "已完成 PayPay App 登錄與身分驗證"), isOn: $store.db.paypayEligible)
                NavigationLink { CampaignsView() } label: { Label(L.t("特典・活動を管理", "管理優惠活動"), systemImage: "gift") }
            }
            Section(L.t("データ", "資料管理")) {
                LabeledContent(L.t("カード", "卡片"), value: "\(store.db.cards.count)")
                LabeledContent(L.t("お店・保存店舗", "店鋪與已存分店"), value: "\(store.db.merchants.count)")
                LabeledContent(L.t("お気に入り", "收藏"), value: "\(store.db.merchants.filter { $0.favorite == true }.count)")
                Button(L.t("JSONを書き出す", "匯出 JSON 備份"), systemImage: "square.and.arrow.up") { exporting = true }
                Button(L.t("JSONを読み込む", "匯入 JSON 備份"), systemImage: "square.and.arrow.down") { confirmImport = true }
                Button(L.t("初期データに戻す", "重設為初始資料"), role: .destructive) { confirmReset = true }
            }
            Section(L.t("データとプライバシー", "資料與隱私")) {
                Text(L.t("独立した非公式ツール。カード会社やペイえらびとは関係ありません。カード番号の保存・決済・銀行連携は行いません。", "本 App 為獨立非官方工具，與發卡機構及「ペイえらび」無關。不儲存卡號、不執行付款，也不連結銀行。"))
                Text(L.t("通常購入ルールの確認日：2026年11月3日。自動更新なし。税金・公共料金・チャージ・寄付などは対象外条件を必ず確認してください。", "一般消費規則核對日：2026 年 11 月 3 日。不會自動更新。稅金、公共費用、儲值、捐款等請另行核對適用條件。"))
                Text(L.t("お店のアイコンは識別用の独自文字バッジで、公式ロゴではありません。カードの画像も独自デザインです。", "店鋪圖示為獨立製作的識別文字徽章，並非官方商標圖檔。卡面也為獨立設計。"))
                Text(L.t("近くのお店はAppleマップの検索を利用します。位置情報の許可後に通信します。アカウントや独自サーバーは不要。現在地の継続追跡はしません。保存した店舗の座標はJSONバックアップに含まれます。", "附近店鋪使用 Apple 地圖搜尋，允許定位後才會傳送查詢。不需帳號或自建伺服器，也不持續追蹤目前位置。你收藏分店的座標會包含在 JSON 備份中。"))
            }
            Section(L.t("公式出典", "官方資料來源")) { ForEach(store.db.cards) { card in VStack(alignment: .leading, spacing: 5) { Text(card.name).font(.subheadline); SafeLink(url: card.source).font(.caption) } } }
        }.navigationTitle(L.t("設定", "設定"))
        .confirmationDialog(L.t("現在のデータを置き換えます。先に書き出すと復元できます。", "將取代目前資料，建議先匯出備份。"), isPresented: $confirmImport, titleVisibility: .visible) { Button(L.t("ファイルを選ぶ", "選擇檔案")) { importing = true } }
        .confirmationDialog(L.t("すべての編集・お気に入りを削除して初期化しますか？", "確定刪除所有編輯與收藏並重設？"), isPresented: $confirmReset, titleVisibility: .visible) { Button(L.t("初期化", "重設"), role: .destructive) { store.db = Seed.database } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in switch result { case .success(let url): store.importData(url); case .failure(let error): store.error = error.localizedDescription } }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: store.exportData()), contentType: .json, defaultFilename: "SakuraCard-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .safeAreaInset(edge: .bottom) { Text(L.t("端末に保存 · アカウント不要", "資料儲存於裝置 · 無需帳號")).font(.caption).padding(.horizontal, 18).padding(.vertical, 12).glassEffect(.regular, in: .capsule).padding(.bottom, 8) }
    }
}
