import SwiftUI
import MapKit
import ImageIO

private struct RadarTile: Hashable, Sendable {
    let z: Int
    let x: Int
    let y: Int
}
private enum RadarRaster {
    static func png(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
    static func image(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width == 256, image.height == 256 else { return nil }
        return image
    }
    static func recolor(_ data: Data) -> Data? {
        guard let image = image(data),
              let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let buffer = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        let bytes = buffer.bindMemory(to: UInt8.self, capacity: 256*256*4)
        for i in stride(from: 0, to: 256*256*4, by: 4) {
            let a = UInt32(bytes[i+3]); if a == 0 { continue }
            let r = min(255, UInt32(bytes[i])*255/a), g = min(255, UInt32(bytes[i+1])*255/a), b = min(255, UInt32(bytes[i+2])*255/a)
            if let color = RadarPalette.mapping[(r << 16) | (g << 8) | b] {
                bytes[i] = UInt8(((color >> 16) & 255)*a/255)
                bytes[i+1] = UInt8(((color >> 8) & 255)*a/255)
                bytes[i+2] = UInt8((color & 255)*a/255)
            }
        }
        return context.makeImage().flatMap(png)
    }
    static func crop(_ data: Data, request: RadarTile, native: RadarTile) -> Data? {
        if request == native { return data }
        guard let image = image(data), request.z >= native.z else { return nil }
        let scale = 1 << (request.z-native.z), side = 256.0/Double(scale)
        let rect = CGRect(x: Double(request.x % scale)*side, y: Double(request.y % scale)*side, width: side, height: side)
        guard let piece = image.cropping(to: rect),
              let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(piece, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        return context.makeImage().flatMap(png)
    }
}
private actor RadarTileCache {
    static let shared = RadarTileCache()
    private var cache: [URL: Data] = [:]
    private var order: [URL] = []
    private var bytes = 0
    private var pending: [URL: Task<Data, Error>] = [:]
    private var missing: [URL: Date] = [:]
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 20
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
    private func source(_ url: URL) async throws -> Data {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-radar-fail") { throw SoraError.http(503) }
        #endif
        if let value = cache[url] { return value }
        if let time = missing[url], Date().timeIntervalSince(time) < 60 { throw SoraError.http(404) }
        if let task = pending[url] { return try await task.value }
        let task = Task<Data, Error> {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 2_000_000, let prepared = RadarRaster.recolor(data) else { throw SoraError.invalidData }
            return prepared
        }
        pending[url] = task
        do {
            let data = try await task.value; pending[url] = nil
            cache[url] = data; order.append(url); bytes += data.count
            while bytes > 32*1024*1024 || order.count > 768 {
                let key = order.removeFirst(); bytes -= cache.removeValue(forKey: key)?.count ?? 0
            }
            return data
        } catch {
            pending[url] = nil; missing[url] = Date()
            if missing.count > 768 { missing = missing.filter { Date().timeIntervalSince($0.value) < 60 } }
            throw error
        }
    }
    func tile(_ requested: RadarTile, frame: RadarFrame) async throws -> Data {
        guard (4...14).contains(requested.z), requested.x >= 0, requested.y >= 0 else { throw SoraError.invalidData }
        // JMA's viewer declares zoomUse=even and maxNativeZoom=10.
        let maximum = min(10, requested.z - requested.z%2)
        for z in stride(from: maximum, through: 4, by: -2) {
            try Task.checkCancellation()
            let shift = requested.z-z
            let native = RadarTile(z: z, x: requested.x >> shift, y: requested.y >> shift)
            guard let url = frame.tileURL(z: z, x: native.x, y: native.y) else { continue }
            do {
                let data = try await source(url)
                if let image = RadarRaster.crop(data, request: requested, native: native) { return image }
            } catch is CancellationError { throw CancellationError() }
            catch { continue } // Sparse high-zoom tiles: try an actual coarser JMA tile.
        }
        throw SoraError.noForecast
    }
    func resetFailures() { missing.removeAll() }
    func prepare(_ tiles: [RadarTile], frames: [RadarFrame]) async throws {
        let jobs = frames.flatMap { frame in tiles.map { ($0, frame) } }
        try await withThrowingTaskGroup(of: Void.self) { group in
            var next = 0
            for _ in 0..<min(4, jobs.count) {
                let job = jobs[next]; next += 1
                group.addTask { _ = try await self.tile(job.0, frame: job.1) }
            }
            while try await group.next() != nil {
                try Task.checkCancellation()
                if next < jobs.count {
                    let job = jobs[next]; next += 1
                    group.addTask { _ = try await self.tile(job.0, frame: job.1) }
                }
            }
        }
    }
}

@MainActor private final class RadarPlayback: ObservableObject {
    @Published var frames: [RadarFrame] = []
    @Published var index = 0
    @Published var available = false
    @Published var failed = false
    @Published var busy = false
    @Published var playing = true
    @Published var shown: RadarFrame?
    @Published var revision = 0
    var loaded: Date?
    var selected: RadarFrame? { frames.indices.contains(index) ? frames[index] : nil }
    func load() async {
        available = false; failed = false; busy = true; shown = nil
        frames = []; index = 0; loaded = nil; revision += 1
        await RadarTileCache.shared.resetFailures()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-radar-fail") {
            let f = DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyyMMddHHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let text = f.string(from: Date())
            frames = RadarFrame(base: text, valid: text).map { [$0] } ?? []; index = 0; return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") && !ProcessInfo.processInfo.arguments.contains("--ui-test-radar-live") { fail(); return }
        #endif
        do {
            async let history = Self.fetch("N1")
            async let prediction = Self.fetch("N2")
            let observed = try await history
            let predicted = (try? await prediction) ?? []
            try Task.checkCancellation()
            let next = RadarTimeline.window(observed: observed, predicted: predicted, now: Date())
            guard !next.isEmpty else { throw SoraError.noForecast }
            frames = next; index = next.lastIndex { !$0.forecast } ?? 0; loaded = Date()
        } catch { fail() }
    }
    private static func fetch(_ suffix: String) async throws -> [RadarFrame] {
        let url = URL(string: "https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_\(suffix).json")!
        var request = URLRequest(url: url); request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SoraError.invalidData }
        return try await Task.detached(priority: .utility) { try RadarTimeline.parse(data) }.value
    }
    func fail() { failed = true; available = false; busy = false; playing = false; shown = nil }
    func visible(_ frame: RadarFrame) { shown = frame; available = true; busy = false }
}

private final class RainTileOverlay: MKTileOverlay, @unchecked Sendable {
    let frame: RadarFrame
    let ready: @Sendable () -> Void
    let failure: @Sendable () -> Void
    init(frame: RadarFrame, ready: @escaping @Sendable () -> Void, failure: @escaping @Sendable () -> Void) {
        self.frame = frame; self.ready = ready; self.failure = failure
        super.init(urlTemplate: nil); tileSize = CGSize(width: 256, height: 256); minimumZ = 4; maximumZ = 14; canReplaceMapContent = false
    }
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tile = RadarTile(z: path.z, x: path.x, y: path.y)
        Task {
            do { let data = try await RadarTileCache.shared.tile(tile, frame: frame); result(data, nil); ready() }
            catch { result(nil, error); failure() }
        }
    }
}
private struct RainMap: UIViewRepresentable {
    let region: Region
    let temperature: Double?
    let condition: String
    let frame: RadarFrame?
    let frames: [RadarFrame]
    let revision: Int
    let focus: Int
    let satellite: Bool
    let reduceMotion: Bool
    let busy: (Bool) -> Void
    let visible: (RadarFrame) -> Void
    let failure: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.overrideUserInterfaceStyle = .dark; map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false; map.isRotateEnabled = false; map.delegate = context.coordinator
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 20_000, maxCenterCoordinateDistance: 5_000_000)
        let point = MKPointAnnotation(); point.coordinate = CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude); point.title = region.name
        map.addAnnotation(point)
        map.setRegion(MKCoordinateRegion(center: point.coordinate, span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)), animated: false)
        context.coordinator.map = map; return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator; c.parent = self
        map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: frame == nil ? 0 : 180, right: 0)
        if c.lastSatellite != satellite {
        c.lastSatellite = satellite
        if satellite { map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat) }
        else {
            let style = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            style.pointOfInterestFilter = .excludingAll; map.preferredConfiguration = style
        }
        }
        if c.focus != focus {
            c.focus = focus
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude), span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)), animated: !reduceMotion)
        }
        c.schedule()
    }
    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) { coordinator.stop(); map.delegate = nil }
    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RainMap
        weak var map: MKMapView?
        var focus = 0
        var lastSatellite: Bool?
        var annotationHost: UIHostingController<AnyView>?
        var request = ""
        var generation = UUID()
        var preparation: Task<Void, Never>?
        var prefetch: Task<Void, Never>?
        var current: RainTileOverlay?
        var incoming: RainTileOverlay?
        var renderers: [ObjectIdentifier: MKTileOverlayRenderer] = [:]
        var link: CADisplayLink?
        var started: CFTimeInterval = 0
        init(_ parent: RainMap) { self.parent = parent }
        func tiles(_ map: MKMapView) -> [RadarTile] {
            let rect = map.visibleMapRect, world = MKMapRect.world.size.width
            guard rect.width > 0, map.bounds.width > 0 else { return [] }
            let zoom = max(4, min(10, Int(log2(world*Double(map.bounds.width)/(256*rect.width)))))
            let z = zoom - zoom%2, count = 1 << z, side = world/Double(count)
            let x0 = max(0, min(count-1, Int(floor(rect.minX/side)))), x1 = max(0, min(count-1, Int(floor(rect.maxX/side))))
            let y0 = max(0, min(count-1, Int(floor(rect.minY/side)))), y1 = max(0, min(count-1, Int(floor(rect.maxY/side))))
            guard x0 <= x1, y0 <= y1 else { return [] }
            let cx = (x0+x1)/2, cy = (y0+y1)/2
            var values: [RadarTile] = []
            for x in x0...x1 { for y in y0...y1 { values.append(RadarTile(z: z, x: x, y: y)) } }
            values.sort { left, right in
                let a = abs(left.x-cx) + abs(left.y-cy)
                let b = abs(right.x-cx) + abs(right.y-cy)
                if a != b { return a < b }
                if left.x != right.x { return left.x < right.x }
                return left.y < right.y
            }
            return Array(values.prefix(24))
        }
        func stop() { preparation?.cancel(); prefetch?.cancel(); link?.invalidate(); link = nil; generation = UUID() }
        func clear() {
            link?.invalidate(); link = nil
            if let incoming { map?.removeOverlay(incoming) }
            if let current { map?.removeOverlay(current) }
            incoming = nil; current = nil; renderers.removeAll()
        }
        func schedule() {
            guard let map else { return }
            guard let frame = parent.frame else { stop(); clear(); request = ""; return }
            let keys = tiles(map)
            let key = frame.id + ":\(parent.revision):" + keys.map { "\($0.z)/\($0.x)/\($0.y)" }.joined(separator: ",")
            guard request != key else { return }
            request = key; stop()
            let token = generation
            link?.invalidate(); link = nil
            if let incoming { map.removeOverlay(incoming); renderers[ObjectIdentifier(incoming)] = nil; self.incoming = nil }
            if let current { renderers[ObjectIdentifier(current)]?.alpha = 0.75 }
            preparation = Task { @MainActor [weak self] in
                guard let self else { return }
                guard !Task.isCancelled, self.generation == token else { return }
                self.parent.busy(true)
                do {
                    let center = map.centerCoordinate
                    guard (20...48).contains(center.latitude), (118...150).contains(center.longitude), !keys.isEmpty else { throw SoraError.noForecast }
                    try await RadarTileCache.shared.prepare(keys, frames: [frame])
                    guard !Task.isCancelled, self.generation == token else { return }
                    let overlay = RainTileOverlay(frame: frame, ready: { [weak self] in Task { @MainActor in self?.beginFade(token) } }, failure: { [weak self] in Task { @MainActor in self?.failed(token) } })
                    self.incoming = overlay; map.addOverlay(overlay, level: .aboveRoads)
                    if let index = self.parent.frames.firstIndex(of: frame) {
                        let around = Array(self.parent.frames[max(0,index-12)...min(self.parent.frames.count-1,index+12)])
                        self.prefetch = Task { try? await RadarTileCache.shared.prepare(keys, frames: around) }
                    }
                } catch is CancellationError { }
                catch { self.failed(token) }
            }
        }
        func failed(_ token: UUID) { guard token == generation else { return }; stop(); clear(); parent.failure() }
        func beginFade(_ token: UUID) {
            guard token == generation, link == nil, let incoming, renderers[ObjectIdentifier(incoming)] != nil else { return }
            started = CACurrentMediaTime()
            if parent.reduceMotion { finishFade(); return }
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            display.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
            link = display; display.add(to: .main, forMode: .common)
        }
        @objc func tick(_ display: CADisplayLink) {
            let progress = min(1, max(0, (display.timestamp-started)/0.25))
            if let incoming, let renderer = renderers[ObjectIdentifier(incoming)] { renderer.alpha = CGFloat(0.75*progress); renderer.setNeedsDisplay() }
            if let current, let renderer = renderers[ObjectIdentifier(current)] { renderer.alpha = CGFloat(0.75*(1-progress)); renderer.setNeedsDisplay() }
            if progress >= 1 { finishFade() }
        }
        func finishFade() {
            link?.invalidate(); link = nil
            guard let next = incoming else { return }
            if let old = current { map?.removeOverlay(old); renderers[ObjectIdentifier(old)] = nil }
            current = next; incoming = nil
            renderers[ObjectIdentifier(next)]?.alpha = 0.75
            parent.visible(next.frame)
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { schedule() }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let rain = overlay as? RainTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: rain); renderer.alpha = 0.001
            renderers[ObjectIdentifier(rain)] = renderer; return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "temperature")
            let host = UIHostingController(rootView: AnyView(VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(parent.temperature.map { "\(Int($0))°" } ?? "—°").font(.system(size: 26, weight: .bold))
                    Image(systemName: Condition.symbol(parent.condition)).symbolRenderingMode(.multicolor).font(.title3)
                }.frame(width: 64, height: 64).background(Color(red: 0.4, green: 0.49, blue: 0.61), in: .circle).overlay(Circle().stroke(.black.opacity(0.8), lineWidth: 2))
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 12)).offset(y: -2)
            }.foregroundStyle(.white)))
            annotationHost = host
            host.view.backgroundColor = .clear; host.view.frame = CGRect(x: 0, y: 0, width: 72, height: 80)
            view.addSubview(host.view); view.frame.size = host.view.frame.size; view.centerOffset = CGPoint(x: 0, y: -40)
            view.isAccessibilityElement = true; view.accessibilityIdentifier = "temperatureBubble"; view.accessibilityLabel = parent.region.name + " " + (parent.temperature.map { "\(Int($0))°" } ?? "—°")
            return view
        }
    }
}

struct InternalWeatherMap: View {
    let region: Region
    let temperature: Double?
    let condition: String
    @StateObject private var radar = RadarPlayback()
    @State private var focus = 0
    @State private var satellite = false
    @State private var layers = false
    @State private var source = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func t(_ zh: String, _ ja: String) -> String { AppLanguage.code == "ja" ? ja : zh }
    var body: some View {
        ZStack(alignment: .top) {
            RainMap(region: region, temperature: temperature, condition: condition, frame: radar.failed ? nil : radar.selected, frames: radar.frames, revision: radar.revision, focus: focus, satellite: satellite, reduceMotion: reduceMotion, busy: { radar.busy = $0 }, visible: { radar.visible($0) }, failure: { radar.fail() }).ignoresSafeArea(.all)
                .accessibilityIdentifier("rainMap")
            GlassEffectContainer(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.weight(.semibold)).frame(width: 46, height: 46) }.glassEffect(.regular, in: .circle).accessibilityIdentifier("closeMap")
                        if radar.available { legend }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Button { layers = true } label: { Image(systemName: "square.3.layers.3d").font(.title3).frame(width: 46, height: 48) }.accessibilityLabel(t("图层", "レイヤー"))
                        Divider().padding(.horizontal, 11)
                        Button { focus += 1 } label: { Image(systemName: "location").font(.title3).frame(width: 46, height: 48) }.accessibilityLabel(t("返回预报地点", "予報地点に戻る"))
                    }.frame(width: 46).glassEffect(.regular, in: .capsule)
                }
            }.padding(.horizontal, 18).padding(.top, 12)
        }.preferredColorScheme(.dark).tint(.white)
            .overlay(alignment: .bottom) { if radar.available { playback.padding(.horizontal, 22).padding(.bottom, 14) } }
            .confirmationDialog(t("地图图层", "地図の種類"), isPresented: $layers) {
                Button(t("标准地图", "標準地図")) { satellite = false }
                Button(t("卫星地图", "衛星画像")) { satellite = true }
                Button(t("重新加载雨云", "雨雲を再読み込み")) { Task { await radar.load() } }
            }
            .sheet(isPresented: $source) { InternalBrowser(url: URL(string: "https://www.jma.go.jp/bosai/nowc/")!) }
            .task {
                await radar.load()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(900)) } catch { break }
                    guard phase == .active else { continue }
                    if let loaded = radar.loaded, Date().timeIntervalSince(loaded) > 300 { await radar.load() }
                    if radar.playing && radar.available && !radar.busy && radar.frames.count > 1 { radar.index = (radar.index+1) % radar.frames.count }
                }
            }
            .onChange(of: phase) { _, value in if value != .active { radar.playing = false } }
            .overlay(alignment: .bottomLeading) {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test-radar-fail") { Text(radar.failed ? "unavailable" : "loading").accessibilityIdentifier("testRadarState") }
                #endif
            }
    }
    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("降水 · 弱→极端", "降水 · 弱→極端")).font(.system(size: 10, weight: .semibold))
            HStack(spacing: 7) {
                VStack(spacing: 0) { ForEach(0..<8) { i in Rectangle().fill(color(RadarPalette.display[i])).frame(width: 12, height: 14) } }.clipShape(Capsule())
                VStack(alignment: .leading, spacing: 0) { ForEach(RadarPalette.thresholds, id: \.self) { Text($0).font(.system(size: 9, weight: .medium)).frame(height: 14) } }
                Text("mm/h").font(.system(size: 9))
            }
            Button(t("JMA · 已重新配色", "JMA · 配色を加工")) { source = true }.font(.system(size: 9))
        }.padding(10).background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white).accessibilityIdentifier("rainLegend")
    }
    private var playback: some View {
        VStack(spacing: 8) {
            HStack {
                Button { radar.playing.toggle() } label: { Image(systemName: radar.playing ? "pause.fill" : "play.fill").frame(width: 34, height: 34) }.accessibilityLabel(t("播放或暂停", "再生・一時停止"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("雨云动画", "雨雲の動き")).font(.subheadline.weight(.semibold))
                    if let frame = radar.shown { Text(RadarClock.stamp.string(from: frame.date)).font(.caption).environment(\.timeZone, JapanTime.calendar.timeZone) }
                }
                Spacer()
                if radar.busy { ProgressView().tint(.white) }
                Text((radar.shown?.forecast ?? false) ? t("预测", "予測") : t("观测", "実況")).font(.caption.weight(.medium))
            }
            Slider(value: Binding(get: { Double(radar.index) }, set: { radar.playing = false; radar.index = min(max(0, Int($0.rounded())), radar.frames.count-1) }), in: 0...Double(max(1,radar.frames.count-1)), step: 1).tint(.white).disabled(radar.frames.count < 2).accessibilityIdentifier("rainTimeline")
            HStack { if let first = radar.frames.first { Text(first.date, style: .time) }; Spacer(); if let last = radar.frames.last { Text(last.date, style: .time) } }.font(.caption2).environment(\.timeZone, JapanTime.calendar.timeZone)
        }.padding(16).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28)).foregroundStyle(.white).accessibilityElement(children: .contain).accessibilityIdentifier("rainPlayback")
    }
    private func color(_ value: UInt32) -> Color { Color(red: Double((value >> 16)&255)/255, green: Double((value >> 8)&255)/255, blue: Double(value&255)/255) }
}

@MainActor private enum RadarClock {
    static let stamp: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = JapanTime.calendar.timeZone; f.dateFormat = "M/d HH:mm 'JST'"; return f }()
}
