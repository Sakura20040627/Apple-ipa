import SwiftUI
import MapKit

struct NearbyView: View {
    @EnvironmentObject private var store: Store
    @StateObject private var nearby = NearbyStore()
    @State private var query = ""
    @State private var category = "すべて"
    @State private var selected: NearbyPlace?
    @State private var showMap = true
    @State private var position: MapCameraPosition = .automatic
    var sortedPlaces: [NearbyPlace] {
        nearby.places.sorted {
            let a = nearby.savedMerchant($0, in: store.db.merchants)?.favorite == true
            let b = nearby.savedMerchant($1, in: store.db.merchants)?.favorite == true
            return a != b ? a : $0.distance < $1.distance
        }
    }
    private func refresh() { nearby.refresh(query: query, category: category) }
    var body: some View {
        List {
            Section {
                HStack { Label(L.t("約3km以内", "約 3 公里內"), systemImage: "location.circle"); Spacer(); Button(L.t("更新", "重新整理"), systemImage: "arrow.clockwise") { refresh() }.disabled(nearby.loading) }
                Text(L.t("ボタンを押すと位置情報を使ってAppleマップで検索します。結果・距離は目安で、網羅的ではありません。", "按下搜尋後，將使用位置資訊透過 Apple 地圖查詢。結果並非完整店鋪名單，距離為直線概算。")).font(.caption).foregroundStyle(.secondary)
                if nearby.location == nil && !nearby.loading { Button(L.t("現在地から検索", "搜尋目前位置附近店鋪"), systemImage: "location.fill") { refresh() }.buttonStyle(.borderedProminent) }
                if nearby.loading { HStack { ProgressView(); Text(L.t("周辺を検索中…", "正在搜尋附近店鋪…")) } }
                if let message = nearby.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if nearby.denied { Button(L.t("位置情報の設定を開く", "開啟定位權限設定")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
            }
            if !nearby.places.isEmpty {
                Section {
                    Toggle(L.t("地図を表示", "顯示地圖"), isOn: $showMap)
                    if showMap {
                        Map(position: $position) {
                            UserAnnotation()
                            ForEach(nearby.places.prefix(30)) { place in
                                Annotation(place.name, coordinate: place.coordinate) { Button { selected = place } label: { MerchantBadge(merchant: nearby.merchant(for: place, in: store.db.merchants), size: 34) }.buttonStyle(.plain) }
                            }
                        }.mapControls { MapCompass(); MapScaleView() }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                Section(L.t("近くのお店 · お気に入り優先、その後距離順", "附近店鋪 · 收藏置頂，其餘依距離排序")) {
                    ForEach(sortedPlaces) { place in
                        HStack(spacing: 10) {
                            Button { selected = place } label: {
                                HStack(spacing: 12) { MerchantBadge(merchant: nearby.merchant(for: place, in: store.db.merchants)); VStack(alignment: .leading, spacing: 4) { Text(place.name).font(.headline); Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Text(place.distanceLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }.foregroundStyle(.primary).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button { toggleFavorite(place) } label: { Image(systemName: nearby.savedMerchant(place, in: store.db.merchants)?.favorite == true ? "star.fill" : "star").foregroundStyle(.orange).padding(6) }.buttonStyle(.borderless).accessibilityLabel(L.t("お気に入り切替", "切換收藏"))
                        }.padding(.vertical, 6)
                    }
                }
            }
        }.safeAreaInset(edge: .top) { CategoryStrip(selected: $category).padding(.vertical, 8).background(.bar) }
        .navigationTitle(L.t("近くのお店", "附近店鋪"))
        .searchable(text: $query, prompt: L.t("店名・キーワードを入力して検索", "輸入店名或關鍵字後搜尋"))
        .onSubmit(of: .search) { refresh() }
        .onChange(of: category) { _, _ in if nearby.location != nil { refresh() } }
        .onChange(of: nearby.places.map(\.id)) { _, _ in position = .automatic }
        .sheet(item: $selected) { place in NearbyDetail(place: place, merchant: nearby.merchant(for: place, in: store.db.merchants), chainID: nearby.matchedMerchant(place, in: store.db.merchants)?.id) }
    }
    private func toggleFavorite(_ place: NearbyPlace) {
        if let existing = nearby.savedMerchant(place, in: store.db.merchants) { store.toggleFavorite(existing.id) }
        else { var merchant = nearby.merchant(for: place, in: store.db.merchants); merchant.favorite = true; store.upsert(merchant) }
    }
}
struct NearbyDetail: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let place: NearbyPlace
    let merchant: Merchant
    let chainID: UUID?
    @State private var added = false
    var body: some View {
        NavigationStack { List {
            Section { HStack { MerchantBadge(merchant: merchant, size: 64); VStack(alignment: .leading, spacing: 6) { Text(place.name).font(.title2.bold()); Text(place.distanceLabel).foregroundStyle(.secondary) } }.padding(.vertical, 12); Text(place.address).textSelection(.enabled) }
            Section {
                Button { place.item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) } label: { Label(L.t("徒歩で案内", "步行導航"), systemImage: "figure.walk") }
                Button { place.item.openInMaps() } label: { Label(L.t("Appleマップで詳細を見る", "在 Apple 地圖查看詳情"), systemImage: "map") }
                if let phone = place.item.phoneNumber { Text(phone).textSelection(.enabled) }
                if let url = place.item.url { SafeLink(url: url.absoluteString) }
            }
            Section {
                Button {
                    if let existing = store.db.merchants.first(where: { $0.name == place.name && $0.latitude == merchant.latitude && $0.longitude == merchant.longitude }) { if existing.favorite != true { store.toggleFavorite(existing.id) } }
                    else { var value = merchant; value.favorite = true; store.upsert(value) }
                    added = true
                } label: { Label(added ? L.t("お気に入りに保存済み", "已加入收藏") : L.t("この店舗をお気に入りに保存", "收藏這間分店並置頂"), systemImage: added ? "star.fill" : "star") }.disabled(added)
                if let chainID {
                    Button { store.selectedMerchant = chainID; store.currentTab = 0; dismiss() } label: { Label(L.t("このチェーンの支払いを比較", "比較此連鎖店的支付回饋"), systemImage: "sparkles") }
                } else {
                    Text(L.t("対応するカードルールは未登録です。一般加盟店として保存し、条件を確認して編集できます。", "尚未辨識此店的卡片規則；可先收藏，再依官方條件編輯。一般回饋不代表保證可刷卡。")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text(L.t("店舗情報：Appleマップ。営業時間・決済可否は店舗へご確認ください。現在地はアプリの独自サーバーに送信しません。", "店鋪資訊來自 Apple 地圖，營業時間與支付方式請向店家確認。App 不會將目前位置傳送至自建伺服器。")).font(.caption).foregroundStyle(.secondary)
        }.navigationTitle(L.t("店舗の詳細", "分店資訊")).navigationBarTitleDisplayMode(.inline).toolbar { Button(L.t("閉じる", "關閉")) { dismiss() } } }
    }
}
