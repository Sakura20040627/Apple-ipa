import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public protocol DataTransport: Sendable {
    func fetch(_ url: URL) async throws -> Data
}
public struct HTTPTransport: DataTransport {
    public init() {}
    public func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("HexPick/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode), data.count < 100_000_000
        else { throw DataError.invalid("下载失败或响应过大") }
        return data
    }
}
public actor DataRepository {
    public static let origin = URL(string: "https://raw.githubusercontent.com/czgreat/aramhex-data/")!
    private let root: URL
    private let seed: URL
    private let transport: any DataTransport
    private var updating = false
    public init(root: URL, seed: URL? = nil, transport: any DataTransport = HTTPTransport()) {
        self.root = root
        self.seed = seed ?? Bundle.module.url(forResource: "Seed", withExtension: nil)!
        self.transport = transport
    }
    public static func bundledSeedURL() -> URL { Bundle.module.url(forResource: "Seed", withExtension: nil)! }
    public static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func verify(_ data: Data, digest: FileDigest) throws {
        guard data.count == digest.size, sha256(data) == digest.sha256.lowercased()
        else { throw DataError.invalid("SHA-256 或文件大小校验失败") }
    }
    private func neededFiles(_ m: Manifest) -> [String] {
        var names = ["heroes.json", "augments.json", "hero_augments.json", "meta.json", "hero_spells.json", "hero_augment_items.json"]
        if m.bands == true {
            for band in ["casual", "mid", "high", "top"] {
                let pair = ["bands/\(band)/heroes.json", "bands/\(band)/hero_augments.json"]
                if pair.allSatisfy({ m.files[$0] != nil }) { names += pair }
            }
        }
        return names.filter { m.files[$0] != nil }
    }
    private func load(_ directory: URL) throws -> Dataset {
        let m = try DataParser.manifest(Data(contentsOf: directory.appendingPathComponent("latest.json")))
        var files: [String: Data] = [:]
        for name in neededFiles(m) {
            let bytes = try Data(contentsOf: directory.appendingPathComponent(name))
            guard let digest = m.files[name] else { throw DataError.invalid("缺少校验信息") }
            try Self.verify(bytes, digest: digest); files[name] = bytes
        }
        return try DataParser.parse(manifest: m, files: files)
    }
    private func currentDirectory() -> URL? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("current.json")),
              let name = try? JSONDecoder().decode(String.self, from: data),
              UUID(uuidString: name) != nil else { return nil }
        return root.appendingPathComponent(name, isDirectory: true)
    }
    public func cached() throws -> Dataset {
        if let directory = currentDirectory(), let data = try? load(directory) { return data }
        return try load(seed)
    }
    public func clear() throws -> Dataset {
        guard !updating else { throw DataError.invalid("更新正在进行，请稍后清理") }
        // Verify bundled fallback before removing downloaded cache.
        let fallback = try load(seed)
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        return fallback
    }
    public func update() async throws -> Dataset {
        guard !updating else { throw DataError.invalid("更新正在进行") }
        updating = true; defer { updating = false }
        let manifestBytes = try await transport.fetch(Self.origin.appendingPathComponent("main/latest.json"))
        let manifest = try DataParser.manifest(manifestBytes)
        let oldDirectory = currentDirectory()
        let validDirectory: URL
        let old: Dataset
        if let oldDirectory, let cached = try? load(oldDirectory) {
            old = cached; validDirectory = oldDirectory
        } else { old = try load(seed); validDirectory = seed }
        if manifest == old.manifest { return old }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stage = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: stage) } }
        var files: [String: Data] = [:]
        for name in neededFiles(manifest) {
            try Task.checkCancellation()
            guard let digest = manifest.files[name] else { throw DataError.invalid("缺少校验信息") }
            let bytes: Data
            if old.manifest.files[name] == digest,
               let existing = try? Data(contentsOf: validDirectory.appendingPathComponent(name)),
               (try? Self.verify(existing, digest: digest)) != nil {
                bytes = existing
            } else {
                // Immutable snapshot tag prevents mixing files if main changes during download.
                let relative = "data-v\(manifest.seq)/\(manifest.path)/\(name)"
                bytes = try await transport.fetch(Self.origin.appendingPathComponent(relative))
            }
            try Self.verify(bytes, digest: digest)
            files[name] = bytes
            let destination = stage.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: destination, options: .atomic)
        }
        let parsed = try DataParser.parse(manifest: manifest, files: files)
        try manifestBytes.write(to: stage.appendingPathComponent("latest.json"), options: .atomic)
        // Atomic pointer commit: old valid directory remains untouched until all validation passes.
        try JSONEncoder().encode(stage.lastPathComponent).write(to: root.appendingPathComponent("current.json"), options: .atomic)
        committed = true
        for directory in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            if UUID(uuidString: directory.lastPathComponent) != nil && directory.lastPathComponent != stage.lastPathComponent {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        return parsed
    }
}
