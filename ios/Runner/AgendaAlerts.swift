import Flutter
import UIKit
import UserNotifications
import ActivityKit

final class AgendaAlerts {
    private let center = UNUserNotificationCenter.current()
    private let channel: FlutterMethodChannel
    private var pendingTask: String?
    private var ready = false
    private let prefix = "myagenda."

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "fr.beyondexpertise.myagenda/alerts", binaryMessenger: messenger)
        let done = UNNotificationAction(identifier: "done", title: "Terminé ✓", options: [.foreground])
        let later = UNNotificationAction(identifier: "later", title: "Pas fini", options: [.foreground])
        let start = UNNotificationAction(identifier: "start", title: "Démarrer", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "myagenda.end", actions: [done, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: "myagenda.start", actions: [start, done], intentIdentifiers: [])
        ])
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    func openTask(_ id: String) {
        DispatchQueue.main.async {
            if self.ready { self.channel.invokeMethod("openTask", arguments: id) }
            else { self.pendingTask = id }
        }
    }

    private func finish(_ result: @escaping FlutterResult, _ value: Any? = nil) {
        DispatchQueue.main.async { result(value) }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialTask":
            ready = true
            result(pendingTask); pendingTask = nil
        case "status":
            center.getNotificationSettings { settings in
                self.center.getPendingNotificationRequests { pending in
                    var liveSupported = false, liveEnabled = false
                    if #available(iOS 16.2, *) {
                        liveSupported = true
                        liveEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
                    }
                    self.finish(result, ["authorized": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                        "denied": settings.authorizationStatus == .denied,
                        "liveSupported": liveSupported, "liveEnabled": liveEnabled,
                        "pending": pending.filter { $0.identifier.hasPrefix(self.prefix) }.count])
                }
            }
        case "requestPermission":
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error { self.finish(result, FlutterError(code: "permission", message: error.localizedDescription, details: nil)) }
                else { self.finish(result, granted) }
            }
        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url) { opened in self.finish(result, opened) }
            } else { result(false) }
        case "testNotification":
            let content = UNMutableNotificationContent()
            content.title = "MyAgenda · test réussi"
            content.body = "Vos tâches pourront vous être rappelées ici. Touchez pour ouvrir MyAgenda."
            content.sound = .default
            center.add(UNNotificationRequest(identifier: prefix + "test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))) { error in
                self.finish(result, error.map { FlutterError(code: "notification", message: $0.localizedDescription, details: nil) })
            }
        case "syncReminders":
            syncReminders(call.arguments as? [String: Any] ?? [:], result: result)
        case "syncLiveActivity":
            if #available(iOS 16.2, *) {
                Task { @MainActor in
                    do { try await syncLive(call.arguments as? [String: Any]); result(nil) }
                    catch { result(FlutterError(code: "live_activity", message: error.localizedDescription, details: nil)) }
                }
            } else { result(nil) }
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func syncReminders(_ arguments: [String: Any], result: @escaping FlutterResult) {
        let events = arguments["events"] as? [[String: Any]] ?? []
        let valid = arguments["validEvents"] as? [String: NSNumber] ?? [:]
        center.getDeliveredNotifications { delivered in
            let obsolete = delivered.filter { notification in
                let request = notification.request
                guard request.identifier.hasPrefix(self.prefix), request.identifier != self.prefix + "test" else { return false }
                let key = String(request.identifier.dropFirst(self.prefix.count))
                guard let expected = valid[key], let actual = request.content.userInfo["at"] as? NSNumber else { return true }
                return abs(expected.doubleValue - actual.doubleValue) > 0.5
            }.map { $0.request.identifier }
            self.center.removeDeliveredNotifications(withIdentifiers: obsolete)
            self.center.getPendingNotificationRequests { existing in
                let desired = Dictionary(uniqueKeysWithValues: events.compactMap { event -> (String, [String: Any])? in
                    guard let id = event["id"] as? String else { return nil }
                    return (self.prefix + id, event)
                })
                self.center.removePendingNotificationRequests(withIdentifiers: existing.filter {
                    $0.identifier.hasPrefix(self.prefix) && $0.identifier != self.prefix + "test" && desired[$0.identifier] == nil
                }.map { $0.identifier })
                self.center.getNotificationSettings { settings in
                    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { self.finish(result); return }
                    let group = DispatchGroup()
                    let errorLock = NSLock()
                    var firstError: Error?
                    for (id, event) in desired {
                        guard let at = event["at"] as? NSNumber, let title = event["title"] as? String,
                              let body = event["body"] as? String, let taskId = event["taskId"] as? String,
                              at.doubleValue > Date().timeIntervalSince1970 else { continue }
                        if let previous = existing.first(where: { $0.identifier == id }),
                           let oldAt = previous.content.userInfo["at"] as? NSNumber,
                           oldAt == at, previous.content.title == title, previous.content.body == body { continue }
                        let content = UNMutableNotificationContent()
                        content.title = title; content.body = body; content.sound = .default
                        content.threadIdentifier = "myagenda.tasks"
                        let kind = event["kind"] as? String ?? "start"
                        content.categoryIdentifier = kind == "end" ? "myagenda.end" : kind == "start" ? "myagenda.start" : ""
                        content.userInfo = ["taskId": taskId, "at": at]
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = .current
                        let date = Date(timeIntervalSince1970: at.doubleValue)
                        let components = calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
                        group.enter()
                        self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))) { error in
                            if let error = error { errorLock.lock(); firstError = error; errorLock.unlock() }
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        result(firstError.map { FlutterError(code: "schedule", message: $0.localizedDescription, details: nil) })
                    }
                }
            }
        }
    }

    @available(iOS 16.2, *)
    @MainActor
    private func syncLive(_ payload: [String: Any]?) async throws {
        let defaults = UserDefaults.standard
        let lastKeyName = "myagenda.lastLiveSession"
        guard let payload = payload, let id = payload["id"] as? String,
              let title = payload["title"] as? String, let mode = payload["mode"] as? String else {
            for activity in Activity<AgendaActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
            defaults.removeObject(forKey: lastKeyName)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let startSeconds = (payload["start"] as? NSNumber)?.doubleValue ?? 0
        let start = startSeconds > 0 ? Date(timeIntervalSince1970: startSeconds) : Date()
        let end = Date(timeIntervalSince1970: (payload["end"] as? NSNumber)?.doubleValue ?? Date().addingTimeInterval(8 * 3600).timeIntervalSince1970)
        let session = "\(id):\(startSeconds)"
        let state = AgendaActivityAttributes.ContentState(title: title, mode: mode, start: start, end: end,
            elapsedSeconds: (payload["elapsedSeconds"] as? NSNumber)?.intValue ?? 0,
            progress: min(1, max(0, (payload["progress"] as? NSNumber)?.doubleValue ?? 0)),
            nextTitle: payload["nextTitle"] as? String,
            nextAt: (payload["nextAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) },
            category: payload["category"] as? String)
        let content = ActivityContent(state: state, staleDate: mode == "paused" ? nil : end)
        var current: Activity<AgendaActivityAttributes>?
        for activity in Activity<AgendaActivityAttributes>.activities {
            if activity.attributes.taskId == id && activity.activityState != .dismissed && activity.activityState != .ended { current = activity }
            else { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        if let current = current {
            await current.update(content)
            defaults.set(session, forKey: lastKeyName)
        } else if UIApplication.shared.applicationState == .active && defaults.string(forKey: lastKeyName) != session {
            // Respect a card the user dismissed. Toggle the feature off/on to show it again.
            _ = try Activity.request(attributes: AgendaActivityAttributes(taskId: id, sessionKey: session), content: content, pushType: nil)
            defaults.set(session, forKey: lastKeyName)
        }
    }
}
