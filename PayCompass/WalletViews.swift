import SwiftUI

struct CardsView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var ownedOnly = false
    var results: [Card] { store.db.cards.filter { (!ownedOnly || $0.owned) && (query.isEmpty || ($0.name + " " + ($0.issuer ?? "") + " " + ($0.brands ?? "") + " " + ($0.pointsName ?? "")).localizedStandardContains(query)) } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Toggle(L.t("所有カードのみ", "只看持有卡片"), isOn: $ownedOnly).padding()
                Text(L.t("\(results.count)枚 · タップして情報・条件を確認", "\(results.count) 張 · 點選查看資料與適用條件")).font(.caption).foregroundStyle(.secondary)
                ForEach(results) { card in
                    NavigationLink { CardDetail(cardID: card.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CardArtwork(card: card)
                            HStack { Label(card.owned ? L.t("比較に使用中", "已加入比較") : L.t("未所有", "尚未持有"), systemImage: card.owned ? "checkmark.circle.fill" : "plus.circle"); Spacer(); Text(card.pointsName ?? "").lineLimit(1) }.font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
                if results.isEmpty { ContentUnavailableView.search(text: query) }
                Text(L.t("カード番号・有効期限・セキュリティコードは保存しません。", "不會儲存卡號、有效期限或安全碼。")).font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle(L.t("カード", "我的卡片")).searchable(text: $query, prompt: L.t("カード・発行会社・ブランド", "卡名、發卡機構、國際組織"))

    }
}
struct CardDetail: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID
    var card: Card? { store.db.cards.first { $0.id == cardID } }
    var body: some View {
        Group {
            if let c = card {
                List {
                    Section { CardArtwork(card: c).listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                    Section {
                        Toggle(L.t("所有・比較に使用", "我持有此卡，加入比較"), isOn: Binding(get: { card?.owned ?? false }, set: { value in if let i = store.db.cards.firstIndex(where: { $0.id == cardID }) { store.db.cards[i].owned = value } }))
                        LabeledContent(L.t("発行会社", "發卡機構"), value: c.issuer ?? "—")
                        LabeledContent(L.t("ポイント", "積分名稱"), value: c.pointsName ?? "—")
                        LabeledContent(L.t("年会費", "年費"), value: (L.isChinese ? c.annualFeeZH ?? c.annualFee : c.annualFee) ?? "—")
                        LabeledContent(L.t("国際ブランド", "國際組織"), value: c.brands ?? "—")
                        LabeledContent(L.t("計算単位", "計算單位"), value: "¥\(c.unit)")
                    }
                    Section(L.t("適用条件・使い方", "適用條件與使用說明")) {
                        Text((L.isChinese ? c.detailsZH ?? c.details : c.details) ?? (L.isChinese ? c.noteZH ?? c.note : c.note))
                        Text(L.t("ポイント価値は円相当の概算。年会費・年間ボーナスは購入ごとの比較から除外しています。", "積分以日圓等值概算。單筆比較未扣除年費，也未計入年度消費獎勵。")).font(.caption).foregroundStyle(.secondary)
                        SafeLink(url: c.source)
                    }
                    Section {
                        NavigationLink { VerifiedOffersView(kind: c.kind) } label: { Label(L.t("還元・キャンペーンの詳細", "回饋與優惠活動"), systemImage: "list.bullet.rectangle") }
                        NavigationLink { RewardPreferencesView() } label: { Label(L.t("還元資格の設定", "設定回饋資格"), systemImage: "checkmark.shield") }
                        if c.kind == "paypay" { NavigationLink { CardDesignView(cardID: c.id) } label: { Label(L.t("カードデザイン", "卡面款式"), systemImage: "photo") } }
                    }
                }
            } else { ContentUnavailableView(L.t("カードがありません", "卡片已不存在"), systemImage: "creditcard") }
        }.navigationTitle(card?.name ?? "").navigationBarTitleDisplayMode(.inline)

    }
}
struct CampaignsView: View {
    @EnvironmentObject private var store: Store
    @State private var editing: Campaign?
    var body: some View {
        List {
            Section(L.t("公式の最新情報", "官方最新資訊")) {
                Link(L.t("PayPay Card のキャンペーン", "PayPay Card 優惠活動"), destination: URL(string: "https://www.paypay-card.co.jp/event/")!)
                Link(L.t("Amazon Mastercard の特典", "Amazon Mastercard 優惠"), destination: URL(string: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp")!)
            }
            Section(L.t("確認済みの活動", "已確認的活動")) {
                if store.db.campaigns.isEmpty { Text(L.t("条件を確認して活動を追加してください。", "確認活動條件後即可新增，啟用後納入比較。")).foregroundStyle(.secondary) }
                ForEach(store.db.campaigns) { c in Button { editing = c } label: { VStack(alignment: .leading, spacing: 5) { Text(c.title); Text(L.t("追加 \(c.bonus.formatted())% · 上限 \(c.cap)円", "額外 \(c.bonus.formatted())% · 上限 \(c.cap) 日圓")).font(.caption); Text(c.enabled ? L.t("有効・期間内のみ計算", "已啟用 · 限活動期間內計算") : L.t("無効", "未啟用")).font(.caption).foregroundStyle(.secondary) } } }.onDelete { store.db.campaigns.remove(atOffsets: $0) }
            }
        }.navigationTitle(L.t("特典・活動", "優惠活動"))
        .toolbar { Button(L.t("追加", "新增"), systemImage: "plus") { if let card = store.db.cards.first, let merchant = store.db.merchants.first { editing = Campaign(title: "", cardID: card.id, merchantID: merchant.id, bonus: 1, cap: 1000, start: .now, end: Calendar.current.date(byAdding: .day, value: 30, to: .now)!, source: "", note: "") } }.disabled(store.db.cards.isEmpty || store.db.merchants.isEmpty) }
        .sheet(item: $editing) { CampaignEditor(campaign: $0) }
    }
}
struct CampaignEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var campaign: Campaign
    var body: some View {
        NavigationStack { Form {
            TextField(L.t("活動名", "活動名稱"), text: $campaign.title)
            Picker(L.t("カード", "卡片"), selection: $campaign.cardID) { ForEach(store.db.cards) { Text($0.name).tag($0.id) } }
            Picker(L.t("お店", "店鋪"), selection: $campaign.merchantID) { ForEach(store.db.merchants) { Text($0.name).tag($0.id) } }
            TextField(L.t("追加還元率 %", "額外回饋率 %"), value: $campaign.bonus, format: .number).keyboardType(.decimalPad)
            TextField(L.t("残り上限 円相当", "剩餘回饋上限（日圓等值）"), value: $campaign.cap, format: .number).keyboardType(.numberPad)
            DatePicker(L.t("開始", "開始"), selection: $campaign.start); DatePicker(L.t("終了", "結束"), selection: $campaign.end)
            TextField(L.t("公式URL", "官方網址"), text: $campaign.source).keyboardType(.URL).textInputAutocapitalization(.never)
            TextField(L.t("エントリー・決済方法などの条件", "登錄與指定支付方式等條件"), text: $campaign.note, axis: .vertical)
            Toggle(L.t("条件・併用可否を確認済み", "已確認條件與可併用性"), isOn: $campaign.enabled)
            Text(L.t("基本分に上乗せ。活動は最高1件のみ。上限残額は手動更新。", "在基本回饋上加計，活動僅取最高一項；剩餘上限須自行更新。")).font(.caption)
        }.navigationTitle(L.t("活動を編集", "編輯活動")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.t("取消", "取消")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(L.t("保存", "儲存")) { if let i = store.db.campaigns.firstIndex(where: { $0.id == campaign.id }) { store.db.campaigns[i] = campaign } else { store.db.campaigns.append(campaign) }; dismiss() }.disabled(campaign.title.isEmpty || !campaign.bonus.isFinite || !(0...100).contains(campaign.bonus) || !(0...100000000).contains(campaign.cap) || campaign.start > campaign.end) } } }
    }
}
struct SafeLink: View {
    let url: String
    var body: some View { if let link = URL(string: url), link.scheme == "https", link.host != nil { Link(L.t("公式サイト・出典を開く", "開啟官方網站與資料來源"), destination: link) } }
}
