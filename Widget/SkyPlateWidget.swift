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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(context.state.demo ? "演示航班" : "最近航班", systemImage: "airplane")
                        .font(.caption).foregroundStyle(accent)
                    Spacer()
                    Text(context.state.distance).font(.caption)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(context.state.number).font(.title2.bold()).foregroundStyle(accent)
                    Spacer()
                    Text("\(context.state.origin) → \(context.state.destination)").font(.headline)
                }
                HStack {
                    Text("高度 \(context.state.altitude)")
                    Spacer()
                    Text("地速 \(context.state.speed)")
                }.font(.caption)
                HStack {
                    Text("已飞 \(context.state.elapsed)")
                    Spacer()
                    Text("预计到达 \(context.state.arrival)")
                }.font(.caption)
                Text(status(context)).font(.caption2)
                    .foregroundStyle(expired(context) ? Color.orange : Color.secondary)
            }
            .padding(16)
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
                            Text("已飞 \(context.state.elapsed)")
                            Spacer()
                            Text("预计到达 \(context.state.arrival)")
                        }.font(.caption)
                        Text(status(context)).font(.caption2)
                            .foregroundStyle(expired(context) ? Color.orange : Color.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: expired(context) ? "clock.badge.exclamationmark" : "airplane")
                    Text(context.state.number).lineLimit(1).minimumScaleFactor(0.6)
                }.font(.caption2).foregroundStyle(expired(context) ? .orange : accent)
            } compactTrailing: {
                Text(context.state.demo ? "演示" : expired(context) ? "过期" : context.state.distance)
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
        let prefix = context.state.demo ? "演示 · " : ""
        if expired(context) { return prefix + "数据已过期 · 点击返回 App 更新" }
        return prefix + "数据 \(context.state.observedAt.formatted(date: .omitted, time: .standard)) · 锁屏后暂停更新"
    }
}
