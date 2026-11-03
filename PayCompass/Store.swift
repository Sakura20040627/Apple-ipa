import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
@MainActor final class Store: ObservableObject {
    @Published var db: Database { didSet { save() } }
    @Published var error: String?
    @Published var currentTab = 0
    @Published var selectedMerchant: UUID?
    private let url: URL
    init() {
        url = URL.documentsDirectory.appending(path: "paycompass.json")
        db = Seed.database
        var loaded = true
        if FileManager.default.fileExists(atPath: url.path) {
            do { db = try Self.decode(Data(contentsOf: url)) }
            catch { loaded = false; self.error = L.t("保存データを読み込めませんでした。\n", "無法讀取儲存資料。\n") + error.localizedDescription }
        }
        if loaded && UserDefaults.standard.integer(forKey: "catalogRevision") < Catalog.revision {
            mergeCatalog()
            UserDefaults.standard.set(Catalog.revision, forKey: "catalogRevision")
            save()
        }
    }
    func mergeCatalog() {
        let seed = Seed.database
        for card in seed.cards where !db.cards.contains(where: { $0.name == card.name }) { db.cards.append(card) }
        for i in db.cards.indices {
            if let template = seed.cards.first(where: { $0.name == db.cards[i].name }) {
                if db.cards[i].issuer == nil { db.cards[i].issuer = template.issuer }
                if db.cards[i].pointsName == nil { db.cards[i].pointsName = template.pointsName }
                if db.cards[i].brands == nil { db.cards[i].brands = template.brands }
                if db.cards[i].annualFee == nil { db.cards[i].annualFee = template.annualFee; db.cards[i].annualFeeZH = template.annualFeeZH }
                if db.cards[i].details == nil { db.cards[i].details = template.details; db.cards[i].detailsZH = template.detailsZH }
                if db.cards[i].noteZH == nil { db.cards[i].noteZH = template.noteZH }
                if db.cards[i].color == nil { db.cards[i].color = template.color }
            }
        }
        for merchant in seed.merchants where !db.merchants.contains(where: { $0.name == merchant.name && $0.latitude == nil }) { db.merchants.append(merchant) }
        for i in db.merchants.indices {
            if let template = seed.merchants.first(where: { $0.name == db.merchants[i].name }) {
                if db.merchants[i].icon == nil { db.merchants[i].icon = template.icon }
                if db.merchants[i].color == nil { db.merchants[i].color = template.color }
                if db.merchants[i].aliases == nil { db.merchants[i].aliases = template.aliases }
            }
        }
    }
    func toggleFavorite(_ id: UUID) {
        guard let i = db.merchants.firstIndex(where: { $0.id == id }) else { return }
        db.merchants[i].favorite = !(db.merchants[i].favorite ?? false)
    }
    func upsert(_ merchant: Merchant) {
        if let i = db.merchants.firstIndex(where: { $0.id == merchant.id }) { db.merchants[i] = merchant }
        else { db.merchants.append(merchant) }
    }
    static func decode(_ data: Data) throws -> Database {
        guard data.count <= 5_000_000 else { throw ValidationError.invalid }
        let value = try JSONDecoder().decode(Database.self, from: data)
        guard value.version == 1, value.cards.count <= 500, value.merchants.count <= 5000, value.campaigns.count <= 1000,
              Set(value.cards.map(\.id)).count == value.cards.count,
              Set(value.merchants.map(\.id)).count == value.merchants.count,
              Set(value.campaigns.map(\.id)).count == value.campaigns.count,
              value.cards.allSatisfy({ !$0.name.isEmpty && $0.rate.isFinite && (0...100).contains($0.rate) && (1...100000).contains($0.unit) && ["custom", "amazon", "paypay"].contains($0.kind) }),
              value.merchants.allSatisfy({ m in
                  !m.name.isEmpty && ["general", "amazon"].contains(m.key) &&
                  (m.latitude == nil || (m.latitude!.isFinite && (-90...90).contains(m.latitude!))) &&
                  (m.longitude == nil || (m.longitude!.isFinite && (-180...180).contains(m.longitude!))) &&
                  ((m.latitude == nil) == (m.longitude == nil))
              }),
              value.campaigns.allSatisfy({ c in value.cards.contains(where: { $0.id == c.cardID }) && value.merchants.contains(where: { $0.id == c.merchantID }) && c.bonus.isFinite && (0...100).contains(c.bonus) && (0...100000000).contains(c.cap) && c.start <= c.end }) else { throw ValidationError.invalid }
        return value
    }
    enum ValidationError: LocalizedError { case invalid; var errorDescription: String? { L.t("JSONの形式・範囲・参照IDが不正です（上限5MB）。", "JSON 格式、數值範圍或參照 ID 有誤（上限 5 MB）。") } }
    func save() {
        do { try JSONEncoder().encode(db).write(to: url, options: [.atomic, .completeFileProtection]) }
        catch { self.error = L.t("保存に失敗しました：", "儲存失敗：") + error.localizedDescription }
    }
    func importData(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { let incoming = try Self.decode(Data(contentsOf: url)); db = incoming }
        catch { self.error = error.localizedDescription }
    }
    func exportData() -> Data { (try? JSONEncoder().encode(db)) ?? Data() }
    func deleteCard(_ id: UUID) { db.campaigns.removeAll { $0.cardID == id }; db.cards.removeAll { $0.id == id } }
    func deleteMerchant(_ id: UUID) { db.campaigns.removeAll { $0.merchantID == id }; db.merchants.removeAll { $0.id == id } }
}
