import SwiftUI
import HexPickCore
import CryptoKit
import ImageIO

/// Only cosmetic metadata is fetched here. Statistical data never passes through this service.
actor AugmentIconCache {
    static let shared = AugmentIconCache()
    private static let base = URL(string: "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/zh_cn/")!
    private let memory = NSCache<NSString, NSData>()
    private let directory: URL
    private var pending: [String: Task<Data, Error>] = [:]
    private var failed: [String: Date] = [:]
    private var memoryDates: [String: Date] = [:]
    private var metadata: [Entry]?
    private var metadataDate = Date.distantPast
    private var metadataTask: Task<Data, Error>?
    private var cleaned = false
    private let iconTTL: TimeInterval = 7 * 24 * 3600
    private let manifestTTL: TimeInterval = 24 * 3600
    private let schema = "icons-v1"
    struct Entry: Decodable, Sendable {
        let id: Int
        let nameTRA: String
        let rarity: String
        let augmentSmallIconPath: String
    }
    enum Failure: Error { case unmapped, invalidResponse, coolingDown }
    init() {
        directory = URL.cachesDirectory.appendingPathComponent("HexPickIcons-v1", isDirectory: true)
        memory.totalCostLimit = 24 * 1024 * 1024
        memory.countLimit = 250
    }
    private func key(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    private func fresh(_ file: URL, ttl: TimeInterval) -> Bool {
        guard let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return false }
        return Date().timeIntervalSince(date) < ttl
    }
    private func cleanDisk() {
        guard !cleaned else { return }; cleaned = true
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        let dated = files.compactMap { url -> (URL, Date, Int)? in
            guard let v = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (url, v.contentModificationDate ?? .distantPast, v.fileSize ?? 0)
        }.sorted { $0.1 > $1.1 }
        var size = 0
        for (url, date, bytes) in dated {
            size += bytes
            if Date().timeIntervalSince(date) > iconTTL || size > 100 * 1024 * 1024 { try? FileManager.default.removeItem(at: url) }
        }
    }
    private static func download(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("HexPick/1.1", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.host == "raw.communitydragon.org",
              response.expectedContentLength <= Int64(limit) else { throw Failure.invalidResponse }
        var result = Data()
        for try await byte in bytes {
            guard result.count < limit else { throw Failure.invalidResponse }
            result.append(byte)
        }
        return result
    }
    private func entries(force: Bool) async throws -> [Entry] {
        if !force, let metadata, Date().timeIntervalSince(metadataDate) < manifestTTL { return metadata }
        let file = directory.appendingPathComponent("cherry-augments.json")
        if !force, fresh(file, ttl: manifestTTL), let data = try? Data(contentsOf: file), let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            metadata = decoded; metadataDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return decoded
        }
        let task: Task<Data, Error>
        if let existing = metadataTask { task = existing }
        else {
            task = Task { try await Self.download(Self.base.appendingPathComponent("v1/cherry-augments.json"), limit: 5_000_000) }
            metadataTask = task
        }
        do {
            let bytes = try await task.value
            let decoded = try JSONDecoder().decode([Entry].self, from: bytes)
            metadata = decoded; metadataDate = Date(); metadataTask = nil
            try? bytes.write(to: file, options: .atomic)
            return decoded
        } catch {
            metadataTask = nil
            // Bounded stale fallback: useful offline, but never keep an obsolete mapping indefinitely.
            if fresh(file, ttl: iconTTL), let bytes = try? Data(contentsOf: file), let decoded = try? JSONDecoder().decode([Entry].self, from: bytes) { return decoded }
            throw error
        }
    }
    func image(id: String, name: String, rarity: String, version: String, force: Bool = false) async throws -> Data {
        cleanDisk()
        let requestKey = key("\(schema)|\(version)|\(id)|\(name)|\(rarity)")
        if !force, let date = failed[requestKey], Date().timeIntervalSince(date) < 30 { throw Failure.coolingDown }
        if !force, let date = memoryDates[requestKey], Date().timeIntervalSince(date) < iconTTL, let data = memory.object(forKey: requestKey as NSString) { return data as Data }
        let disk = directory.appendingPathComponent(requestKey + ".png")
        if !force, fresh(disk, ttl: iconTTL), let data = try? Data(contentsOf: disk) {
            memory.setObject(data as NSData, forKey: requestKey as NSString, cost: data.count); memoryDates[requestKey] = (try? disk.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date(); return data
        }
        if let task = pending[requestKey] { return try await task.value }
        let task = Task<Data, Error> {
            let rows = try await self.entries(force: force)
            let expectedRarity = ["silver": "kSilver", "gold": "kGold", "prismatic": "kPrismatic"][rarity]
            // Reject numeric collisions, renamed entries and wrong tiers rather than guessing an icon.
            guard let row = rows.first(where: { String($0.id) == id && $0.nameTRA == name && $0.rarity == expectedRarity }) else { throw Failure.unmapped }
            let prefix = "/lol-game-data/assets/"
            let path = row.augmentSmallIconPath.lowercased()
            guard path.hasPrefix(prefix), path.hasSuffix(".png"), !path.contains(".."), !path.contains("?"), !path.contains("#") else { throw Failure.invalidResponse }
            let url = Self.base.appendingPathComponent(String(path.dropFirst(prefix.count)))
            let data = try await Self.download(url, limit: 2_000_000)
            // Validate and downsample before persisting; discard huge or malformed image payloads.
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 256] as CFDictionary),
                  let encoded = UIImage(cgImage: image).pngData() else { throw Failure.invalidResponse }
            return encoded
        }
        pending[requestKey] = task
        do {
            let data = try await task.value; pending[requestKey] = nil; failed[requestKey] = nil
            memory.setObject(data as NSData, forKey: requestKey as NSString, cost: data.count)
            memoryDates[requestKey] = Date()
            try? data.write(to: disk, options: .atomic)
            return data
        } catch { pending[requestKey] = nil; failed[requestKey] = Date(); throw error }
    }
    func prefetch(_ rows: [(String, String, String)], version: String) async {
        // Four concurrent requests; callers pass a bounded lookahead window, never the full catalogue.
        for start in stride(from: 0, to: min(rows.count, 8), by: 4) {
            guard !Task.isCancelled else { return }
            let batch = rows[start..<min(start + 4, rows.count)]
            await withTaskGroup(of: Void.self) { group in
                for (id, name, rarity) in batch { group.addTask { _ = try? await self.image(id: id, name: name, rarity: rarity, version: version) } }
            }
        }
    }
}
struct AugmentIcon: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String
    let rarity: String
    var size: CGFloat = 48
    @State private var image: UIImage?
    @State private var failed = false
    @State private var retry = 0
    private var identity: String { "\(id)|\(store.dataset?.manifest.patch ?? "latest")|\(retry)" }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Theme.rarityGradient(rarity))
            if let image { Image(uiImage: image).resizable().scaledToFit().padding(6).accessibilityHidden(true) }
            else { AugmentGlyph(rarity: rarity, size: size).accessibilityHidden(true) }
        }.frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.rarityColor(rarity), lineWidth: 1.5))
            .overlay(alignment: .bottomTrailing) {
                if failed {
                    Button { retry += 1 } label: {
                        Image(systemName: "arrow.clockwise.circle.fill").font(.body).foregroundStyle(Theme.text)
                            .padding(4).background(Theme.surface, in: Circle()).frame(width: 44, height: 44)
                    }.buttonStyle(.borderless).accessibilityLabel("重试加载\(store.augments[id]?.name ?? "海克斯")图标")
                }
            }
            .accessibilityElement(children: .contain)
            .task(id: identity) {
                image = nil; failed = false
                guard let augment = store.augments[id], !id.isEmpty else { return }
                do {
                    let bytes = try await AugmentIconCache.shared.image(id: id, name: augment.name, rarity: rarity, version: store.dataset?.manifest.patch ?? "latest", force: retry > 0)
                    try Task.checkCancellation()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { image = UIImage(data: bytes) }
                } catch { if !Task.isCancelled { failed = true } }
            }
    }
}
@MainActor
func prefetchIcons(after id: String, in ids: [String], store: AppStore) async {
    guard let index = ids.firstIndex(of: id) else { return }
    let next = ids.dropFirst(index + 1).prefix(8).compactMap { key -> (String, String, String)? in
        guard let a = store.augments[key] else { return nil }; return (key, a.name, a.rarity)
    }
    await AugmentIconCache.shared.prefetch(next, version: store.dataset?.manifest.patch ?? "latest")
}
