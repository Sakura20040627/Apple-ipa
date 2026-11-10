import Foundation

public enum GuideSource: String, Codable, CaseIterable, Sendable {
    case mayhempedia, aramMayhem, astrBotReference
    public var title: String {
        switch self { case .mayhempedia: return "Mayhempedia"; case .aramMayhem: return "ARAMMayhem"; case .astrBotReference: return "AstrBot（仅功能参考）" }
    }
    public var author: String { self == .mayhempedia ? "Copyright (c) 2026 Mayhempedia" : "Data: arammayhem.com" }
    public var license: String { self == .mayhempedia ? "MIT" : self == .aramMayhem ? "CC BY 4.0" : "不接入内容" }
    public var licenseURL: URL {
        URL(string: self == .mayhempedia ? "https://github.com/boxsbraindump/Mayhempedia/blob/main/LICENSE" : "https://creativecommons.org/licenses/by/4.0/")!
    }
    public var home: URL { URL(string: self == .mayhempedia ? "https://github.com/boxsbraindump/Mayhempedia" : "https://arammayhem.com/data/")! }
}
public struct GuideMetadata: Codable, Sendable, Equatable {
    public let source: GuideSource
    public let patch: String
    public let updatedAt: String
    public let updateMeaning: String
    public let retrievedAt: String
    public let revision: String
    public init(source: GuideSource, patch: String, updatedAt: String, updateMeaning: String, retrievedAt: String, revision: String) {
        self.source = source; self.patch = patch; self.updatedAt = updatedAt; self.updateMeaning = updateMeaning; self.retrievedAt = retrievedAt; self.revision = revision
    }
    public func validate() throws {
        guard [patch, updatedAt, updateMeaning, retrievedAt, revision].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw GuideError.missingAttribution }
        guard source != .astrBotReference else { throw GuideError.referenceOnly }
    }
}
public struct GuideAugment: Codable, Sendable, Identifiable, Hashable {
    /// Namespaced identity, e.g. may:41; NEVER used as a Riot runtime id.
    public let id: String
    public let sourceID: String
    public let riotID: String?
    public let name: String
    public let rarity: String
    public let iconURL: String?
    public let availability: String
    public let note: String?
    public init(id: String, sourceID: String, riotID: String?, name: String, rarity: String, iconURL: String?, availability: String = "unknown", note: String? = nil) {
        self.id = id; self.sourceID = sourceID; self.riotID = riotID; self.name = name; self.rarity = rarity; self.iconURL = iconURL; self.availability = availability; self.note = note
    }
}
public struct GuideItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let iconURL: String?
    public let description: String?
    public let catalogSource: String
    public init(id: String, name: String, iconURL: String?, description: String?, catalogSource: String) {
        self.id = id; self.name = name; self.iconURL = iconURL; self.description = description; self.catalogSource = catalogSource
    }
}
public struct GuideSynergy: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let augments: [GuideAugment]
    public let explanation: String
    public let sourceURL: URL
}
public struct BuildGuide: Sendable, Identifiable {
    public enum Kind: String, Sendable { case build, combination }
    public let id: String
    public let heroID: String
    public let heroName: String
    public let title: String
    public let kind: Kind
    public let core: [GuideAugment]
    public let good: [GuideAugment]
    public let trap: [GuideAugment]
    public let starterItems: [GuideItem]
    public let items: [GuideItem]
    public let explanation: String?
    public let synergies: [GuideSynergy]
    public let tags: [String]
    public let metadata: GuideMetadata
    public let sourceURL: URL
    public let thirdPartySources: [String]
    public var warning: String {
        kind == .build ? "部分内容引自第三方，版本和时效需核对；不是官方攻略，也不是本应用统计结论。" : "仅公开组合与编辑标签；来源不提供强化胜率或完整中文玩法长文。"
    }
}
public enum GuideError: Error, LocalizedError, Sendable {
    case missingAttribution, unsupportedSchema, referenceOnly, invalidHero
    public var errorDescription: String? {
        switch self {
        case .missingAttribution: return "攻略缺少必需的来源、版本或更新时间，已拒绝载入。"
        case .unsupportedSchema: return "不支持此攻略数据格式。"
        case .referenceOnly: return "AstrBot 仅作功能参考，不接入 Apexlol 生产数据。"
        case .invalidHero: return "攻略的英雄标识无法映射。"
        }
    }
}
public struct HeroIdentity: Codable, Sendable { public let id: String; public let name: String }
public struct AdapterContext: Codable, Sendable {
    public let augments: [String: GuideAugment]
    public let items: [String: GuideItem]
    public let champions: [String: HeroIdentity]
    public let mayMetadata: GuideMetadata
    public let aramMetadata: GuideMetadata
    public func augment(source: String, id: String, name: String) -> GuideAugment {
        augments[source + ":" + id] ?? GuideAugment(id: source + ":" + id, sourceID: id, riotID: nil, name: name, rarity: "", iconURL: nil)
    }
    public func item(id: String, name: String) -> GuideItem {
        guard let row = items[id] else { return GuideItem(id: id, name: name, iconURL: nil, description: nil, catalogSource: "来源未提供装备详情") }
        // Preserve upstream item naming and order; enrich only cosmetic metadata, never the choice itself.
        return GuideItem(id: id, name: name, iconURL: row.iconURL, description: row.description, catalogSource: row.catalogSource)
    }
}
public struct IconMappingFailure: Codable, Sendable, Identifiable {
    public let kind: String
    public let source: String
    public let id: String
    public let name: String?
    public var identity: String { kind + ":" + source + ":" + id }
}
/// Source-independent presentation only. No imports of HexPickCore, no win-rate fields or scorer.
public enum GuideConflict {
    public static func fields(for guide: BuildGuide, among all: [BuildGuide]) -> [String] {
        let others = all.filter { $0.heroID == guide.heroID && $0.metadata.source != guide.metadata.source }
        func keys(_ values: [GuideAugment]) -> Set<String> { Set(values.map { $0.riotID.map { "riot:" + $0 } ?? "name:" + $0.name }) }
        var result: [String] = []
        if others.contains(where: { !$0.core.isEmpty && !guide.core.isEmpty && keys($0.core) != keys(guide.core) }) { result.append("核心强化列表不同") }
        if others.contains(where: { !$0.good.isEmpty && !guide.good.isEmpty && keys($0.good) != keys(guide.good) }) { result.append("备选强化列表不同") }
        if others.contains(where: { !$0.trap.isEmpty && !guide.core.isEmpty && !keys($0.trap).isDisjoint(with: keys(guide.core)) }) { result.append("核心与避坑标签存在交叉") }
        if others.contains(where: { !$0.core.isEmpty && !guide.trap.isEmpty && !keys($0.core).isDisjoint(with: keys(guide.trap)) }) { result.append("避坑与核心标签存在交叉") }
        if others.contains(where: { !$0.items.isEmpty && !guide.items.isEmpty && $0.items.map(\.id) != guide.items.map(\.id) }) { result.append("装备顺序不同") }
        if others.contains(where: { !$0.starterItems.isEmpty && !guide.starterItems.isEmpty && $0.starterItems.map(\.id) != guide.starterItems.map(\.id) }) { result.append("出门装不同") }
        return result
    }
}
