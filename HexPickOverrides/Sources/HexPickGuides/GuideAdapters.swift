import Foundation

public protocol BuildGuideAdapter: Sendable {
    var source: GuideSource { get }
    var productionEnabled: Bool { get }
    func convert(_ payload: Data, context: AdapterContext) throws -> [BuildGuide]
}
public struct MayhempediaAdapter: BuildGuideAdapter {
    public let source: GuideSource = .mayhempedia
    public let productionEnabled = true
    public init() {}
    private struct File: Decodable {
        let championId: Int; let championName: String; let archetypes: [Route]
    }
    private struct Route: Decodable {
        let key: String; let name: String; let note: String?; let augments: Groups
        let items: [Reference]?; let starterItems: [Reference]?; let sources: [String]?
    }
    private struct Groups: Decodable { let core: [Reference]?; let good: [Reference]?; let trap: [Reference]? }
    private struct Reference: Decodable { let id: Int; let name: String }
    public func convert(_ payload: Data, context: AdapterContext) throws -> [BuildGuide] {
        try context.mayMetadata.validate()
        guard context.mayMetadata.source == source else { throw GuideError.missingAttribution }
        return try JSONDecoder().decode([File].self, from: payload).flatMap { file in
            file.archetypes.map { route in
                func augments(_ values: [Reference]?) -> [GuideAugment] {
                    (values ?? []).map { context.augment(source: "may", id: String($0.id), name: $0.name) }
                }
                func items(_ values: [Reference]?) -> [GuideItem] { (values ?? []).map { context.item(id: String($0.id), name: $0.name) } }
                let path = "https://github.com/boxsbraindump/Mayhempedia/blob/\(context.mayMetadata.revision)/data/builds/"
                // File links use champion aliases, not translated display names.
                let alias = context.champions.first(where: { $0.value.id == String(file.championId) })?.key ?? ""
                return BuildGuide(id: "may:\(file.championId):\(route.key)", heroID: String(file.championId), heroName: file.championName,
                                  title: route.name, kind: .build, core: augments(route.augments.core), good: augments(route.augments.good), trap: augments(route.augments.trap),
                                  starterItems: items(route.starterItems), items: items(route.items), explanation: route.note, synergies: [], tags: ["构筑攻略"],
                                  metadata: context.mayMetadata, sourceURL: URL(string: path + alias + ".json") ?? source.home,
                                  thirdPartySources: route.sources ?? [])
            }
        }
    }
}
public struct ARAMMayhemAdapter: BuildGuideAdapter {
    public let source: GuideSource = .aramMayhem
    public let productionEnabled = true
    public init() {}
    private struct Envelope: Decodable { let schemaVersion: Int; let rows: [Combo] }
    private struct Combo: Decodable {
        let comboId: Int; let championId: String; let augmentIds: [String]
        let augmentNames: [[String: String]]?; let types: [String]; let url: String
    }
    public func convert(_ payload: Data, context: AdapterContext) throws -> [BuildGuide] {
        try context.aramMetadata.validate()
        guard context.aramMetadata.source == source else { throw GuideError.missingAttribution }
        let document = try JSONDecoder().decode(Envelope.self, from: payload)
        guard document.schemaVersion == 1 else { throw GuideError.unsupportedSchema }
        return document.rows.map { row in
            let hero = context.champions[row.championId.lowercased()]
            let values = row.augmentIds.enumerated().map { index, id in
                let names = row.augmentNames.flatMap { index < $0.count ? $0[index] : nil }
                return context.augment(source: "aram", id: id, name: names?["zh-CN"] ?? names?["en"] ?? id)
            }
            let tags = row.types.map { ["god": "强力组合", "strong": "强力", "blackTech": "特殊玩法", "trap": "避坑"][ $0 ] ?? $0 }
            let link = URL(string: row.url).flatMap { $0.scheme == "https" && $0.host == "arammayhem.com" ? $0 : nil } ?? source.home
            let explanation = "来源编辑标签：\(tags.joined(separator: "、"))。公开数据未提供该组合的具体机制说明、装备顺序或强化胜率；可打开原始页面核对。"
            let synergy = values.count > 1 ? [GuideSynergy(id: "aram-combo:\(row.comboId)", title: "联动 · 组合标签", augments: values, explanation: explanation, sourceURL: link)] : []
            return BuildGuide(id: "aram:\(row.comboId)", heroID: hero?.id ?? "aram-hero:\(row.championId)", heroName: hero?.name ?? row.championId,
                              title: values.map(\.name).joined(separator: " + "), kind: .combination,
                              core: row.types.contains("trap") ? [] : values, good: [], trap: row.types.contains("trap") ? values : [], starterItems: [], items: [], explanation: nil,
                              synergies: synergy, tags: tags, metadata: context.aramMetadata, sourceURL: link, thirdPartySources: [])
        }
    }
    public struct ItemRow: Decodable, Sendable {
        public let itemId: String; public let gameItemId: String?; public let name: [String: String]
    }
    private struct ItemEnvelope: Decodable { let schemaVersion: Int; let rows: [ItemRow] }
    public func equipmentCatalog(_ payload: Data) throws -> [ItemRow] {
        let value = try JSONDecoder().decode(ItemEnvelope.self, from: payload)
        guard value.schemaVersion == 1 else { throw GuideError.unsupportedSchema }; return value.rows
    }
}
/// Interaction reference only: https://github.com/orange-guang/astrbot_plugin_hextech
/// That plugin obtains content from Apexlol. No plugin code, prose, payload or API is imported.
public struct AstrBotReferenceAdapter: BuildGuideAdapter {
    public let source: GuideSource = .astrBotReference
    public let productionEnabled = false
    public init() {}
    public func convert(_ payload: Data, context: AdapterContext) throws -> [BuildGuide] { throw GuideError.referenceOnly }
}
public struct GuideLibrary: Sendable {
    public let guides: [BuildGuide]
    public let context: AdapterContext
    public let mappingFailures: [IconMappingFailure]
    public let equipmentCount: Int
    public let equipment: [GuideItem]
    public static func bundled() throws -> GuideLibrary {
        func data(_ name: String) throws -> Data {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources") else { throw GuideError.unsupportedSchema }
            return try Data(contentsOf: url)
        }
        let decoder = JSONDecoder()
        let context = try decoder.decode(AdapterContext.self, from: data("GuideCatalog"))
        let may = try MayhempediaAdapter().convert(data("Mayhempedia"), context: context)
        let aram = try ARAMMayhemAdapter().convert(data("ARAMCombos"), context: context)
        let equipment = try ARAMMayhemAdapter().equipmentCatalog(data("ARAMItems"))
        // Deliberate concatenation, never dictionary(heroID) replacement or field-level merge.
        let guides = may + aram
        guard Set(guides.map(\.id)).count == guides.count else { throw GuideError.unsupportedSchema }
        return GuideLibrary(guides: guides, context: context,
                            mappingFailures: try decoder.decode([IconMappingFailure].self, from: data("IconMappingFailures")), equipmentCount: equipment.count,
                            equipment: equipment.map { item in
                                let name = item.name["zh-CN"] ?? item.name["en"] ?? item.itemId
                                return context.item(id: item.gameItemId ?? "aram-item:" + item.itemId, name: name)
                            })
    }
}
