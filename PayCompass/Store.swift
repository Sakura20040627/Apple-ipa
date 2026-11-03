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
    private let url: URL
    init() {
        url = URL.documentsDirectory.appending(path: "paycompass.json")
        db = Seed.database
        if FileManager.default.fileExists(atPath: url.path) {
            do { db = try Self.decode(Data(contentsOf: url)) }
            catch { self.error = "保存データを読み込めませんでした。元ファイルは保持されています。\n\(error.localizedDescription)" }
        }
    }
    static func decode(_ data: Data) throws -> Database {
        guard data.count <= 5_000_000 else { throw ValidationError.invalid }
        let value = try JSONDecoder().decode(Database.self, from: data)
        guard value.version == 1, value.cards.count <= 500, value.merchants.count <= 5000, value.campaigns.count <= 1000,
              Set(value.cards.map(\.id)).count == value.cards.count,
              Set(value.merchants.map(\.id)).count == value.merchants.count,
              Set(value.campaigns.map(\.id)).count == value.campaigns.count,
              value.cards.allSatisfy({ !$0.name.isEmpty && $0.rate.isFinite && (0...100).contains($0.rate) && (1...100000).contains($0.unit) && ["custom", "amazon", "paypay"].contains($0.kind) }),
              value.merchants.allSatisfy({ !$0.name.isEmpty }),
              value.campaigns.allSatisfy({ c in value.cards.contains(where: { $0.id == c.cardID }) && value.merchants.contains(where: { $0.id == c.merchantID }) && c.bonus.isFinite && (0...100).contains(c.bonus) && (0...100000000).contains(c.cap) && c.start <= c.end }) else { throw ValidationError.invalid }
        return value
    }
    enum ValidationError: LocalizedError { case invalid; var errorDescription: String? { "JSONの形式・範囲・参照IDが不正です（上限5MB）。" } }
    func save() {
        do { try JSONEncoder().encode(db).write(to: url, options: [.atomic, .completeFileProtection]) }
        catch { self.error = "保存に失敗しました: \(error.localizedDescription)" }
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
