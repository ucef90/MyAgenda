import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct AgendaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var mode: String
        var start: Date
        var end: Date
        var elapsedSeconds: Int
        var progress: Double
        var nextTitle: String?
        var nextAt: Date?
        var category: String?
    }
    var taskId: String
    var sessionKey: String
}
