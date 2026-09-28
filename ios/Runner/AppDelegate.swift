import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var agendaAlerts: AgendaAlerts?
  private var deviceAssistant: DeviceAssistant?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "MyAgendaAlerts") {
      agendaAlerts = AgendaAlerts(messenger: registrar.messenger())
      deviceAssistant = DeviceAssistant(messenger: registrar.messenger())
    }
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.identifier.hasPrefix("myagenda.") {
      if #available(iOS 14.0, *) { completionHandler([.banner, .list, .sound]) }
      else { completionHandler([.alert, .sound]) }
    } else { super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.identifier.hasPrefix("myagenda.") {
      if let id = response.notification.request.content.userInfo["taskId"] as? String {
        if ["done", "later", "start"].contains(response.actionIdentifier) {
          var url = URLComponents(); url.scheme = "myagenda"; url.host = "task"
          url.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "action", value: response.actionIdentifier)]
          agendaAlerts?.openTask(url.string ?? id)
        } else { agendaAlerts?.openTask(id) }
      }
      completionHandler()
    } else { super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler) }
  }

  override func application(_ app: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if url.scheme == "myagenda", url.host == "task",
       URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value != nil {
      agendaAlerts?.openTask(url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
