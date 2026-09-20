import SwiftUI
import UIKit

private let lime = Color(red: 0.78, green: 0.98, blue: 0.36)
private let ink = Color(red: 0.035, green: 0.065, blue: 0.105)

struct ContentView: View {
    @ObservedObject var store: FlightStore
    @State private var settings = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Label("SKYPLATE", systemImage: "airplane").font(.headline).tracking(3)
                        Spacer()
                        Button { settings = true } label: {
                            Image(systemName: "slider.horizontal.3").padding(12)
                                .background(.white.opacity(0.07), in: Circle())
                        }.accessibilityLabel("设置")
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let stale = store.flight.map { $0.unavailable || $0.expiresAt <= context.date } ?? false
                        HStack(spacing: 8) {
                            Circle().fill(stale ? .orange : lime).frame(width: 7, height: 7)
                            Text(store.demo ? "演示模式 · 非真实航班" : stale ? "数据已过期 · 等待更新" : store.status)
                                .font(.caption).foregroundStyle(.secondary)
                            if store.busy { ProgressView().scaleEffect(0.65) }
                        }
                    }
                    if let flight = store.flight { plate(flight) }
                    else { emptyState }
                    Spacer(minLength: 0)
                    VStack(spacing: 12) {
                        Button {
                            Task { await store.toggleActivity() }
                        } label: {
                            Label(store.activityEnabled ? "关闭锁屏与灵动岛铭牌" : "显示到锁屏与灵动岛",
                                  systemImage: "platter.filled.top.iphone")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(17)
                                .background(lime, in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(ink)
                        }.disabled(store.flight == nil && !store.activityEnabled)
                        Text("锁屏后保留最近数据 · 返回 App 自动更新")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            Text("数据")
                            Link("ADSB.lol", destination: URL(string: "https://www.adsb.lol/docs/open-data/api/")!)
                            Text("·")
                            Link("adsbdb", destination: URL(string: "https://www.adsbdb.com")!)
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(minHeight: geometry.size.height, alignment: .top)
            }.background(ink)
        }
        .sheet(isPresented: $settings) { SettingsView(store: store) }
        .alert("实时活动", isPresented: Binding(get: { store.activityMessage != nil },
            set: { if !$0 { store.activityMessage = nil } })) {
                Button("知道了") { store.activityMessage = nil }
            } message: { Text(store.activityMessage ?? "") }
    }

    private func plate(_ f: FlightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("离你最近的空中飞机").font(.subheadline).foregroundStyle(.secondary)
                    Text(f.number).font(.system(size: 66, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.45).lineLimit(1).foregroundStyle(lime)
                    Text("呼号 \(f.callsign)  ·  \(f.aircraftType)")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "airplane").font(.system(size: 35))
                    .rotationEffect(.degrees(-35)).foregroundStyle(lime.opacity(0.85)).padding(.top, 32)
            }
            HStack(alignment: .top, spacing: 12) {
                airport(code: f.origin, name: f.originName, label: "出发地", alignment: .leading)
                Image(systemName: "arrow.right").foregroundStyle(lime).padding(.top, 30)
                airport(code: f.destination, name: f.destinationName, label: "目的地", alignment: .trailing)
            }
            .padding(20).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 24) {
                metric("飞行高度", value: f.altitude, icon: "arrow.up.and.down")
                metric("飞行速度 · 地速", value: f.speed, icon: "speedometer")
                metric("已飞时间", value: f.elapsed, icon: "clock")
                metric("预计到达时间", value: f.arrival, icon: "clock.badge.checkmark")
            }
            Divider().overlay(.white.opacity(0.1))
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("水平距离").font(.caption).foregroundStyle(.secondary)
                    Text(f.distance).font(.title2.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("注册号 \(f.registration)").font(.caption)
                    Text("数据时间 \(f.observedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("航线为呼号匹配参考；缺失信息显示 N/A。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func airport(code: String, name: String, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(code).font(.system(size: 32, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 23, weight: .medium, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.65).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            ZStack {
                ForEach(1..<4) { index in
                    Circle().stroke(lime.opacity(0.12), lineWidth: 1)
                        .frame(width: CGFloat(index) * 64, height: CGFloat(index) * 64)
                }
                Image(systemName: "airplane").font(.system(size: 40)).foregroundStyle(lime)
            }.frame(height: 220)
            Text("寻找你身边的航班").font(.title2.weight(.semibold))
            Text(store.status).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("搜索半径 \(store.radius) 海里 · 自动选择距离最近的飞机")
                .font(.caption).foregroundStyle(.secondary)
            Button("打开设置 / 查看演示") { settings = true }.foregroundStyle(lime)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

struct SettingsView: View {
    @ObservedObject var store: FlightStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("附近航班") {
                    Picker("搜索半径", selection: $store.radius) {
                        ForEach([25, 50, 100, 250], id: \.self) { Text("\($0) 海里").tag($0) }
                    }
                    Picker("刷新间隔", selection: $store.interval) {
                        ForEach([15, 30, 60], id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Toggle("公制单位（米 / km/h）", isOn: $store.metric)
                }
                Section {
                    Toggle("演示模式", isOn: $store.demo)
                } footer: { Text("演示模式使用虚构数据，不访问航班服务。真实模式包含通航飞机及直升机；只在数据源覆盖的飞机中选择最近一架。") }
                Section("数据说明") {
                    Text("免费来源提供位置、气压高度和地速。商业航班号与起降机场通过呼号匹配，可能缺失或与当天实际航线不同。")
                    Text("当前来源不提供实际起飞时间与预计到达时间，所以已飞时间与预计到达时间显示 N/A，不使用首次发现时间或距离估算代替。")
                    Text("锁屏与灵动岛显示最近一次数据，数据超过 60 秒标为过期。App 在前台时自动刷新，持续后台更新需要服务器推送。")
                }.font(.footnote)
                Section("位置与隐私") {
                    Text("仅在使用 App 时定位。你的坐标会发送给 ADSB.lol 以查询附近飞机；只把飞机呼号发送给 adsbdb 查询航线。无账号、无广告、无自建服务器，不记录位置历史。")
                    Link("打开 iPhone App 设置", destination: URL(string: UIApplication.openSettingsURLString)!)
                }.font(.footnote)
                LocationDiagnostics(provider: store.location)
                Section("来源与许可") {
                    Link("ADSB.lol · ODbL 1.0", destination: URL(string: "https://www.adsb.lol/docs/open-data/api/")!)
                    Link("adsbdb · 航线参考", destination: URL(string: "https://www.adsbdb.com")!)
                }
            }
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            } }
            .onChange(of: store.radius) { _, _ in store.settingsChanged() }
            .onChange(of: store.interval) { _, _ in store.settingsChanged() }
            .onChange(of: store.metric) { _, _ in store.settingsChanged() }
            .onChange(of: store.demo) { _, _ in store.settingsChanged() }
        }.preferredColorScheme(.dark)
    }
}

struct LocationDiagnostics: View {
    @ObservedObject var provider: LocationProvider
    var body: some View {
        Section("定位诊断") {
            LabeledContent("运行设备", value: provider.environment)
            LabeledContent("权限", value: provider.permission)
            LabeledContent("精度授权", value: provider.accuracy)
            LabeledContent("最近错误", value: provider.lastError)
            Text(provider.message).font(.footnote)
            if let point = provider.location {
                LabeledContent("位置时间", value: point.timestamp.formatted(date: .omitted, time: .standard))
                LabeledContent("位置精度", value: String(format: "±%.0f m", point.horizontalAccuracy))
            }
            Button("重新定位") { provider.retry() }
            #if targetEnvironment(simulator)
            Text("模拟器不会自动使用 iPhone 的 GPS。请在模拟器顶部菜单 Features → Location → Custom Location 设置经纬度。奥克兰示例：-36.8485, 174.7633。此位置仅用于模拟测试。")
                .font(.footnote)
            #endif
        }
    }
}
