import Cocoa
import FlutterMacOS
import Security

class MainFlutterWindow: NSWindow {
  private var workChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = "MyAgenda"
    self.minSize = NSSize(width: 390, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)
    workChannel = FlutterMethodChannel(name: "fr.beyondexpertise.myagenda/assistant", binaryMessenger: flutterViewController.engine.binaryMessenger)
    workChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleWork(call, result: result)
    }

    super.awakeFromNib()
  }

    // Tokens stay in this device's Keychain and are never exported with tasks.
    private func handleWork(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "fr.beyondexpertise.myagenda.work",
                                   kSecAttrAccount as String: "private-device"]
        if call.method == "workOpenMail" {
            guard let raw = call.arguments as? String, let url = URL(string: raw),
                  url.scheme == "https", url.host == "mail.google.com", url.user == nil,
                  url.password == nil, url.port == nil else {
                result(FlutterError(code: "url", message: "Lien Gmail invalide.", details: nil)); return
            }
            let opened = NSWorkspace.shared.open(url)
            result(opened ? nil : FlutterError(code: "url", message: "Gmail ne peut pas être ouvert.", details: nil))
            return
        }
        var status: OSStatus = errSecSuccess
        switch call.method {
        case "workRead":
            var read = query
            read[kSecReturnData as String] = true
            read[kSecMatchLimit as String] = kSecMatchLimitOne
            var value: CFTypeRef?
            status = SecItemCopyMatching(read as CFDictionary, &value)
            if status == errSecItemNotFound { result(nil); return }
            if status == errSecSuccess, let data = value as? Data, let text = String(data: data, encoding: .utf8) { result(text); return }
        case "workWrite":
            guard let text = call.arguments as? String, let data = text.data(using: .utf8), data.count <= 8192 else {
                result(FlutterError(code: "keychain", message: "Configuration invalide.", details: nil)); return
            }
            let attributes: [String: Any] = [kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            }
        case "workDelete":
            status = SecItemDelete(query as CFDictionary)
            if status == errSecItemNotFound { status = errSecSuccess }
        default: result(FlutterMethodNotImplemented); return
        }
        if status == errSecSuccess { result(nil) }
        else { result(FlutterError(code: "keychain", message: "Déverrouillez cet appareil pour accéder à la connexion privée.", details: nil)) }
    }
}
