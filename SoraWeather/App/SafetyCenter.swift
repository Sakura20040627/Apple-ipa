import SwiftUI

private actor SafetyDisk {
    static let shared = SafetyDisk()
    private var saved: [String: SafetyRecord]?
    private var url: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("safety-v1.json") }
    func load() -> [String: SafetyRecord] {
        if let saved { return saved }
        guard let bytes = try? Data(contentsOf: url), bytes.count < 5_000_000,
              let records = try? JSONDecoder().decode([String: SafetyRecord].self, from: bytes) else { saved = [:]; return [:] }
        saved = records; return records
    }
    func save(_ record: SafetyRecord, office: String) {
        var records = load()
        var latest = records[office] ?? SafetyRecord()
        latest.merge(warnings: record.warnings, quakes: record.quakes, issued: record.warningsIssued, warningTime: record.warningsFetched, quakeTime: record.quakesFetched)
        records[office] = latest; saved = records
        guard let bytes = try? JSONEncoder().encode(records) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
@MainActor final class SafetyCenter: ObservableObject {
    static let shared = SafetyCenter()
    @Published private(set) var records: [String: SafetyRecord] = [:]
    @Published private(set) var refreshing = false
    private var restored = false
    private var currentOffice: String?
    func record(_ region: Region) -> SafetyRecord { records[region.office] ?? SafetyRecord() }
    func restore() async {
        guard !restored else { return }; restored = true
        let saved = await SafetyDisk.shared.load()
        for (key, value) in saved where records[key] == nil { records[key] = value.restored() }
    }
    func ingest(_ value: WeatherService.Safety, region: Region, markFailure: Bool = false) {
        guard markFailure || value.warningsFetched != nil || value.quakesFetched != nil else { return }
        var record = records[region.office] ?? SafetyRecord()
        let newerWarning = value.warningsFetched.map { $0 > (record.warningsFetched ?? .distantPast) } ?? false
        let newerQuake = value.quakesFetched.map { $0 > (record.quakesFetched ?? .distantPast) } ?? false
        guard markFailure || newerWarning || newerQuake else { return }
        record.merge(warnings: value.warnings, quakes: value.quakes, issued: value.warningsIssued, warningTime: value.warningsFetched, quakeTime: value.quakesFetched)
        records[region.office] = record
        Task { await SafetyDisk.shared.save(record, office: region.office) }
    }
    func refresh(current: Region, cities: [SavedCity]) async {
        if refreshing && currentOffice == current.office { return }
        while refreshing {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        refreshing = true; currentOffice = current.office
        defer { refreshing = false; currentOffice = nil }
        await restore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") {
            if ProcessInfo.processInfo.arguments.contains("--ui-test-warning") {
                var record = SafetyRecord()
                let warning = DisasterItem(id: "fixture-warning", title: "JMA 大雨特別警報 · 発表", detail: "JMA UI fixture · 府県単位", issued: Date())
                let quake = DisasterItem(id: "fixture-quake", title: "静岡県西部", detail: "M 5.7 · 最大震度 5+ · 2026-11-08T01:04:00+09:00", issued: Date())
                record.merge(warnings: [warning], quakes: [quake], issued: Date(), warningTime: Date(), quakeTime: Date())
                records[current.office] = record
                for city in cities where city.region.office != current.office { records[city.region.office] = record }
            }
            return
        }
        #endif
        let first = await WeatherService.shared.safety(region: current)
        guard !Task.isCancelled else { return }; ingest(first, region: current, markFailure: true)
        var seen: Set<String> = [current.office]
        let others = cities.map(\.region).filter { seen.insert($0.office).inserted }
        await withTaskGroup(of: (Region, WeatherService.Safety).self) { group in
            var index = 0
            for _ in 0..<min(2, others.count) {
                let region = others[index]; index += 1
                group.addTask { (region, await WeatherService.shared.safety(region: region)) }
            }
            while let (region, value) = await group.next() {
                if Task.isCancelled { group.cancelAll(); return }
                ingest(value, region: region, markFailure: true)
                if index < others.count {
                    let region = others[index]; index += 1
                    group.addTask { (region, await WeatherService.shared.safety(region: region)) }
                }
            }
        }
    }
}
@MainActor final class SafetyNavigation: ObservableObject {
    struct Request: Identifiable { let id = UUID(); let cityKey: String }
    static let shared = SafetyNavigation()
    @Published private(set) var pending: Request?
    func open(_ cityKey: String) { pending = Request(cityKey: cityKey) }
    func clear(_ id: UUID) { if pending?.id == id { pending = nil } }
}
