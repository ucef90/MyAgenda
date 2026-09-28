import Flutter
import UIKit
import AVFoundation
import Speech
import EventKit
import Security

/// Device features keep recordings in the app sandbox. No account tokens or
/// calendar content are embedded in the application bundle.
final class DeviceAssistant: NSObject, AVAudioPlayerDelegate {
    private let channel: FlutterMethodChannel
    private let events = EKEventStore()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStarted: Date?
    private var player: AVAudioPlayer?
    private var playbackResult: FlutterResult?
    private var recognition: SFSpeechRecognitionTask?
    private var transcriptionResult: FlutterResult?
    private var transcriptionTimeout: DispatchWorkItem?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "fr.beyondexpertise.myagenda/assistant", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }
    private func error(_ message: String, _ code: String = "device") -> FlutterError {
        FlutterError(code: code, message: message, details: nil)
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
            UIApplication.shared.open(url, options: [:]) { opened in
                result(opened ? nil : FlutterError(code: "url", message: "Gmail ne peut pas être ouvert.", details: nil))
            }
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
    private func folder() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("MyAgendaAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func audioURL(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw NSError(domain: "MyAgenda", code: 1, userInfo: [NSLocalizedDescriptionKey: "Note audio invalide."]) }
        return try folder().appendingPathComponent(id).appendingPathExtension("m4a")
    }
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method.hasPrefix("work") { handleWork(call, result: result); return }
        switch call.method {
        case "recordStart":
            guard recorder == nil, recordingURL == nil else { result(error("Un enregistrement est déjà ouvert.")); return }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    guard granted else { result(self.error("Autorisez le microphone dans Réglages > MyAgenda.", "permission")); return }
                    do {
                        self.stopPlayback()
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                        try session.setActive(true)
                        let url = try self.audioURL(UUID().uuidString)
                        let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000])
                        guard recorder.record(forDuration: 180) else { throw NSError(domain: "MyAgenda", code: 2, userInfo: [NSLocalizedDescriptionKey: "Le microphone est indisponible."]) }
                        self.recorder = recorder; self.recordingURL = url; self.recordingStarted = Date()
                        result(nil)
                    } catch { result(self.error(error.localizedDescription)) }
                }
            }
        case "recordStop":
            guard let recorder = recorder, let url = recordingURL else { result(error("Aucun enregistrement en cours.")); return }
            let duration = min(180, max(recorder.currentTime, Date().timeIntervalSince(recordingStarted ?? Date())))
            recorder.stop(); self.recorder = nil; recordingURL = nil; recordingStarted = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            do {
                let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                guard size > 0, duration >= 0.5 else { try? FileManager.default.removeItem(at: url); result(error("Enregistrement trop court. Réessayez.")); return }
                let date = DateFormatter(); date.locale = Locale(identifier: "fr_FR"); date.dateFormat = "dd/MM HH:mm"
                result(["id": url.deletingPathExtension().lastPathComponent, "name": "Note du \(date.string(from: Date()))", "seconds": Int(duration.rounded()), "bytes": size])
            } catch { result(self.error(error.localizedDescription)) }
        case "recordCancel":
            recorder?.stop(); recorder = nil
            if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
            recordingURL = nil; recordingStarted = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            result(nil)
        case "audioRemove", "audioRead", "audioPlay", "transcribe":
            do {
                guard let id = call.arguments as? String else { result(error("Note introuvable.")); return }
                let url = try audioURL(id)
                if call.method == "audioRemove" {
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                    result(nil)
                } else if call.method == "audioRead" {
                    result(try Data(contentsOf: url).base64EncodedString())
                } else if call.method == "transcribe" {
                    transcribe(url, result: result)
                } else {
                    stopPlayback()
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .spokenAudio)
                    try session.setActive(true)
                    let audio = try AVAudioPlayer(contentsOf: url); audio.delegate = self
                    guard audio.play() else { result(error("Lecture impossible.")); return }
                    player = audio; playbackResult = result
                }
            } catch { result(self.error(error.localizedDescription)) }
        case "audioStop": stopPlayback(); result(nil)
        case "calendars":
            authorizeCalendar { granted, failure in
                guard granted else { result(self.error(failure?.localizedDescription ?? "Autorisez l’accès complet aux calendriers dans Réglages > MyAgenda.", "permission")); return }
                result(self.events.calendars(for: .event).map { ["id": $0.calendarIdentifier, "title": $0.title, "source": $0.source.title] })
            }
        case "calendarEvents":
            // Background refresh never prompts for a permission the person revoked.
            let access = EKEventStore.authorizationStatus(for: .event)
            var allowed = access == .authorized
            if #available(iOS 17.0, *) { allowed = access == .fullAccess }
            guard allowed else { result(error("Autorisez d’abord vos calendriers.", "permission")); return }
            let ids = call.arguments as? [String] ?? []
            let selected = events.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
            guard !selected.isEmpty else { result([]); return }
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 90, to: start)!
            let values = events.events(matching: events.predicateForEvents(withStart: start, end: end, calendars: selected)).sorted { $0.startDate < $1.startDate }
            guard values.count <= 2000 else { result(error("Trop d’événements : sélectionnez moins de calendriers.")); return }
            result(values.filter { $0.status != .canceled }.map { event -> [String: Any] in
                let occurrence = event.occurrenceDate ?? event.startDate!
                // The original occurrence date remains stable when a recurring instance is moved.
                let rawId = event.calendar.calendarIdentifier + ":" + event.calendarItemIdentifier + (event.hasRecurrenceRules || event.isDetached ? ":\(Int(occurrence.timeIntervalSince1970))" : "")
                let id = Data(rawId.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "=", with: "")
                return ["id": id, "title": event.title ?? "Rendez-vous", "calendar": event.calendar.title, "start": event.startDate.timeIntervalSince1970, "end": event.endDate.timeIntervalSince1970, "allDay": event.isAllDay]
            })
        default: result(FlutterMethodNotImplemented)
        }
    }
    private func authorizeCalendar(_ completion: @escaping (Bool, Error?) -> Void) {
        let callback: (Bool, Error?) -> Void = { granted, error in DispatchQueue.main.async { completion(granted, error) } }
        if #available(iOS 17.0, *) { events.requestFullAccessToEvents(completion: callback) }
        else { events.requestAccess(to: .event, completion: callback) }
    }
    private func transcribe(_ url: URL, result: @escaping FlutterResult) {
        guard transcriptionResult == nil else { result(error("Une transcription est déjà en cours.")); return }
        transcriptionResult = result
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { self.finishTranscription(self.error("Autorisez la reconnaissance vocale dans Réglages > Confidentialité et sécurité.", "permission")); return }
                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")), recognizer.isAvailable else { self.finishTranscription(self.error("La dictée française est indisponible. Vérifiez votre connexion puis réessayez.")); return }
                let request = SFSpeechURLRecognitionRequest(url: url); request.shouldReportPartialResults = false
                let timeout = DispatchWorkItem { [weak self] in self?.finishTranscription(self?.error("La transcription a pris trop de temps. Réessayez avec une phrase plus courte.")) }
                self.transcriptionTimeout = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: timeout)
                self.recognition = recognizer.recognitionTask(with: request) { response, failure in
                    DispatchQueue.main.async {
                        if let response = response, response.isFinal {
                            let text = response.bestTranscription.formattedString
                            self.finishTranscription(text.isEmpty ? self.error("Aucune parole reconnue.") : text)
                        } else if let failure = failure { self.finishTranscription(self.error(failure.localizedDescription)) }
                    }
                }
            }
        }
    }
    private func finishTranscription(_ value: Any?) {
        guard let result = transcriptionResult else { return }
        transcriptionResult = nil; transcriptionTimeout?.cancel(); transcriptionTimeout = nil
        recognition?.cancel(); recognition = nil
        result(value)
    }
    private func stopPlayback() {
        player?.stop(); player = nil
        let result = playbackResult; playbackResult = nil; result?(nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { stopPlayback() }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) { stopPlayback() }
}
