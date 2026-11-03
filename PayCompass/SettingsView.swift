import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("appLanguage") private var language = "system"
    @AppStorage("appTheme") private var theme = "sakura"
    var body: some View {
        Form {
            Section {
                HStack(spacing: 15) {
                    Image("AppLogo").resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) { Text("櫻卡").font(.title2.bold()); Text("SAKURA CARD · 2.1").font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 6)
            }
            Section {
                NavigationLink { ThemeSettingsView() } label: { HStack { Label(L.t("テーマカラー", "主題顏色"), systemImage: "paintpalette"); Spacer(); Circle().fill((AppTheme(rawValue: theme) ?? .sakura).color).frame(width: 20, height: 20) } }
                NavigationLink { LanguageSettingsView() } label: { Label(L.t("言語・表示", "語言與顯示"), systemImage: "globe") }
                NavigationLink { RewardPreferencesView() } label: { Label(L.t("還元資格", "回饋資格"), systemImage: "checkmark.shield") }
            }
            Section {
                NavigationLink { BackupSettingsView() } label: { Label(L.t("バックアップ", "備份與還原"), systemImage: "externaldrive") }
                NavigationLink { AboutSettingsView() } label: { Label(L.t("櫻卡について", "關於櫻卡"), systemImage: "info.circle") }
            }
        }.navigationTitle(L.t("設定", "設定"))
    }
}
struct ThemeSettingsView: View {
    @AppStorage("appTheme") private var theme = "sakura"
    var body: some View {
        List { ForEach(AppTheme.allCases) { value in
            Button { theme = value.rawValue } label: {
                HStack(spacing: 14) { Circle().fill(value.color.gradient).frame(width: 30, height: 30); Text(value.name).foregroundStyle(.primary); Spacer(); if theme == value.rawValue { Image(systemName: "checkmark").fontWeight(.semibold) } }.padding(.vertical, 6)
            }.accessibilityAddTraits(theme == value.rawValue ? .isSelected : [])
        } }.navigationTitle(L.t("テーマカラー", "主題顏色"))
    }
}
struct LanguageSettingsView: View {
    @AppStorage("appLanguage") private var language = "system"
    @AppStorage("colorScheme") private var scheme = "system"
    var body: some View {
        Form {
            Section(L.t("言語", "語言")) { Picker(L.t("言語", "語言"), selection: $language) { Text(L.t("システム", "跟隨系統")).tag("system"); Text("日本語").tag("ja"); Text("繁體中文").tag("zh-Hant") }.pickerStyle(.inline).labelsHidden() }
            Section(L.t("表示モード", "顯示模式")) { Picker(L.t("表示モード", "顯示模式"), selection: $scheme) { Text(L.t("システム", "跟隨系統")).tag("system"); Text(L.t("ライト", "淺色")).tag("light"); Text(L.t("ダーク", "深色")).tag("dark") }.pickerStyle(.inline).labelsHidden() }
        }.navigationTitle(L.t("言語・表示", "語言與顯示"))
    }
}
struct RewardPreferencesView: View {
    @EnvironmentObject private var store: Store
    var body: some View {
        Form {
            Section("Amazon Mastercard") { Toggle(L.t("Amazon Prime 会員", "Amazon Prime 會員"), isOn: $store.db.prime) }
            Section("PayPay Card") {
                Toggle(L.t("クレジット設定・本人確認済み", "已完成信用支付設定與身分驗證"), isOn: $store.db.paypayEligible)
                Toggle(L.t("現在のStep +0.5%をアプリで確認済み", "已在 PayPay App 確認當期 Step +0.5%"), isOn: Binding(get: { store.db.paypayStepMonth == RewardRules.month(.now) }, set: { store.db.paypayStepMonth = $0 ? RewardRules.month(.now) : nil }))
                Text(L.t("前月に200円以上を30回・合計10万円以上。適用期間は毎月2日〜翌月1日。次の期間は再確認してください。", "前月須完成每筆至少 200 日圓共 30 筆、合計至少 10 萬日圓。適用期為每月 2 日至下月 1 日；新一期須重新確認。")).font(.caption).foregroundStyle(.secondary)
            }
            Section { NavigationLink { CampaignsView() } label: { Text(L.t("個別の活動を登録", "登錄個人優惠")) } }
        }.navigationTitle(L.t("還元資格", "回饋資格"))
    }
}
struct BackupSettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmImport = false
    @State private var confirmReset = false
    var body: some View {
        Form {
            Section {
                Button(L.t("JSONを書き出す", "匯出 JSON 備份"), systemImage: "square.and.arrow.up") { exporting = true }
                Button(L.t("JSONを読み込む", "匯入 JSON 備份"), systemImage: "square.and.arrow.down") { confirmImport = true }
            }
            Section { Button(L.t("初期データに戻す", "重設為初始資料"), role: .destructive) { confirmReset = true } }
        }.navigationTitle(L.t("バックアップ", "備份與還原"))
        .confirmationDialog(L.t("現在のデータを置き換えます。先に書き出すと復元できます。", "將取代目前資料，建議先匯出備份。"), isPresented: $confirmImport, titleVisibility: .visible) { Button(L.t("ファイルを選ぶ", "選擇檔案")) { importing = true } }
        .confirmationDialog(L.t("すべての編集・お気に入りを削除して初期化しますか？", "確定刪除所有編輯與收藏並重設？"), isPresented: $confirmReset, titleVisibility: .visible) { Button(L.t("初期化", "重設"), role: .destructive) { store.db = Seed.database } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in switch result { case .success(let url): store.importData(url); case .failure(let error): store.error = error.localizedDescription } }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: store.exportData()), contentType: .json, defaultFilename: "SakuraCard-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
}
struct AboutSettingsView: View {
    var body: some View {
        List {
            Section { Text(L.t("独立した非公式ツール。カード番号の保存や決済は行いません。", "獨立非官方工具，不儲存卡號或執行付款。")); Text(L.t("データは端末内に保存。近くのお店の検索時のみ、許可された現在地をAppleマップへ送信します。保存店舗の座標はバックアップに含まれます。", "資料存於裝置；搜尋附近店鋪時，才會將已授權的位置傳至 Apple 地圖。已存分店座標會包含於備份。")) }
            Section {
                NavigationLink { CalculationInfoView() } label: { Text(L.t("計算方法", "計算方式")) }
                NavigationLink { VerifiedOffersView(kind: "paypay") } label: { Text("PayPay Card") }
                NavigationLink { VerifiedOffersView(kind: "amazon") } label: { Text("Amazon Mastercard") }
                NavigationLink { BrandSourcesView() } label: { Text(L.t("画像の出典", "圖像來源")) }
            }
        }.navigationTitle(L.t("櫻卡について", "關於櫻卡"))
    }
}
struct CalculationInfoView: View {
    var body: some View {
        List {
            Text(L.t("1回の購入額からポイントを概算します。実際の付与は月間合計・端数・対象外商品で変わります。", "由單筆金額估算積分，實際回饋會因月結、尾數及不適用商品而異。"))
            Text(L.t("7-Elevenの7%はApple PayのMastercardタッチ決済のみ。iD・現物カードのタッチは対象外。たばこは追加5.5%対象外。", "7-Eleven 的 7% 僅限 Apple Pay Mastercard 感應支付；iD、實體卡感應不適用，菸品亦不適用額外 5.5%。"))
            Text(L.t("抽選・個別クーポン・新規入会特典は自動計上しません。個別活動と公式加算は高い方1件のみ。", "抽獎、個人優惠券與新戶禮不自動計入；個人活動與官方加碼僅取較高一項。"))
            Text(L.t("確認日：2026年11月4日（日本時間）。自動更新なし。", "核對日期：2026 年 11 月 4 日（日本時間），不會自動更新。"))
        }.navigationTitle(L.t("計算方法", "計算方式"))
    }
}
struct PurchaseConditionsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section { Picker(L.t("用途", "消費類型"), selection: $store.purchaseContext.type) { ForEach(PurchaseType.allCases) { Text($0.name).tag($0) } } }
            if store.purchaseContext.type == .shopping {
                Section("Amazon Mastercard · 7-Eleven") {
                    Toggle(L.t("Apple PayのMastercardタッチで払う", "使用 Apple Pay Mastercard 感應"), isOn: $store.purchaseContext.amazonApplePay)
                    Toggle(L.t("たばこの購入", "購買菸品"), isOn: $store.purchaseContext.tobacco)
                    Text(L.t("iD・現物カードのタッチではオフにしてください。たばこ以外とは分けて計算してください。", "使用 iD 或實體卡感應時請關閉；菸品與其他商品請分開計算。")).font(.caption).foregroundStyle(.secondary)
                }
                Section { Toggle(L.t("コンビニ優遇の対象外店舗・通販", "不適用便利商店優惠的分店／網購"), isOn: $store.purchaseContext.excludedConvenience) }
            }
            NavigationLink { RewardPreferencesView() } label: { Text(L.t("Prime・PayPay資格", "Prime 與 PayPay 資格")) }
        }.navigationTitle(L.t("今回の支払い条件", "本次支付條件")).toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("完了", "完成")) { dismiss() } } }
    }
}
struct CardDesignView: View {
    @EnvironmentObject private var store: Store
    let cardID: UUID
    let designs = [("CardPayPayBlack", "Black"), ("CardPayPayLavender", "Lavender"), ("CardPayPayBlue", "Blue"), ("CardPayPayPink", "Pink")]
    var body: some View {
        List { ForEach(designs, id: \.0) { asset, title in
            Button { if let i = store.db.cards.firstIndex(where: { $0.id == cardID }) { store.db.cards[i].artworkVariant = asset } } label: {
                HStack { Image(asset).resizable().scaledToFit().frame(width: 110); Text(title).foregroundStyle(.primary); Spacer(); if (store.db.cards.first { $0.id == cardID }?.artworkVariant ?? "CardPayPayBlack") == asset { Image(systemName: "checkmark") } }
            }
        } }.navigationTitle(L.t("カードデザイン", "卡面款式"))
    }
}

struct BrandSourcesView: View {
    var body: some View {
        List {
            Section {
                Text(L.t("カード画像とブランドロゴは識別用です。各権利は発行会社・各ブランドに帰属し、提携を示すものではありません。写真・ロゴ等は本プロジェクトのMITライセンス対象外です。", "卡面與品牌圖像用於識別，權利歸各發卡機構及品牌所有，不代表合作。照片與商標不屬於本專案 MIT 授權範圍。"))
                SafeLink(url: "https://www.paypay-card.co.jp/service/card/design/")
                SafeLink(url: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp")
            }
            Section(L.t("お店の画像出典", "店鋪圖像來源")) {
                ForEach(BrandAssets.sources) { source in
                    HStack { Image(source.asset).resizable().scaledToFit().frame(width: 40, height: 40).background(.white).clipShape(RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading) { Text(source.name); SafeLink(url: source.url).font(.caption) } }
                }
            }
        }.navigationTitle(L.t("画像の出典", "圖像來源"))
    }
}
