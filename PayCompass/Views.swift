import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: Store
    var body: some View {
        TabView {
            NavigationStack { CompareView() }.tabItem { Label("えらぶ", systemImage: "sparkles") }
            NavigationStack { CardsView() }.tabItem { Label("カード", systemImage: "creditcard") }
            NavigationStack { MerchantsView() }.tabItem { Label("お店", systemImage: "storefront") }
            NavigationStack { CampaignsView() }.tabItem { Label("特典", systemImage: "gift") }
            NavigationStack { SettingsView() }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .alert("お知らせ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("閉じる") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct CompareView: View {
    @EnvironmentObject private var store: Store
    @State private var merchantID: UUID?
    @State private var amount = "5000"
    var merchant: Merchant? { store.db.merchants.first { $0.id == merchantID } ?? store.db.merchants.first }
    var yen: Int? { guard let n = Int(amount), (0...100_000_000).contains(n) else { return nil }; return n }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAY COMPASS").font(.caption.weight(.bold)).tracking(3).foregroundStyle(.teal)
                    Text("いつもの支払いを、\n少し賢く。").font(.largeTitle.bold())
                    Text("持っているカードから、今日のベストを。").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Picker("お店", selection: Binding(get: { merchant?.id }, set: { merchantID = $0 })) {
                        ForEach(store.db.merchants) { Text($0.name).tag(Optional($0.id)) }
                    }
                    HStack { Text("¥").font(.title); TextField("購入金額", text: $amount).keyboardType(.numberPad).font(.largeTitle.bold()).accessibilityLabel("購入金額、円") }
                    Text("0〜100,000,000円・税込の通常購入").font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                if let merchant, let yen {
                    let quotes = Calculator.quotes(store.db, merchant: merchant, amount: yen)
                    if quotes.isEmpty { ContentUnavailableView("カードを追加", systemImage: "creditcard", description: Text("カードタブで所有カードを有効にしてください。")) }
                    ForEach(Array(quotes.enumerated()), id: \.element.id) { index, quote in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(index == 0 ? "おすすめ · 同点の場合あり" : "比較", systemImage: index == 0 ? "sparkles" : "creditcard").font(.caption.bold())
                                Spacer()
                                Text(quote.rate, format: .number.precision(.fractionLength(1))).font(.headline) + Text("%")
                            }.foregroundStyle(.teal)
                            Text(quote.card.name).font(.title2.bold())
                            HStack(alignment: .firstTextBaseline) { Text("\(quote.total)").font(.system(.largeTitle, design: .rounded).bold()); Text("円相当 / 概算").foregroundStyle(.secondary) }
                            Text("通常 \(quote.base) + 活動 \(quote.bonus)（最も高い1件のみ）").font(.caption)
                            Text(quote.reason).font(.footnote).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(index == 0 ? Color.teal.opacity(0.12) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
                    }
                    Text("単一購入の参考値です。請求集計・端数・ポイント交換先・除外商品で実際の付与は変わります。決済可否は店頭でご確認ください。活動の上限はこの計算内で適用し、利用済み枠は追跡しません。").font(.caption).foregroundStyle(.secondary)
                } else { Text("お店と有効な整数金額を入力してください。").foregroundStyle(.secondary) }
            }.padding(20)
        }.background(LinearGradient(colors: [.teal.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).navigationTitle("えらぶ").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
    }
}
struct CardsView: View {
    @EnvironmentObject private var store: Store
    @State private var editing: Card?
    var body: some View {
        List {
            Section("マイウォレット") {
                ForEach(store.db.cards) { card in
                    Button { editing = card } label: {
                        HStack { Image(systemName: "creditcard.fill").foregroundStyle(.teal); VStack(alignment: .leading) { Text(card.name).foregroundStyle(.primary); Text(card.owned ? "比較に使用中" : "未所有").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(card.rate, specifier: "%.1f")%").foregroundStyle(.secondary) }.padding(.vertical, 10)
                    }
                }.onDelete { offsets in let ids = offsets.map { store.db.cards[$0].id }; ids.forEach(store.deleteCard) }
            }
            Text("カード番号・有効期限・セキュリティコードは保存しません。").font(.caption)
        }.navigationTitle("カード")
        .toolbar { Button("追加", systemImage: "plus") { editing = Card(name: "", rate: 1, unit: 100, source: "", note: "ユーザー設定") } }
        .sheet(item: $editing) { card in CardEditor(card: card) }
    }
}
struct CardEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var card: Card
    var body: some View {
        NavigationStack {
            Form {
                Section("カード") { TextField("名称", text: $card.name); Toggle("所有している", isOn: $card.owned); TextField("基本還元率 %", value: $card.rate, format: .number).keyboardType(.decimalPad); TextField("計算単位 円", value: $card.unit, format: .number).keyboardType(.numberPad) }
                Section("根拠") { TextField("公式URL", text: $card.source).keyboardType(.URL).textInputAutocapitalization(.never); TextField("条件・例外", text: $card.note, axis: .vertical); SafeLink(url: card.source) }
                if card.kind != "custom" { Text("このカードはAmazon・PayPayの条件設定が適用されます。一般還元率の編集はAmazon特別率を変更しません。").font(.caption) }
            }.navigationTitle("カードを編集").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { if let i = store.db.cards.firstIndex(where: { $0.id == card.id }) { store.db.cards[i] = card } else { store.db.cards.append(card) }; dismiss() }.disabled(card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !card.rate.isFinite || !(0...100).contains(card.rate) || !(1...100000).contains(card.unit)) } }
        }
    }
}
struct MerchantsView: View {
    @EnvironmentObject private var store: Store
    @State private var search = ""
    @State private var editing: Merchant?
    var results: [Merchant] { store.db.merchants.filter { search.isEmpty || ($0.name + $0.category).localizedStandardContains(search) } }
    var body: some View {
        List {
            ForEach(results) { merchant in Button { editing = merchant } label: { HStack { Image(systemName: "storefront").foregroundStyle(.teal); VStack(alignment: .leading) { Text(merchant.name).foregroundStyle(.primary); Text(merchant.category).font(.caption).foregroundStyle(.secondary) } } } }
            .onDelete { offsets in let ids = offsets.map { results[$0].id }; ids.forEach(store.deleteMerchant) }
            if results.isEmpty { ContentUnavailableView.search(text: search) }
        }.searchable(text: $search, prompt: "店名・カテゴリ")
        .navigationTitle("お店を探す").toolbar { Button("追加", systemImage: "plus") { editing = Merchant(name: "", category: "その他") } }
        .sheet(item: $editing) { merchant in MerchantEditor(merchant: merchant) }
    }
}
struct MerchantEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var merchant: Merchant
    var body: some View {
        NavigationStack { Form {
            TextField("店名", text: $merchant.name); TextField("カテゴリ", text: $merchant.category)
            Picker("計算ルール", selection: $merchant.key) { Text("一般加盟店").tag("general"); Text("Amazon.co.jp").tag("amazon") }
            TextField("メモ", text: $merchant.note, axis: .vertical)
            Text("店舗名は検索用の初期リストです。対応決済や加盟店優遇の保証ではありません。").font(.caption)
        }.navigationTitle("お店を編集").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { if let i = store.db.merchants.firstIndex(where: { $0.id == merchant.id }) { store.db.merchants[i] = merchant } else { store.db.merchants.append(merchant) }; dismiss() }.disabled(merchant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
    }
}
struct CampaignsView: View {
    @EnvironmentObject private var store: Store
    @State private var editing: Campaign?
    var body: some View {
        List {
            Section("公式の最新情報") {
                Link("PayPay Card のキャンペーン", destination: URL(string: "https://www.paypay-card.co.jp/campaign/")!)
                Link("Amazon Mastercard の特典・条件", destination: URL(string: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp")!)
            }
            Section("確認済みの活動") {
                if store.db.campaigns.isEmpty { Text("活動を追加して条件を確認すると、比較に反映できます。未確認の期間限定オファーは収録していません。").foregroundStyle(.secondary) }
                ForEach(store.db.campaigns) { campaign in
                    Button { editing = campaign } label: { VStack(alignment: .leading) { Text(campaign.title); Text("追加 \(campaign.bonus, specifier: "%.1f")% · 上限 \(campaign.cap)円").font(.caption); Text(campaign.enabled ? "条件確認済み · 期間内のみ計算" : "無効").font(.caption).foregroundStyle(.secondary) } }
                }.onDelete { store.db.campaigns.remove(atOffsets: $0) }
            }
        }.navigationTitle("特典・活動").toolbar { Button("追加", systemImage: "plus") { if let card = store.db.cards.first, let merchant = store.db.merchants.first { editing = Campaign(title: "", cardID: card.id, merchantID: merchant.id, bonus: 1, cap: 1000, start: .now, end: Calendar.current.date(byAdding: .day, value: 30, to: .now)!, source: "", note: "") } }.disabled(store.db.cards.isEmpty || store.db.merchants.isEmpty) }
        .sheet(item: $editing) { CampaignEditor(campaign: $0) }
    }
}
struct CampaignEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var campaign: Campaign
    var body: some View {
        NavigationStack { Form {
            TextField("活動名", text: $campaign.title)
            Picker("カード", selection: $campaign.cardID) { ForEach(store.db.cards) { Text($0.name).tag($0.id) } }
            Picker("お店", selection: $campaign.merchantID) { ForEach(store.db.merchants) { Text($0.name).tag($0.id) } }
            TextField("追加還元率 %", value: $campaign.bonus, format: .number).keyboardType(.decimalPad)
            TextField("残り付与上限 円相当", value: $campaign.cap, format: .number).keyboardType(.numberPad)
            DatePicker("開始", selection: $campaign.start); DatePicker("終了", selection: $campaign.end)
            TextField("公式URL", text: $campaign.source).keyboardType(.URL).textInputAutocapitalization(.never)
            TextField("エントリー・決済方法等の条件", text: $campaign.note, axis: .vertical)
            Toggle("条件・併用可否を確認済み", isOn: $campaign.enabled)
            Text("追加率は通常還元に上乗せします。重複活動は最大1件のみ。上限の残額は手動で更新してください。").font(.caption)
        }.navigationTitle("活動を編集").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { if let i = store.db.campaigns.firstIndex(where: { $0.id == campaign.id }) { store.db.campaigns[i] = campaign } else { store.db.campaigns.append(campaign) }; dismiss() }.disabled(campaign.title.isEmpty || !campaign.bonus.isFinite || !(0...100).contains(campaign.bonus) || !(0...100000000).contains(campaign.cap) || campaign.start > campaign.end) } } }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmImport = false
    @State private var confirmReset = false
    var body: some View {
        Form {
            Section("計算条件") {
                Toggle("Amazon Prime 会員", isOn: $store.db.prime)
                Toggle("PayPayアプリ登録・本人確認済み", isOn: $store.db.paypayEligible)
            }
            Section("データ") {
                Button("JSONを書き出す", systemImage: "square.and.arrow.up") { exporting = true }
                Button("JSONを読み込む", systemImage: "square.and.arrow.down") { confirmImport = true }
                Button("初期データに戻す", role: .destructive) { confirmReset = true }
            }
            Section("このアプリについて") {
                Text("Pay Compass · 1.0").font(.headline)
                Text("独立した非公式ツール。カード会社やペイえらびとは関係ありません。カード番号の保管・決済・銀行連携は行いません。データはこの端末内のJSONに保存されます。")
                Text("初期ルール確認日：2026年11月3日。自動更新なし。通常の国内商品購入のみ想定。公共料金・税金・チャージ・寄付・分割手数料無料取引などは別条件です。実際の条件は公式サイトで確認してください。")
                Text("初期収録：PayPay Card、Amazon Mastercard、楽天カード、JCB CARD W。その他のカードは名称と基本ルールを追加できます。")
            }
            Section("公式出典") { ForEach(store.db.cards) { card in VStack(alignment: .leading) { Text(card.name); SafeLink(url: card.source) } } }
        }.navigationTitle("設定")
        .confirmationDialog("現在のデータを置き換えます。先に書き出すと復元できます。", isPresented: $confirmImport, titleVisibility: .visible) { Button("ファイルを選ぶ") { importing = true } }
        .confirmationDialog("すべての編集を削除して初期化しますか？", isPresented: $confirmReset, titleVisibility: .visible) { Button("初期化", role: .destructive) { store.db = Seed.database } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in switch result { case .success(let url): store.importData(url); case .failure(let error): store.error = error.localizedDescription } }
        .fileExporter(isPresented: $exporting, document: BackupDocument(data: store.exportData()), contentType: .json, defaultFilename: "PayCompass-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .safeAreaInset(edge: .bottom) {
            Text("端末に保存 · アカウント不要").font(.caption).padding(.horizontal, 18).padding(.vertical, 12).glassEffect(.regular, in: .capsule).padding(.bottom, 8)
        }
    }
}
struct SafeLink: View {
    let url: String
    var body: some View { if let link = URL(string: url), link.scheme == "https", link.host != nil { Link("公式サイト・出典を開く", destination: link) } }
}
