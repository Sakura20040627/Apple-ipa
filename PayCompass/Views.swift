import SwiftUI
import UniformTypeIdentifiers
import MapKit

struct RootView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("appLanguage") private var language = "system"
    @AppStorage("appTheme") private var theme = "sakura"
    @AppStorage("colorScheme") private var scheme = "system"
    var body: some View {
        TabView(selection: $store.currentTab) {
            NavigationStack { CompareView() }.tabItem { Label(L.t("比較", "比較"), systemImage: "sparkles") }.tag(0)
            NavigationStack { CardsView() }.tabItem { Label(L.t("カード", "卡片"), systemImage: "creditcard") }.tag(1)
            NavigationStack { MerchantsView() }.tabItem { Label(L.t("お店", "店鋪"), systemImage: "storefront") }.tag(2)
            NavigationStack { NearbyView() }.tabItem { Label(L.t("近く", "附近"), systemImage: "location") }.tag(3)
            NavigationStack { SettingsView() }.tabItem { Label(L.t("設定", "設定"), systemImage: "gearshape") }.tag(4)
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-sakuraTab"), args.indices.contains(i + 1), let tab = Int(args[i + 1]), (0...4).contains(tab) { store.currentTab = tab }
        }
        #endif
        .id(language)
        .tint((AppTheme(rawValue: theme) ?? .sakura).color)
        .environment(\.locale, Locale(identifier: language == "system" ? (L.isChinese ? "zh-Hant" : "ja") : language))
        .preferredColorScheme(scheme == "dark" ? .dark : scheme == "light" ? .light : nil)
        .alert(L.t("お知らせ", "通知"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button(L.t("閉じる", "關閉")) { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct CompareView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("appTheme") private var theme = "sakura"
    @State private var amount = "5000"
    @State private var picker = false
    var merchant: Merchant? { store.db.merchants.first { $0.id == store.selectedMerchant } ?? Catalog.sorted(store.db.merchants).first }
    var yen: Int? { guard let n = Int(amount), (0...100_000_000).contains(n) else { return nil }; return n }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAKURA CARD").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Color.accentColor)
                    Text(L.t("支払いに、いい選択を。", "每筆消費，都選得更好。")).font(.largeTitle.bold())
                    Text(L.t("あなたのカードで、今日のベストを。", "用你持有的卡，找到今天最好的回饋。")).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Button { picker = true } label: {
                        HStack(spacing: 14) {
                            if let merchant { MerchantBadge(merchant: merchant); VStack(alignment: .leading, spacing: 3) { Text(merchant.name).font(.headline).foregroundStyle(.primary); Text(L.t("タップしてお店を検索", "點此搜尋店鋪")).font(.caption).foregroundStyle(.secondary) } }
                            else { Label(L.t("お店を選択", "選擇店鋪"), systemImage: "magnifyingglass") }
                            Spacer(); Image(systemName: "magnifyingglass").foregroundStyle(Color.accentColor)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                    HStack { Text("¥").font(.title).foregroundStyle(.secondary); TextField(L.t("購入金額", "消費金額"), text: $amount).keyboardType(.numberPad).font(.system(.largeTitle, design: .rounded).bold()).accessibilityLabel(L.t("購入金額、円", "消費金額，日圓")) }
                    Text(L.t("税込の通常購入 · 最大1億円", "含稅一般消費 · 上限 1 億日圓")).font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                if let merchant, let yen {
                    let quotes = Calculator.quotes(store.db, merchant: merchant, amount: yen)
                    if quotes.isEmpty { ContentUnavailableView(L.t("カードを追加", "新增卡片"), systemImage: "creditcard", description: Text(L.t("カードタブで所有カードを有効にしてください。", "請在卡片頁開啟你持有的卡片。"))) }
                    ForEach(Array(quotes.enumerated()), id: \.element.id) { index, quote in QuoteRow(quote: quote, recommended: index == 0) }
                    Text(L.t("単一購入の参考値です。月間集計、端数、交換先、対象外商品で実際の付与は変わります。活動は最大1件。上限残額は手動更新です。決済可否は店頭でご確認ください。", "此為單筆消費估算。月結、進位規則、兌換方式與不適用商品會影響實際回饋。活動僅取最高一項，剩餘上限須手動更新。支付方式是否可用請向店家確認。")).font(.caption).foregroundStyle(.secondary)
                } else { Text(L.t("お店と有効な整数金額を入力してください。", "請選擇店鋪，並輸入有效的整數金額。")).foregroundStyle(.secondary) }
            }.padding(20)
        }.background(LinearGradient(colors: [(AppTheme(rawValue: theme) ?? .sakura).color.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
        .navigationTitle("櫻卡").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { CampaignsView() } label: { Image(systemName: "gift") }.accessibilityLabel(L.t("特典・活動", "優惠活動")) }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(L.t("完了", "完成")) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
        .sheet(isPresented: $picker) { NavigationStack { MerchantPicker { item in store.selectedMerchant = item.id; picker = false } } }
    }
}
struct QuoteRow: View {
    let quote: Quote
    let recommended: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(recommended ? L.t("おすすめ · 同点の場合あり", "推薦 · 可能有同分卡片") : L.t("比較", "比較"), systemImage: recommended ? "sparkles" : "creditcard").font(.caption.bold())
                Spacer(); Text("\(quote.rate, specifier: "%.1f")%").font(.headline)
            }.foregroundStyle(Color.accentColor)
            HStack(spacing: 12) { RoundedRectangle(cornerRadius: 6).fill(Color(hex: quote.card.color ?? "CE447B").gradient).frame(width: 34, height: 23); Text(quote.card.name).font(.title3.bold()) }
            HStack(alignment: .firstTextBaseline) { Text("\(quote.total)").font(.system(.largeTitle, design: .rounded).bold()); Text(L.t("円相当 / 概算", "日圓等值／估算")).foregroundStyle(.secondary) }
            Text(L.t("通常 \(quote.base) + 活動 \(quote.bonus)", "基本 \(quote.base)＋活動 \(quote.bonus)")).font(.caption)
            Text(quote.reason).font(.footnote).foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(recommended ? Color.accentColor.opacity(0.13) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
    }
}
struct CategoryStrip: View {
    @Binding var selected: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(L.categories, id: \.self) { category in
                    Button { selected = category } label: { Text(L.category(category)).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10).background(selected == category ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule()).foregroundStyle(selected == category ? Color.accentColor : .primary) }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16)
        }
    }
}
struct MerchantRow: View {
    let merchant: Merchant
    var body: some View {
        HStack(spacing: 14) {
            MerchantBadge(merchant: merchant)
            VStack(alignment: .leading, spacing: 4) { Text(merchant.name).font(.headline); Text(merchant.address ?? L.category(merchant.category)).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            Spacer()
            if merchant.favorite == true { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel(L.t("お気に入り", "已收藏")) }
        }.padding(.vertical, 8)
    }
}
struct MerchantPicker: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category = "すべて"
    let select: (Merchant) -> Void
    var results: [Merchant] { Catalog.sorted(store.db.merchants).filter { Catalog.matches($0, query: query) && (category == "すべて" || $0.category == category) } }
    var body: some View {
        List { ForEach(results) { m in Button { select(m) } label: { MerchantRow(merchant: m).foregroundStyle(.primary) } }; if results.isEmpty { ContentUnavailableView.search(text: query) } }
        .safeAreaInset(edge: .top) { CategoryStrip(selected: $category).padding(.vertical, 8).background(.bar) }
        .searchable(text: $query, prompt: L.t("店名・英語・カテゴリ", "店名、繁中別名、英文、分類"))
        .navigationTitle(L.t("お店を選択", "選擇店鋪"))
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.t("閉じる", "關閉")) { dismiss() } } }
    }
}
struct MerchantsView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var category = "すべて"
    @State private var favoritesOnly = false
    @State private var editing: Merchant?
    var results: [Merchant] { Catalog.sorted(store.db.merchants).filter { Catalog.matches($0, query: query) && (category == "すべて" || $0.category == category) && (!favoritesOnly || $0.favorite == true) } }
    var body: some View {
        List {
            Section {
                Toggle(L.t("お気に入りのみ", "只看收藏"), isOn: $favoritesOnly)
                Text(L.t("\(results.count)件 · お気に入りを先頭に表示", "\(results.count) 間 · 收藏預設置頂")).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(results) { m in
                NavigationLink { MerchantDetail(merchantID: m.id) } label: { MerchantRow(merchant: m) }
                .swipeActions(edge: .leading) { Button { store.toggleFavorite(m.id) } label: { Label(m.favorite == true ? L.t("解除", "取消收藏") : L.t("お気に入り", "收藏"), systemImage: m.favorite == true ? "star.slash" : "star") }.tint(.orange) }
                .swipeActions(edge: .trailing) { Button(role: .destructive) { store.deleteMerchant(m.id) } label: { Label(L.t("削除", "刪除"), systemImage: "trash") }; Button { editing = m } label: { Label(L.t("編集", "編輯"), systemImage: "pencil") } }
            }
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }.safeAreaInset(edge: .top) { CategoryStrip(selected: $category).padding(.vertical, 8).background(.bar) }
        .searchable(text: $query, prompt: L.t("店名・英語・カテゴリ", "店名、繁中別名、英文、分類"))
        .navigationTitle(L.t("お店を探す", "搜尋店鋪"))
        .toolbar { Button(L.t("追加", "新增"), systemImage: "plus") { editing = Merchant(name: "", category: "その他") } }
        .sheet(item: $editing) { MerchantEditor(merchant: $0) }
    }
}
struct MerchantDetail: View {
    @EnvironmentObject private var store: Store
    let merchantID: UUID
    @State private var editing: Merchant?
    var merchant: Merchant? { store.db.merchants.first { $0.id == merchantID } }
    var body: some View {
        Group {
            if let m = merchant {
                List {
                    Section { HStack { MerchantBadge(merchant: m, size: 64); VStack(alignment: .leading) { Text(m.name).font(.title2.bold()); Text(L.category(m.category)).foregroundStyle(.secondary) } }.padding(.vertical, 12) }
                    Section {
                        Button { store.selectedMerchant = m.id; store.currentTab = 0 } label: { Label(L.t("このお店で比較", "比較這間店的支付回饋"), systemImage: "sparkles") }
                        Button { store.toggleFavorite(m.id) } label: { Label(m.favorite == true ? L.t("お気に入りを解除", "取消收藏") : L.t("お気に入りに追加", "加入收藏並置頂"), systemImage: m.favorite == true ? "star.fill" : "star") }
                        if let lat = m.latitude, let lon = m.longitude {
                            Button { MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))).openInMaps() } label: { Label(L.t("地図・経路", "地圖與路線"), systemImage: "map") }
                        }
                    }
                    if let address = m.address { Section(L.t("住所", "地址")) { Text(address).textSelection(.enabled) } }
                    Section(L.t("メモ", "備註")) { Text(m.note == "通常のカード購入を想定。店舗・商品ごとの対象外条件を確認してください。" ? L.t("通常のカード購入を想定。店舗・商品ごとの対象外条件を確認してください。", "以一般刷卡購物為前提；請確認分店與商品的適用條件。") : m.note) }
                }.toolbar { Button(L.t("編集", "編輯")) { editing = m } }
            } else { ContentUnavailableView(L.t("お店がありません", "店鋪已不存在"), systemImage: "storefront") }
        }.navigationTitle(L.t("お店の情報", "店鋪資訊")).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { MerchantEditor(merchant: $0) }
    }
}
struct MerchantEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var merchant: Merchant
    var body: some View {
        NavigationStack { Form {
            Section { MerchantBadge(merchant: merchant, size: 64); TextField(L.t("店名", "店名"), text: $merchant.name)
                Picker(L.t("カテゴリ", "分類"), selection: $merchant.category) { ForEach(L.categories.filter { $0 != "すべて" }, id: \.self) { Text(L.category($0)).tag($0) } }
                Toggle(L.t("お気に入り・先頭に表示", "收藏並置頂"), isOn: Binding(get: { merchant.favorite == true }, set: { merchant.favorite = $0 }))
            }
            Section(L.t("検索・アイコン", "搜尋與圖示")) { TextField(L.t("別名・英語", "別名、英文"), text: optional($merchant.aliases)); TextField(L.t("アイコン文字（短く）", "圖示縮寫（短文字）"), text: optional($merchant.icon)); TextField(L.t("カラー HEX", "圖示顏色 HEX"), text: optional($merchant.color)).textInputAutocapitalization(.characters) }
            Section(L.t("詳細", "詳細資訊")) {
                TextField(L.t("住所", "地址"), text: optional($merchant.address))
                Picker(L.t("計算ルール", "計算規則"), selection: $merchant.key) { Text(L.t("一般加盟店", "一般店鋪")).tag("general"); Text("Amazon.co.jp").tag("amazon") }
                TextField(L.t("メモ", "備註"), text: $merchant.note, axis: .vertical)
            }
        }.navigationTitle(L.t("お店を編集", "編輯店鋪")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.t("取消", "取消")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(L.t("保存", "儲存")) { store.upsert(merchant); dismiss() }.disabled(merchant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
    }
}
func optional(_ value: Binding<String?>) -> Binding<String> { Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 }) }
