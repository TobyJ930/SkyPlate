import ActivityKit
import WidgetKit
import SwiftUI

private let accent = Color(red: 0.78, green: 0.98, blue: 0.36)

@main
struct SkyPlateWidgets: WidgetBundle {
    var body: some Widget { NearestFlightActivity() }
}

struct NearestFlightActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(context.state.demo ? L("演示航班", "Demo flight", language: context.state.language) : L("最近航班", "Nearest flight", language: context.state.language), systemImage: "airplane")
                        .font(.caption).foregroundStyle(accent)
                    Spacer()
                    Text(context.state.distance).font(.caption)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(context.state.number).font(.title3.bold()).foregroundStyle(accent)
                    Spacer()
                    Text("\(context.state.origin) → \(context.state.destination)").font(.headline)
                }
                HStack {
                    Text(context.state.airline?.displayName(language: context.state.language) ?? "N/A").lineLimit(1)
                    Spacer()
                    Text("Squawk \(context.state.squawk ?? "N/A")").monospacedDigit()
                }.font(.caption)
                HStack {
                    Text(L("高度 \(context.state.altitude)", "Altitude \(context.state.altitude)", language: context.state.language))
                    Spacer()
                    Text(L("地速 \(context.state.speed)", "Speed \(context.state.speed)", language: context.state.language))
                }.font(.caption)
                HStack {
                    Text(L("已飞 \(context.state.elapsed)", "Elapsed \(context.state.elapsed)", language: context.state.language))
                    Spacer()
                    Text(L("预计到达 \(context.state.arrival)", "ETA \(context.state.arrival)", language: context.state.language))
                }.font(.caption)
                Text(status(context)).font(.caption2).lineLimit(1)
                    .foregroundStyle(expired(context) ? Color.orange : Color.secondary)
            }
            .padding(12)
            .activityBackgroundTint(Color(red: 0.035, green: 0.065, blue: 0.105))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.state.number).font(.title3.bold()).foregroundStyle(accent)
                        Text("\(context.state.origin) → \(context.state.destination)").font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.altitude).font(.headline)
                        Text(context.state.speed).font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        HStack {
                            Text(context.state.airline?.displayName(language: context.state.language) ?? "N/A").lineLimit(1)
                            Spacer()
                            Text("Squawk \(context.state.squawk ?? "N/A")").monospacedDigit()
                        }.font(.caption)
                        HStack {
                            Text(L("已飞 \(context.state.elapsed)", "Elapsed \(context.state.elapsed)", language: context.state.language))
                            Spacer()
                            Text(L("预计到达 \(context.state.arrival)", "ETA \(context.state.arrival)", language: context.state.language))
                        }.font(.caption)
                        Text(status(context)).font(.caption2).lineLimit(1)
                            .foregroundStyle(expired(context) ? Color.orange : Color.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: expired(context) ? "clock.badge.exclamationmark" : "airplane")
                    Text(context.state.number).lineLimit(1).minimumScaleFactor(0.6)
                }.font(.caption2).foregroundStyle(expired(context) ? .orange : accent)
            } compactTrailing: {
                Text(context.state.demo ? L("演示", "Demo", language: context.state.language) : expired(context) ? L("过期", "Stale", language: context.state.language) : context.state.distance)
                    .font(.caption2).monospacedDigit()
            } minimal: {
                Image(systemName: expired(context) ? "clock.badge.exclamationmark" : "airplane")
                    .foregroundStyle(expired(context) ? .orange : accent)
            }
            .keylineTint(accent)
        }
    }

    private func expired(_ context: ActivityViewContext<FlightAttributes>) -> Bool {
        context.isStale || context.state.unavailable
    }
    private func status(_ context: ActivityViewContext<FlightAttributes>) -> String {
        let prefix = context.state.demo ? L("演示 · ", "Demo · ", language: context.state.language) : ""
        if expired(context) { return prefix + L("数据已过期 · 点击返回 App 更新", "Data stale · Tap to reopen and refresh", language: context.state.language) }
        return prefix + L("数据 \(context.state.observedAt.formatted(date: .omitted, time: .standard)) · 锁屏后暂停更新", "Observed \(context.state.observedAt.formatted(date: .omitted, time: .standard)) · Paused on Lock Screen", language: context.state.language)
    }
}
