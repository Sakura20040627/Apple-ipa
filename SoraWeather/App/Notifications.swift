import Foundation
import UserNotifications
import BackgroundTasks

@MainActor final class RainNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RainNotifications()
    private let center = UNUserNotificationCenter.current()
    private var revision = UUID()
    static let backgroundID = "app.sora.weather.refresh"
    func install() { center.delegate = self }
    func permission() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }
    func requestPermission() async -> Bool { (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false }
    func cancel() async { revision = UUID(); await cancelPending() }
    private func cancelPending() async {
        let ids = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("rain.") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    func reconcile(region: Region, snapshot: WeatherSnapshot?, points: [RainPoint], fetched: Date?, enabled: Bool, japanese: Bool) async -> String? {
        let token = UUID(); revision = token
        let authorized = await permission()
        guard token == revision else { return nil }
        await cancelPending() // Dry refresh, source failure, region switch and opt-out all remove obsolete rain requests.
        guard token == revision, enabled, authorized else { return nil }
        let now = Date()
        // Delivered requests survive app suspension; use OS delivery dates, not scheduling dates, for cooldown.
        let delivered = await center.deliveredNotifications().filter { $0.request.identifier.hasPrefix("rain.") }.map(\.date).max()
        let saved = UserDefaults.standard.object(forKey: "lastRainDelivered") as? Date
        let scheduled = UserDefaults.standard.object(forKey: "lastRainScheduledFire") as? Date
        let elapsedScheduled = scheduled.flatMap { $0 <= now ? $0 : nil }
        let last = [saved, delivered, elapsedScheduled].compactMap { $0 }.max()
        guard token == revision else { return nil }
        if let last { UserDefaults.standard.set(last, forKey: "lastRainDelivered") }
        let plan = fetched.flatMap { RainPolicy.plan(points: points, fetched: $0, now: now, region: region.id, enabled: enabled, authorized: authorized, lastDelivered: last) }
        let content = UNMutableNotificationContent(); content.sound = .default; content.interruptionLevel = .active
        let fire: Date
        if let plan {
            fire = plan.fireDate
            content.title = japanese ? "雨の予測 · \(region.name)" : "降雨预测 · \(region.name)"
            content.body = japanese ? "約\(time(plan.onset))から雨の可能性。予測は変わることがあります。" : "约 \(time(plan.onset)) 起可能降雨，预报可能变化。"
        } else {
            guard last.map({ now.timeIntervalSince($0) >= 3600 }) ?? true,
                  let snapshot, !snapshot.stale(at: now),
                  let window = ForecastRainPolicy.window(snapshot: snapshot, now: now) else { return nil }
            fire = max(now.addingTimeInterval(5), window.date.addingTimeInterval(-1800))
            content.title = japanese ? "雨の時間帯 · \(region.name)" : "降雨时段 · \(region.name)"
            content.body = japanese ? "\(time(window.date))以降の予報に雨。時間帯の予報で、降り始めの通知ではありません。" : "\(time(window.date)) 起的预报时段可能有雨。这是时段提醒，无法预测准确起雨时间。"
        }
        content.userInfo = ["regionID": region.id, "destination": "safety"]
        let requestID = "rain.\(region.id).\(token.uuidString)"
        guard token == revision else { return nil }
        do {
            try await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)))
            if token != revision { center.removePendingNotificationRequests(withIdentifiers: [requestID]); return nil }
            UserDefaults.standard.set(fire, forKey: "lastRainScheduledFire")
            return nil
        } catch { return japanese ? "通知を予約できませんでした" : "通知预约失败" }
    }
    private func time(_ date: Date) -> String { let f = DateFormatter(); f.timeZone = JapanTime.calendar.timeZone; f.dateFormat = "HH:mm"; return f.string(from: date) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let key = SafetyDestination.cityKey(userInfo: response.notification.request.content.userInfo, identifier: response.notification.request.identifier) else { completionHandler(); return }
        Task { @MainActor in SafetyNavigation.shared.open(key); completionHandler() }
    }
    func scheduleBackground() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundID)
        guard UserDefaults.standard.bool(forKey: "rainEnabled") else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundID); request.earliestBeginDate = Date().addingTimeInterval(30*60)
        try? BGTaskScheduler.shared.submit(request) // OS decides whether/when this runs.
    }
    func backgroundRefresh() async {
        defer { scheduleBackground() }
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "rainEnabled") else { await cancel(); return }
        let region = defaults.data(forKey: "selectedRegion.v1").flatMap { try? JSONDecoder().decode(Region.self, from: $0) } ?? Region.supported.first { $0.id == defaults.string(forKey: "region") } ?? .osaka
        let result = await WeatherService.shared.refresh(region)
        if Task.isCancelled { return }
        let key = defaults.string(forKey: "yahooClientID") ?? ""
        let points = (try? await WeatherService.shared.rain(region: region, clientID: key)) ?? []
        if Task.isCancelled || (defaults.string(forKey: "region") ?? "osaka") != region.id { return }
        _ = await reconcile(region: region, snapshot: result.cached ? nil : result.weather, points: points, fetched: points.isEmpty ? nil : Date(), enabled: defaults.bool(forKey: "rainEnabled"), japanese: AppLanguage.code == "ja")
    }
}
