import ActivityKit
import WidgetKit
import SwiftUI

@main
struct MyAgendaActivityBundle: WidgetBundle {
    var body: some Widget { MyAgendaActivity() }
}

struct MyAgendaActivity: Widget {
    private let accent = Color(red: 0.46, green: 0.55, blue: 1)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgendaActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("MYAGENDA", systemImage: "calendar")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(accent)
                    Spacer()
                    Text(label(context)).font(.caption.weight(.medium))
                }
                Text(context.state.title).font(.headline).lineLimit(2)
                HStack {
                    Label(context.isStale ? "Ouvrez MyAgenda" : "Votre prochain pas", systemImage: "arrow.up.right")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    timer(context).font(.title3.monospacedDigit().weight(.semibold))
                }
                if context.state.progress > 0 {
                    ProgressView(value: context.state.progress).tint(accent)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.09, green: 0.11, blue: 0.19))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(taskURL(context.attributes.taskId))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("MyAgenda", systemImage: "calendar").font(.caption).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title).font(.headline).lineLimit(2)
                        Text(label(context)).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.mode == "paused" ? "pause.circle.fill" : "calendar").foregroundStyle(accent)
            } compactTrailing: {
                timer(context).font(.caption2.monospacedDigit()).frame(maxWidth: 60)
            } minimal: {
                Image(systemName: "calendar").foregroundStyle(accent)
            }
            .widgetURL(taskURL(context.attributes.taskId))
            .keylineTint(accent)
        }
    }
    private func label(_ context: ActivityViewContext<AgendaActivityAttributes>) -> String {
        if context.isStale { return "Créneau écoulé" }
        switch context.state.mode {
        case "running": return "En cours"
        case "paused": return "En pause"
        default: return "À réaliser maintenant"
        }
    }
    @ViewBuilder
    private func timer(_ context: ActivityViewContext<AgendaActivityAttributes>) -> some View {
        if context.isStale {
            Image(systemName: "clock.badge.exclamationmark")
        } else if context.state.mode == "paused" {
            Text("\(context.state.elapsedSeconds / 60) min")
        } else {
            Text(timerInterval: context.state.start...max(context.state.end, context.state.start.addingTimeInterval(1)), countsDown: context.state.mode != "running")
        }
    }
    private func taskURL(_ id: String) -> URL? {
        var url = URLComponents()
        url.scheme = "myagenda"; url.host = "task"
        url.queryItems = [URLQueryItem(name: "id", value: id)]
        return url.url
    }
}
