import SwiftUI
import HexPickCore

enum HeroSort: String, CaseIterable {
    case strength = "强度", name = "名称", win = "胜率", pick = "使用率"
}
struct HeroesView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var sort: HeroSort = .strength
    @State private var favoritesOnly = false
    private var ids: [String] {
        let filtered = store.heroes.keys.filter { id in
            guard let hero = store.heroes[id] else { return false }
            return (!favoritesOnly || store.favoriteHeroes.contains(id)) &&
                (search.isEmpty || hero.name.localizedStandardContains(search) || (hero.title?.localizedStandardContains(search) ?? false))
        }
        return filtered.sorted {
            guard let a = store.heroes[$0], let b = store.heroes[$1] else { return $0 < $1 }
            switch sort {
            case .strength: return a.rank == b.rank ? $0 < $1 : (a.rank ?? Int.max) < (b.rank ?? Int.max)
            case .name: return a.name == b.name ? $0 < $1 : a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .win: return a.winRate == b.winRate ? $0 < $1 : a.winRate > b.winRate
            case .pick: return a.pickRate == b.pickRate ? $0 < $1 : (a.pickRate ?? 0) > (b.pickRate ?? 0)
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("选好英雄，再选海克斯。").font(.title2.weight(.semibold))
                    if let data = store.dataset {
                        Text("\(data.manifest.patch) · \(data.manifest.modeLabel ?? "常规") · 数据截至")
                        Text(data.manifest.snapshotAt).textSelection(.enabled)
                    }
                    Text(store.status)
                    if let error = store.error { Text(error).foregroundStyle(Theme.gold) }
                }.font(.caption).foregroundStyle(Theme.secondary)
                BandPicker()
                if !store.recent.isEmpty && search.isEmpty && !favoritesOnly {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近查看").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(store.recent.filter { store.heroes[$0] != nil }, id: \.self) { id in
                                    NavigationLink { HeroDetailView(heroID: id) } label: {
                                        VStack { HeroPortrait(id: id, name: store.heroes[id]?.name ?? "", size: 52)
                                            Text(store.heroes[id]?.name ?? "").font(.caption).lineLimit(1) }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Text(favoritesOnly ? "收藏英雄" : "全部英雄").font(.headline)
                    Spacer()
                    Picker("排序", selection: $sort) { ForEach(HeroSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.menu)
                }
                if ids.isEmpty { ContentUnavailableView.search(text: search) }
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(stride(from: 0, to: ids.count, by: 20)), id: \.self) { start in
                        Section {
                            ForEach(Array(ids[start..<min(start + 20, ids.count)]), id: \.self) { id in
                                if let hero = store.heroes[id] {
                                    NavigationLink { HeroDetailView(heroID: id) } label: {
                                        HeroRow(id: id, hero: hero, favorite: store.favoriteHeroes.contains(id))
                                    }.buttonStyle(.plain).accessibilityIdentifier("hero-\(id)")
                                        .contextMenu { Button(store.favoriteHeroes.contains(id) ? "取消收藏" : "收藏", systemImage: "star") { store.toggleHero(id) } }
                                }
                            }
                        } header: {
                            Text("\(favoritesOnly ? "收藏" : "英雄") · \(start + 1)–\(min(start + 20, ids.count))")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                                .background(Theme.background)
                        }
                    }
                }
                Text("强度排序沿用数据源胜率排名，不额外编造强度分数。使用率指全部英雄出场中的占比。")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }.padding(20)
        }
        .hexBackground()
        .navigationTitle("海克斯大乱斗")
        .searchable(text: $search, prompt: "搜索英雄名称或称号")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(favoritesOnly ? "显示全部" : "显示收藏", systemImage: favoritesOnly ? "star.fill" : "star") { favoritesOnly.toggle() }
            }
        }
        .refreshable { await store.update() }
    }
}
struct HeroDetailView: View {
    @Environment(AppStore.self) private var store
    let heroID: String
    @State private var rarity = ""
    @State private var ordering: AugmentSort = .recommendation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var hero: Hero? { store.heroes[heroID] }
    private var results: [Recommendation] {
        let original = store.recommendations(heroID: heroID).filter { rarity.isEmpty || store.augments[$0.id]?.rarity == rarity }
        return original.sorted { a, b in
            let left: Double?, right: Double?
            switch ordering {
            case .recommendation: left = a.score; right = b.score
            case .win: left = a.stat?.rate; right = b.stat?.rate
            case .pick: left = a.stat.map { Double($0.games) }; right = b.stat.map { Double($0.games) }
            case .wilson: left = wilsonLower(a.stat); right = wilsonLower(b.stat)
            }
            return left == right ? a.id < b.id : (left ?? -1) > (right ?? -1)
        }
    }
    private var groups: [String] {
        let known = Theme.rarityOrder.filter { key in results.contains { store.augments[$0.id]?.rarity == key } }
        return known + (results.contains { !Theme.rarityOrder.contains(store.augments[$0.id]?.rarity ?? "") } ? [""] : [])
    }
    var body: some View {
        ScrollView {
            if let hero {
                VStack(alignment: .leading, spacing: 24) {
                    HeroHeader(id: heroID, hero: hero)
                    NavigationLink { CompareView(initialHeroID: heroID) } label: {
                        Label("开始三选一", systemImage: "rectangle.stack").font(.headline).padding(14).frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
                    BandPicker()
                    Text("推荐海克斯").font(.title2.bold())
                    RarityPicker(value: $rarity)
                    Picker("强化排序", selection: $ordering) {
                        ForEach(AugmentSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).frame(minHeight: 44)
                    Text(ordering == .wilson ? "Wilson 95% 下界仅用于此列表排序，不改变三选一推荐算法。" : "推荐使用原保守评分；持有率 = 当前英雄组合样本 ÷ 英雄出场次数，不代表强化出现概率。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                    if results.isEmpty { Text("当前筛选暂无足够数据").foregroundStyle(Theme.secondary) }
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.self) { group in
                            Section {
                                ForEach(results.filter { Theme.rarityGroup(store.augments[$0.id]?.rarity ?? "") == group }) { result in
                                    VStack(alignment: .leading, spacing: 6) {
                                        NavigationLink { AugmentDetailView(augmentID: result.id) } label: {
                                            RecommendationCard(result: result)
                                        }.buttonStyle(.plain)
                                        HStack {
                                            Text("持有率 \(percent(hero.games > 0 ? result.stat.map { Double($0.games) / Double(hero.games) } : nil))")
                                            if ordering == .wilson { Text("Wilson 下界 \(percent(wilsonLower(result.stat)))") }
                                        }.font(.caption).foregroundStyle(Theme.secondary).padding(.horizontal, 8)
                                    }.task { await prefetchIcons(after: result.id, in: results.map(\.id), store: store) }
                                }
                            } header: {
                                HStack { Text(Theme.rarityName(group)).font(.headline); Spacer()
                                    Text("\(results.filter { Theme.rarityGroup(store.augments[$0.id]?.rarity ?? "") == group }.count) 项").font(.caption)
                                }.foregroundStyle(Theme.rarityColor(group)).padding(.vertical, 12).background(Theme.background)
                            }
                        }
                    }.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: ordering)
                    equipment
                    spells
                    Text(statisticalNotice).font(.footnote).foregroundStyle(Theme.secondary)
                }.padding(20)
            } else { ContentUnavailableView("英雄暂无数据", systemImage: "person.crop.circle.badge.questionmark") }
        }
        .hexBackground()
        .navigationTitle(hero?.name ?? "英雄攻略").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("收藏英雄", systemImage: store.favoriteHeroes.contains(heroID) ? "star.fill" : "star") { store.toggleHero(heroID) }
            }
        }
        .onAppear { store.viewed(heroID) }
    }
    @ViewBuilder private var equipment: some View {
        if let table = store.dataset?.items[heroID], !table.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("装备参考 · 全体样本").font(.title2.bold())
                Text("仅适用于下列海克斯的持有者。第一条装备记录为代理，不证明实际绑定目标，不是通用出装顺序。")
                    .font(.caption).foregroundStyle(Theme.secondary)
                ForEach(table.keys.sorted(), id: \.self) { id in
                    if let reference = table[id] {
                        Text(store.augments[id]?.name ?? "海克斯 \(id)").font(.headline)
                        ForEach(reference.items.indices, id: \.self) { i in
                            let item = reference.items[i]
                            HStack {
                                EquipmentIcon(id: item.item, name: item.name, version: store.dataset?.manifest.patch ?? "latest")
                                Text(item.name); Spacer()
                                if reference.showWinrate == true { Text(percent(item.games > 0 ? Double(item.wins) / Double(item.games) : nil)).monospacedDigit() }
                                if reference.showSampleSize == true { Text("\(item.games) 局").foregroundStyle(Theme.secondary) }
                            }.font(.subheadline)
                        }
                        if let note = reference.note { Text("数据源注：\(note)").font(.caption).foregroundStyle(Theme.secondary) }
                    }
                }
            }
        }
    }
    @ViewBuilder private var spells: some View {
        if let table = store.dataset?.spells[heroID], !table.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("召唤师技能 · 全体样本").font(.title2.bold())
                Text("按使用次数列出前三组，非技能选择的因果效果。").font(.caption).foregroundStyle(Theme.secondary)
                ForEach(table.keys.sorted { (table[$0]?.games ?? 0) > (table[$1]?.games ?? 0) }.prefix(3), id: \.self) { key in
                    if let stat = table[key] {
                        HStack { Text(spellNames(key)); Spacer(); VStack(alignment: .trailing) {
                            Text(percent(stat.rate)); Text("\(stat.games.formatted()) 局").font(.caption).foregroundStyle(Theme.secondary)
                        } }.monospacedDigit()
                    }
                }
            }
        }
    }
    private func spellNames(_ combo: String) -> String {
        let names = ["1": "净化", "4": "闪现", "6": "幽灵疾步", "7": "治疗术", "13": "清晰术", "14": "引燃", "21": "屏障", "32": "标记"]
        return combo.split(separator: "+").map { names[String($0)] ?? "技能 \($0)" }.joined(separator: " + ")
    }
}


enum AugmentSort: String, CaseIterable {
    case recommendation = "推荐评分", win = "胜率", pick = "持有率", wilson = "Wilson 下界"
}
struct HeroRow: View {
    let id: String
    let hero: Hero
    var favorite = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                HeroPortrait(id: id, name: hero.name, size: 60)
                VStack(alignment: .leading, spacing: 5) {
                    Text(hero.name).font(.headline)
                    Text(hero.title ?? "").font(.caption).foregroundStyle(Theme.secondary)
                    if favorite { Label("已收藏", systemImage: "star.fill").font(.caption).foregroundStyle(Theme.gold) }
                }
                Spacer(minLength: 0)
                RankBadge(rank: hero.rank)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { metrics }
                VStack(alignment: .leading, spacing: 12) { metrics }
            }
        }.hexCard().frame(minHeight: 44).accessibilityElement(children: .combine)
    }
    @ViewBuilder private var metrics: some View {
        WinRateView(rate: hero.winRate)
        VStack(alignment: .leading, spacing: 5) {
            Text("出场率 \(percent(hero.pickRate))")
            Text("\(compactCount(hero.games)) 场").accessibilityLabel("\(hero.games) 场")
        }.font(.caption).foregroundStyle(Theme.secondary)
    }
}
struct HeroHeader: View {
    let id: String
    let hero: Hero
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack(alignment: .bottomLeading) {
                // Reuse bundled portrait: no additional hero asset downloads or fabricated splash art.
                if let image = UIImage(named: "hero_\(id)") {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 200).clipped().accessibilityHidden(true)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(hero.name).font(Theme.TypeScale.title)
                    Text(hero.title ?? "").font(.subheadline)
                }.foregroundStyle(.white).padding(20).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16)).padding(12)
            }.frame(minHeight: 200).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { metrics }
                VStack(alignment: .leading, spacing: 16) { metrics }
            }.frame(maxWidth: .infinity, alignment: .leading).hexCard()
        }
    }
    @ViewBuilder private var metrics: some View {
        WinRateView(rate: hero.winRate, title: "英雄胜率")
        VStack(alignment: .leading, spacing: 6) {
            Text("\(compactCount(hero.games)) 场").font(.subheadline).accessibilityLabel("\(hero.games) 场")
            Text("出场率 \(percent(hero.pickRate))").font(.caption)
        }.foregroundStyle(Theme.secondary)
        RankBadge(rank: hero.rank)
    }
}
