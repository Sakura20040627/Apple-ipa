import SwiftUI
import HexPickGuides

struct DiscoverView: View {
    @Environment(GuideStore.self) private var store
    @State private var query = ""
    @State private var source = ""
    private var filtered: [BuildGuide] {
        store.guides.filter { guide in
            (source.isEmpty || guide.metadata.source.rawValue == source) &&
            (query.isEmpty || ([guide.heroName, guide.title] + guide.core.map(\.name) + guide.good.map(\.name) + guide.trap.map(\.name)).contains { $0.localizedStandardContains(query) })
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("发现你的下一套玩法").font(Theme.TypeScale.section)
                    Text("构筑攻略与组合标签 · 独立来源，不参与统计榜或三选一评分")
                        .font(.subheadline).foregroundStyle(Theme.secondary)
                    Text("内置带版本的资料快照；攻略不会因统计数据更新而被自动改写。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                    HStack {
                        NavigationLink { EquipmentCatalogView() } label: { Label("装备目录", systemImage: "shippingbox") }.frame(minHeight: 44)
                        Spacer()
                        NavigationLink { IconMappingReportView() } label: { Label("图标映射报告", systemImage: "checklist") }.frame(minHeight: 44)
                    }.font(.subheadline)
                }.hexCard()
                Picker("攻略来源", selection: $source) {
                    Text("全部来源").tag("")
                    Text("Mayhempedia 构筑").tag(GuideSource.mayhempedia.rawValue)
                    Text("ARAMMayhem 组合").tag(GuideSource.aramMayhem.rawValue)
                }.pickerStyle(.menu).frame(minHeight: 44)
                if let error = store.error {
                    Text(error).foregroundStyle(Theme.negative)
                    Button("重新载入攻略") { Task { await store.load() } }.frame(minHeight: 44)
                } else if store.library == nil { LoadingSkeleton() }
                else if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(filtered) { guide in
                    GuideCard(guide: guide, conflicts: GuideConflict.fields(for: guide, among: store.guides))
                        .task {
                            guard let index = filtered.firstIndex(where: { $0.id == guide.id }) else { return }
                            let next = filtered.dropFirst(index).prefix(3).flatMap { entry in
                                (entry.core + entry.good).map { $0.resource(version: entry.metadata.revision) } + entry.items.map { $0.resource(version: entry.metadata.revision) }
                            }
                            await ResourceIconCache.shared.prefetchResources(Array(next.prefix(8)))
                        }
                }
            }.padding(20)
        }.hexBackground().navigationTitle("发现")
            .searchable(text: $query, prompt: "英雄、流派或核心强化")
            .task { await store.load() }
    }
}
struct GuideCard: View {
    let guide: BuildGuide
    let conflicts: [String]
    @State private var expanded = false
    @State private var synergy: GuideSynergy?
    @State private var selectedItem: GuideItem?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                HeroPortrait(id: guide.heroID, name: guide.heroName, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(guide.heroName).font(.caption).foregroundStyle(Theme.secondary)
                    Text(guide.title).font(.headline)
                }
                Spacer(minLength: 0)
            }
            Text("\(guide.metadata.source.title) · \(guide.kind == .build ? "第三方构筑" : "编辑组合标签")")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.gold).padding(8)
                .background(Theme.gold.opacity(0.1), in: Capsule())
            Text(guide.warning).font(.caption).foregroundStyle(Theme.secondary)
            if !conflicts.isEmpty {
                DisclosureGroup {
                    Text(conflicts.joined(separator: "；") + "。不同来源条目分别保留；组合标签与完整构筑的范围也不同，不做合并或自动裁决。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                } label: { Label("来源方案存在差异", systemImage: "rectangle.split.2x1").font(.caption).foregroundStyle(Theme.gold) }
            }
            if guide.kind == .build {
                augmentSection("核心强化", entries: guide.core)
                augmentSection("备选强化", entries: guide.good)
                augmentSection("陷阱／避坑", entries: guide.trap, trap: true)
                itemSection("出门装", items: guide.starterItems)
                itemSection("成装顺序", items: guide.items, numbered: true)
                DisclosureGroup(isExpanded: $expanded) {
                    Text(guide.explanation?.isEmpty == false ? guide.explanation! : "来源未提供玩法说明。")
                        .font(.subheadline).foregroundStyle(Theme.secondary).textSelection(.enabled)
                } label: { Text("玩法理由 · 来源原文").font(.subheadline.weight(.semibold)) }
            } else {
                augmentSection(guide.trap.isEmpty ? "组合中的强化" : "来源标记为避坑", entries: guide.trap.isEmpty ? guide.core : guide.trap, trap: !guide.trap.isEmpty)
                Text("装备顺序／玩法长文：此公开数据未提供。")
                    .font(.caption).foregroundStyle(Theme.secondary)
                if !guide.tags.isEmpty { Text("编辑标签：" + guide.tags.joined(separator: "、")).font(.caption).foregroundStyle(Theme.blue) }
                else { Text("编辑标签：来源未提供").font(.caption).foregroundStyle(Theme.secondary) }
            }
            if !guide.synergies.isEmpty {
                ForEach(guide.synergies) { row in
                    Button { synergy = row } label: { Label(row.title, systemImage: "link").font(.subheadline.weight(.semibold)).frame(minHeight: 44) }
                }
            }
            Divider()
            GuideAttributionView(guide: guide)
        }.hexCard(rarity: "gold")
            .sheet(item: $selectedItem) { EquipmentDetailView(item: $0, version: guide.metadata.revision) }
            .sheet(item: $synergy) { value in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(value.augments.map(\.name).joined(separator: " + ")).font(.title2.bold())
                            Text(value.explanation).foregroundStyle(Theme.secondary)
                            Link("查看原始组合", destination: value.sourceURL).frame(minHeight: 44)
                            GuideAttributionView(guide: guide)
                        }.padding(20)
                    }.hexBackground().navigationTitle("联动说明")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { synergy = nil } } }
                }
            }
    }
    @ViewBuilder private func augmentSection(_ title: String, entries: [GuideAugment], trap: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: trap ? "exclamationmark.triangle" : "hexagon")
                .font(.subheadline.weight(.semibold)).foregroundStyle(trap ? Theme.negative : Theme.text)
            if entries.isEmpty { Text("来源未提供").font(.caption).foregroundStyle(Theme.secondary) }
            else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                ResourceIcon(request: entry.resource(version: guide.metadata.revision), size: 56, trap: trap)
                                Text(entry.name).font(.caption).fixedSize(horizontal: false, vertical: true)
                                if trap {
                                    Text(entry.trapReason ?? "来源未提供逐项原因").font(.caption2).foregroundStyle(Theme.negative)
                                    if let patch = entry.invalidSince { Text("来源标记失效版本：" + patch).font(.caption2).foregroundStyle(Theme.negative) }
                                }
                                if let note = entry.note { Text(note).font(.caption2).foregroundStyle(Theme.gold) }
                                if entry.availability == "legacy" || entry.availability == "retired" {
                                    Text("来源标为历史／下架；不保证当前有效").font(.caption2).foregroundStyle(Theme.negative)
                                }
                            }.frame(width: 100, alignment: .leading)
                        }
                    }.padding(.vertical, 4)
                }
                if trap { Text("来源将上述强化标为避坑，但未提供逐项原因或明确失效版本；需核对适用性。").font(.caption).foregroundStyle(Theme.negative) }
            }
        }
    }
    @ViewBuilder private func itemSection(_ title: String, items: [GuideItem], numbered: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            if items.isEmpty { Text("来源未提供").font(.caption).foregroundStyle(Theme.secondary) }
            else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 6) {
                                ResourceIcon(request: item.resource(version: guide.metadata.revision), size: 56)
                                    .onTapGesture { selectedItem = item }
                                    .accessibilityLabel(item.name + "，查看装备说明")
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { selectedItem = item }
                                Button { selectedItem = item } label: {
                                    Text((numbered ? "\(index + 1). " : "") + item.name)
                                        .font(.caption).frame(minHeight: 44, alignment: .topLeading)
                                }.buttonStyle(.plain).accessibilityLabel("查看\(item.name)装备说明")
                            }.frame(width: 100, alignment: .leading)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
    }
}
struct GuideAttributionView: View {
    let guide: BuildGuide
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("来源：\(guide.metadata.source.title) · \(guide.metadata.source.license)").font(.caption.weight(.semibold))
            Text(guide.metadata.source.author)
            if guide.metadata.source == .mayhempedia {
                Link("补充编辑资料 Data: arammayhem.com · CC BY 4.0", destination: URL(string: "https://arammayhem.com/data/")!).frame(minHeight: 44)
                Link("CC BY 4.0 协议", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).frame(minHeight: 44)
            }
            Text("适用版本：\(guide.metadata.patch)")
            Text("更新时间：\(guide.metadata.updatedAt)\n\(guide.metadata.updateMeaning)")
            Text("快照获取：\(guide.metadata.retrievedAt)")
            if !guide.thirdPartySources.isEmpty { Text("上游引用：" + guide.thirdPartySources.joined(separator: "、")) }
            Text("HexPick 修改：统一字段与本地化标签、图标映射；不改写来源的推荐顺序，不新增胜率。")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { links }
                VStack(alignment: .leading, spacing: 8) { links }
            }
        }.font(.caption).foregroundStyle(Theme.secondary).textSelection(.enabled)
    }
    @ViewBuilder private var links: some View {
        Link("原始来源", destination: guide.sourceURL).frame(minHeight: 44)
        Link(guide.metadata.source.license + " 协议", destination: guide.metadata.source.licenseURL).frame(minHeight: 44)
    }
}
struct EquipmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: GuideItem
    let version: String
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ResourceIcon(request: item.resource(version: version), size: 80)
                    Text(item.name).font(.title.bold())
                    Text(item.description?.isEmpty == false ? item.description! : "来源未提供此装备的说明。")
                    Text("装备 ID：\(item.id)\n\(item.catalogSource)").font(.caption).foregroundStyle(Theme.secondary)
                    Text("描述来自独立装备目录，不代表该构筑的效果已经实测验证。当前客户端说明也可能与攻略版本不同。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                    Link("Data: arammayhem.com · CC BY 4.0", destination: URL(string: "https://arammayhem.com/data/")!).frame(minHeight: 44)
                    Link("CC BY 4.0 协议", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).frame(minHeight: 44)
                }.padding(20)
            }.hexBackground().navigationTitle("装备说明")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
struct EquipmentCatalogView: View {
    @Environment(GuideStore.self) private var store
    @State private var query = ""
    @State private var selected: GuideItem?
    var body: some View {
        List {
            Section {
                Text("Data: arammayhem.com · CC BY 4.0\n装备目录仅作资料补充，不覆盖构筑的出装选择或顺序。说明与图标来自 CommunityDragon / Riot Games。")
                    .font(.caption).foregroundStyle(Theme.secondary)
                Link("来源与许可", destination: URL(string: "https://arammayhem.com/data/")!)
            }
            ForEach((store.library?.equipment ?? []).filter { query.isEmpty || $0.name.localizedStandardContains(query) }) { item in
                HStack(spacing: 12) {
                    ResourceIcon(request: item.resource(version: store.library?.context.aramMetadata.revision ?? "catalog"))
                        .onTapGesture { selected = item }
                        .accessibilityLabel(item.name + "，查看装备说明")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selected = item }
                    Button { selected = item } label: { Text(item.name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.buttonStyle(.plain)
                }.task {
                    let all = store.library?.equipment ?? []
                    if let i = all.firstIndex(where: { $0.id == item.id }) {
                        await ResourceIconCache.shared.prefetchResources(all.dropFirst(i + 1).prefix(8).map { $0.resource(version: store.library?.context.aramMetadata.revision ?? "catalog") })
                    }
                }
            }
        }.hexBackground().navigationTitle("装备目录").searchable(text: $query)
            .sheet(item: $selected) { EquipmentDetailView(item: $0, version: store.library?.context.aramMetadata.revision ?? "catalog") }
    }
}
struct IconMappingReportView: View {
    @Environment(GuideStore.self) private var store
    var body: some View {
        List {
            Section("装备映射") {
                let failures = store.library?.mappingFailures.filter { $0.kind == "item" } ?? []
                Text(failures.isEmpty ? "构筑与装备目录中的装备 ID 均已建立图标路径映射。失败 ID 清单：[]" : "以下装备没有可确认的 CommunityDragon 路径，使用占位图。")
                ForEach(failures, id: \.identity) { Text("\($0.source) · \($0.id) · \($0.name ?? "")") }
            }
            Section("强化映射失败 ID") {
                ForEach(store.library?.mappingFailures.filter { $0.kind == "augment" } ?? [], id: \.identity) { row in
                    Text("\(row.source) · \(row.id) · \(row.name ?? "")")
                }
                Text("不同来源使用各自命名空间，不能把 Mayhempedia 的本地数字 ID 当作 Riot ID。路径映射成功也不保证 CDN 永久可用；网络失败仍会显示占位和重试。")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
        }.hexBackground().navigationTitle("图标映射报告")
    }
}
