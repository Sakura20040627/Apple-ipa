import SwiftUI
import HexPickCore

let statisticalNotice = "相关胜率不等于选择该海克斯必然导致胜利。统计来自部分对局结束时的持有记录，不代表全服或因果效果。"
let bandNames = ["casual": "娱乐", "mid": "中分", "high": "高分", "top": "顶尖"]
func percent(_ value: Double?) -> String { value.map { String(format: "%.2f%%", $0 * 100) } ?? "—" }
func signedPP(_ value: Double?) -> String { value.map { String(format: "%+.2f 个百分点", $0 * 100) } ?? "—" }

struct HeroPortrait: View {
    let id: String
    let name: String
    var size: CGFloat = 64
    var body: some View {
        Group {
            if let image = UIImage(named: "hero_\(id)") {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack { Color.secondary.opacity(0.15); Text(String(name.prefix(1))).font(.title2.bold()) }
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityLabel(name)
    }
}
struct AugmentGlyph: View {
    let rarity: String
    var size: CGFloat = 42
    var color: Color {
        switch rarity { case "gold": return .yellow.opacity(0.75); case "prismatic": return .purple.opacity(0.7); default: return .secondary }
    }
    var body: some View {
        Image(systemName: rarity == "prismatic" ? "diamond" : "hexagon")
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(color).frame(width: size, height: size)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}
struct StatLabel: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(Theme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct RarityPicker: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var value: String
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { picker.pickerStyle(.menu) }
            else { picker.pickerStyle(.segmented) }
        }.frame(minHeight: 44)
    }
    private var picker: some View {
        Picker("稀有度", selection: $value) {
            Text("全部").tag(""); Text("白银").tag("silver")
            Text("黄金").tag("gold"); Text("棱彩").tag("prismatic")
        }

    }
}
struct BandPicker: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        if let data = store.dataset, !data.bands.isEmpty {
            Picker("统计分数段（非官方段位）", selection: $store.band) {
                Text("全体").tag("")
                ForEach(["casual", "mid", "high", "top"].filter { data.bands[$0] != nil }, id: \.self) { key in
                    Text(bandNames[key] ?? key).tag(key)
                }
            }
        }
    }
}
struct RecommendationCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let result: Recommendation
    var position: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                AugmentIcon(id: result.id, rarity: store.augments[result.id]?.rarity ?? "")
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.augments[result.id]?.name ?? "海克斯 \(result.id)").font(.headline)
                    Text(store.augments[result.id]?.rarityLabel ?? "未知稀有度").font(.caption).foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                if let position { RankBadge(rank: position) }
            }
            if let stat = result.stat {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) { metrics(stat) }
                    VStack(alignment: .leading, spacing: 16) { metrics(stat) }
                }
                Text("相对英雄基准 \(signedPP(result.delta)) · 保守评分 \(percent(result.score))")
                    .font(.caption).foregroundStyle(Theme.secondary)
                if stat.uncertain {
                    Label("样本量不足，谨慎参考", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(Theme.gold)
                }
            } else { Text("暂无足够数据").foregroundStyle(Theme.secondary) }
            Text(result.reason).font(.footnote).foregroundStyle(Theme.secondary)
        }.hexCard(rarity: store.augments[result.id]?.rarity)
            .accessibilityElement(children: .contain)
    }
    @ViewBuilder private func metrics(_ stat: Stat) -> some View {
        WinRateView(rate: stat.rate, title: "组合胜率")
        VStack(alignment: .leading, spacing: 6) {
            Text("样本 \(compactCount(stat.games)) 局").font(.subheadline)
                .accessibilityLabel("样本 \(stat.games) 局")
            Text("平滑胜率 \(percent(result.posterior))").font(.caption)
        }.foregroundStyle(Theme.secondary)
    }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        TabView {
            Tab("英雄", systemImage: "square.grid.2x2") { NavigationStack { HeroesView() } }
            Tab("三选一", systemImage: "rectangle.stack") { NavigationStack { CompareView() } }
            Tab("图鉴", systemImage: "hexagon") { NavigationStack { AugmentLibraryView() } }
            Tab("设置", systemImage: "gearshape") { NavigationStack { SettingsView() } }
        }.tint(Theme.blue)
            .hexBackground()
            .overlay {
                if store.dataset == nil {
                    if let error = store.error {
                        ContentUnavailableView {
                            Label("暂时无法载入数据", systemImage: "wifi.exclamationmark")
                        } description: { Text(error) } actions: {
                            Button("重试") { Task { await store.update() } }.frame(minWidth: 44, minHeight: 44)
                        }.background(Theme.background)
                    } else { LoadingSkeleton().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background) }
                }
            }
    }
}
