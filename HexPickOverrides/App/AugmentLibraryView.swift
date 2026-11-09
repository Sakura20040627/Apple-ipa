import SwiftUI
import HexPickCore

struct AugmentLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var rarity = ""
    @State private var favoritesOnly = false
    private var ids: [String] {
        store.augments.keys.filter { id in
            guard let a = store.augments[id] else { return false }
            return (search.isEmpty || a.name.localizedStandardContains(search)) &&
                (rarity.isEmpty || a.rarity == rarity) && (!favoritesOnly || store.favoriteAugments.contains(id))
        }.sorted { (store.augments[$0]?.name ?? "").localizedStandardCompare(store.augments[$1]?.name ?? "") == .orderedAscending }
    }
    var body: some View {
        List {
            Section {
                RarityPicker(value: $rarity)
                Text("游戏图标按需加载；未匹配或离线时显示稀有度符号，点击重试按钮可重新加载。")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
            ForEach(Theme.rarityOrder + [""], id: \.self) { group in
                let groupIDs = ids.filter { Theme.rarityGroup(store.augments[$0]?.rarity ?? "") == group }
                if !groupIDs.isEmpty {
                    Section(Theme.rarityName(group)) {
                        ForEach(groupIDs, id: \.self) { id in
                            if let augment = store.augments[id] {
                                NavigationLink { AugmentDetailView(augmentID: id) } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        AugmentIcon(id: id, rarity: augment.rarity)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(augment.name).font(.headline)
                                            Text(augment.rarityLabel).font(.caption).foregroundStyle(Theme.rarityColor(augment.rarity))
                                        }
                                        Spacer(minLength: 0)
                                        if store.favoriteAugments.contains(id) { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.gold).accessibilityLabel("已收藏") }
                                    }.padding(.vertical, 8).frame(minHeight: 44)
                                }
                                .task { await prefetchIcons(after: id, in: ids, store: store) }
                                .swipeActions { Button(store.favoriteAugments.contains(id) ? "取消收藏" : "收藏", systemImage: "star") { store.toggleAugment(id) }.tint(Theme.blue) }
                            }
                        }
                    }
                }
            }
            if ids.isEmpty { ContentUnavailableView.search(text: search) }
        }
        .hexBackground()
        .navigationTitle("海克斯图鉴").searchable(text: $search, prompt: "搜索中文名称")
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button("仅看收藏", systemImage: favoritesOnly ? "star.fill" : "star") { favoritesOnly.toggle() }
        } }
    }
}
struct AugmentDetailView: View {
    @Environment(AppStore.self) private var store
    let augmentID: String
    private var compatibleHeroes: [(id: String, result: Recommendation)] {
        store.heroes.keys.compactMap { id -> (id: String, result: Recommendation)? in
            guard let result = store.recommendations(heroID: id, ids: [augmentID]).first, result.score != nil else { return nil }
            return (id, result)
        }.sorted {
            if $0.result.score == $1.result.score { return $0.id < $1.id }
            return ($0.result.score ?? -1) > ($1.result.score ?? -1)
        }
    }
    private var total: Stat {
        let values = store.combinations.values.compactMap { $0[augmentID] }
        return Stat(games: values.reduce(0) { $0 + $1.games }, wins: values.reduce(0) { $0 + $1.wins })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    AugmentIcon(id: augmentID, rarity: store.augments[augmentID]?.rarity ?? "", size: 80)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.augments[augmentID]?.name ?? augmentID).font(.title.bold())
                        Text(store.augments[augmentID]?.rarityLabel ?? "").foregroundStyle(Theme.secondary)
                    }
                }
                BandPicker()
                if total.games > 0 {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) { totalMetrics }
                        VStack(alignment: .leading, spacing: 16) { totalMetrics }
                    }.hexCard(rarity: store.augments[augmentID]?.rarity)
                } else { Text("暂无足够数据").foregroundStyle(Theme.secondary) }
                Text("适配英雄").font(.title2.bold())
                Text("按各英雄组合的保守评分排序。总体持有胜率不会替代英雄专属推荐。")
                    .font(.caption).foregroundStyle(Theme.secondary)
                LazyVStack(spacing: 16) {
                    ForEach(Array(compatibleHeroes.prefix(20)), id: \.id) { row in
                        NavigationLink { HeroDetailView(heroID: row.id) } label: {
                            HStack {
                                HeroPortrait(id: row.id, name: store.heroes[row.id]?.name ?? "", size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.heroes[row.id]?.name ?? row.id)
                                    Text("\(row.result.stat?.games.formatted() ?? "0") 局\(row.result.stat?.uncertain == true ? " · 样本量不足" : "")")
                                        .font(.caption).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    WinRateView(rate: row.result.stat?.rate, title: "组合胜率")
                                    Text("平滑 \(percent(row.result.posterior))").font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }.padding(12).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                }
                Text(statisticalNotice).font(.footnote).foregroundStyle(Theme.secondary)
            }.padding(20)
        }
        .hexBackground()
        .navigationTitle("海克斯详情").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button("收藏海克斯", systemImage: store.favoriteAugments.contains(augmentID) ? "star.fill" : "star") { store.toggleAugment(augmentID) }
        } }
    }
    @ViewBuilder private var totalMetrics: some View {
        WinRateView(rate: total.rate, title: "全英雄持有胜率")
        Text("\(compactCount(total.games)) 持有人次\n非独立对局")
            .font(.caption).foregroundStyle(Theme.secondary)
            .accessibilityLabel("\(total.games) 持有人次，非独立对局")
    }

}
