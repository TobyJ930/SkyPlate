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
                        }.accessibilityLabel(L("设置", "Settings"))
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let stale = store.flight.map { $0.unavailable || $0.expiresAt <= context.date } ?? false
                        HStack(spacing: 8) {
                            Circle().fill(stale ? .orange : lime).frame(width: 7, height: 7)
                            Text(store.demo ? L("演示模式 · 非真实航班", "Demo mode · Not a real flight") : stale ? L("数据已过期 · 等待更新", "Data stale · Waiting for an update") : store.status)
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
                            Label(store.activityEnabled ? L("关闭锁屏与灵动岛铭牌", "Turn off Live Activity") : L("显示到锁屏与灵动岛", "Show on Lock Screen & Dynamic Island"),
                                  systemImage: "platter.filled.top.iphone")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(17)
                                .background(lime, in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(ink)
                        }.disabled(store.flight == nil && !store.activityEnabled)
                        Text(L("锁屏后保留最近数据 · 返回 App 自动更新", "Last update on Lock Screen · Reopen app to refresh"))
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            Text(L("数据", "Data"))
                            Link("ADSB.lol", destination: URL(string: "https://www.adsb.lol/docs/open-data/api/")!)
                            Text("·")
                            Link("adsbdb", destination: URL(string: "https://www.adsbdb.com")!)
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(minHeight: geometry.size.height, alignment: .top)
            }.background(ink)
        }
        .sheet(isPresented: $settings) { SettingsView(store: store) }
        .alert(L("实时活动", "Live Activity"), isPresented: Binding(get: { store.activityMessage != nil },
            set: { if !$0 { store.activityMessage = nil } })) {
                Button(L("知道了", "OK")) { store.activityMessage = nil }
            } message: { Text(store.activityMessage ?? "") }
    }

    private func plate(_ f: FlightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("离你最近的空中飞机", "Nearest airborne aircraft")).font(.subheadline).foregroundStyle(.secondary)
                    Text(f.number).font(.system(size: 66, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.45).lineLimit(1).foregroundStyle(lime)
                    Text(L("呼号 \(f.callsign)  ·  \(f.aircraftType)", "Callsign \(f.callsign)  ·  \(f.aircraftType)"))
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "airplane").font(.system(size: 35))
                    .rotationEffect(.degrees(-35)).foregroundStyle(lime.opacity(0.85)).padding(.top, 32)
            }
            HStack(alignment: .top, spacing: 12) {
                airport(code: f.origin, name: f.originName, label: L("出发地", "Origin"), alignment: .leading)
                Image(systemName: "arrow.right").foregroundStyle(lime).padding(.top, 30)
                airport(code: f.destination, name: f.destinationName, label: L("目的地", "Destination"), alignment: .trailing)
            }
            .padding(20).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
            HStack(spacing: 12) {
                Text(f.airline?.badge ?? "N/A")
                    .font(.headline.monospaced()).foregroundStyle(lime)
                    .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("航空公司", "Airline")).font(.caption).foregroundStyle(.secondary)
                    Text(f.airline?.displayName(language: store.language) ?? "N/A").font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(L("应答机代码", "Squawk")).font(.caption).foregroundStyle(.secondary)
                    Text(f.squawk ?? "N/A").font(.title3.monospaced().weight(.semibold))
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 24) {
                metric(L("飞行高度", "Altitude"), value: f.altitude, icon: "arrow.up.and.down")
                metric(L("飞行速度 · 地速", "Ground speed"), value: f.speed, icon: "speedometer")
                metric(L("已飞时间", "Elapsed flight time"), value: f.elapsed, icon: "clock")
                metric(L("预计到达时间", "Estimated arrival"), value: f.arrival, icon: "clock.badge.checkmark")
            }
            Divider().overlay(.white.opacity(0.1))
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("水平距离", "Horizontal distance")).font(.caption).foregroundStyle(.secondary)
                    Text(f.distance).font(.title2.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(L("注册号 \(f.registration)", "Registration \(f.registration)")).font(.caption)
                    Text(L("数据时间 \(f.observedAt.formatted(date: .omitted, time: .standard))", "Observed \(f.observedAt.formatted(date: .omitted, time: .standard))"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(L("航线为呼号匹配参考；缺失信息显示 N/A。", "Route matched by callsign; unavailable information shows N/A."))
                .font(.caption2).foregroundStyle(.secondary)
            if store.showPhotos { aircraftPhoto }
        }
    }

    private func airport(code: String, name: String, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(code).font(.system(size: 32, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var aircraftPhoto: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("飞机照片 · 资料图片", "Aircraft photo · Reference image"))
                .font(.caption).foregroundStyle(.secondary)
            if let photo = store.photo, !store.demo, photo.aircraftHex == store.flight?.hex.lowercased() {
                AsyncImage(url: photo.thumbnail) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 200)
                    case .failure:
                        photoPlaceholder(L("照片加载失败", "Photo unavailable"))
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity).frame(height: 120)
                    @unknown default:
                        photoPlaceholder("N/A")
                    }
                }.id(photo.thumbnail)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Link(L("图片来源：Airport-Data.com · 查看原图", "Photo: Airport-Data.com · View original"), destination: photo.original)
                    .font(.caption2).foregroundStyle(.secondary)
            } else if store.photoLoading {
                ProgressView().frame(maxWidth: .infinity).frame(height: 120)
            } else {
                photoPlaceholder(store.demo ? L("演示模式不加载照片", "Photos disabled in demo mode") : "N/A")
            }
        }
    }

    private func photoPlaceholder(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane").font(.title2)
            Text(text).font(.caption)
        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 120)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
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
            Text(L("寻找你身边的航班", "Finding aircraft near you")).font(.title2.weight(.semibold))
            Text(store.status).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(L("搜索半径 \(store.radius) 海里 · 自动选择距离最近的飞机", "Search radius \(store.radius) NM · Automatically selects the nearest aircraft"))
                .font(.caption).foregroundStyle(.secondary)
            Button(L("打开设置 / 查看演示", "Settings / View demo")) { settings = true }.foregroundStyle(lime)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

struct SettingsView: View {
    @ObservedObject var store: FlightStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Language / 语言") {
                    Picker("Language / 语言", selection: $store.language) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }.pickerStyle(.segmented)
                }
                Section(L("附近航班", "Nearby aircraft")) {
                    Picker(L("搜索半径", "Search radius"), selection: $store.radius) {
                        ForEach([25, 50, 100, 250], id: \.self) { Text(L("\($0) 海里", "\($0) NM")).tag($0) }
                    }
                    Picker(L("刷新间隔", "Refresh interval"), selection: $store.interval) {
                        ForEach([15, 30, 60], id: \.self) { Text(L("\($0) 秒", "\($0) seconds")).tag($0) }
                    }
                    Toggle(L("公制单位（米 / km/h）", "Metric units (m / km/h)"), isOn: $store.metric)
                    Toggle(L("显示飞机照片", "Show aircraft photos"), isOn: $store.showPhotos)
                }
                Section {
                    Toggle(L("演示模式", "Demo mode"), isOn: $store.demo)
                } footer: { Text(L("演示模式使用虚构数据，不访问航班服务。真实模式包含通航飞机及直升机；只在数据源覆盖的飞机中选择最近一架。", "Demo mode uses fictional data without calling flight services. Live mode includes general aviation and helicopters, selecting the nearest aircraft within feed coverage.")) }
                Section(L("数据说明", "About the data")) {
                    Text(L("免费来源提供位置、气压高度和地速。商业航班号与起降机场通过呼号匹配，可能缺失或与当天实际航线不同。", "Free sources provide position, barometric altitude and ground speed. Flight numbers and airports are matched by callsign and may be missing or differ from the actual route."))
                    Text(L("当前来源不提供实际起飞时间与预计到达时间，所以已飞时间与预计到达时间显示 N/A，不使用首次发现时间或距离估算代替。", "Current sources do not provide actual takeoff time or ETA. Elapsed time and estimated arrival show N/A; first-seen time and distance estimates are not substitutes."))
                    Text(L("锁屏与灵动岛显示最近一次数据，数据超过 60 秒标为过期。App 在前台时自动刷新，持续后台更新需要服务器推送。", "Lock Screen and Dynamic Island show the last update, marked stale after 60 seconds. Updates run while the app is open. Continuous background updates require server push."))
                }.font(.footnote)
                Section(L("位置与隐私", "Location & privacy")) {
                    Text(L("仅在使用 App 时定位。你的坐标会发送给 ADSB.lol 以查询附近飞机；只把飞机呼号发送给 adsbdb 查询航线。无账号、无广告、无自建服务器，不记录位置历史。", "Location is used only while the app is open. Coordinates go to ADSB.lol for nearby aircraft; callsigns go to adsbdb for routes. No accounts, ads, custom server or stored location history."))
                    Link(L("打开 iPhone App 设置", "Open iPhone app settings"), destination: URL(string: UIApplication.openSettingsURLString)!)
                }.font(.footnote)
                LocationDiagnostics(provider: store.location)
                Section(L("照片与航空公司", "Photos & airlines")) {
                    Text(L("照片按飞机的 Mode-S 地址查询，属于资料图片，并非实时拍摄。查询将飞机地址发送给 adsbdb，图片由 Airport-Data.com 加载；不发送你的位置。没有照片时显示 N/A。", "Photos are reference images matched by Mode-S address, not live images. The aircraft address is sent to adsbdb; images load from Airport-Data.com. Your location is not sent to these services. Missing photos show N/A."))
                    Text(L("航空公司来自呼号匹配结果，仅供参考；机场与航空公司专有名称可能保留数据源原文。字母标识是航空公司代码，不是官方 Logo。", "Airline information is matched by callsign for reference. Airport and airline proper names may remain in the source language. Letter badges are airline codes, not official logos."))
                }.font(.footnote)
                Section(L("来源与许可", "Sources & licenses")) {
                    Link("ADSB.lol · ODbL 1.0", destination: URL(string: "https://www.adsb.lol/docs/open-data/api/")!)
                    Link(L("adsbdb · 航线参考", "adsbdb · Route reference"), destination: URL(string: "https://www.adsbdb.com")!)
                }
            }
            .navigationTitle(L("设置", "Settings"))
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(L("完成", "Done")) { dismiss() }
            } }
            .onChange(of: store.radius) { _, _ in store.settingsChanged() }
            .onChange(of: store.interval) { _, _ in store.settingsChanged() }
            .onChange(of: store.metric) { _, _ in store.settingsChanged() }
            .onChange(of: store.demo) { _, _ in store.settingsChanged() }
            .onChange(of: store.language) { _, _ in store.languageChanged() }
            .onChange(of: store.showPhotos) { _, _ in store.photosChanged() }
        }.preferredColorScheme(.dark)
    }
}

struct LocationDiagnostics: View {
    @ObservedObject var provider: LocationProvider
    var body: some View {
        Section(L("定位诊断", "Location diagnostics")) {
            LabeledContent(L("运行设备", "Environment"), value: provider.environment)
            LabeledContent(L("权限", "Permission"), value: provider.permission)
            LabeledContent(L("精度授权", "Accuracy authorization"), value: provider.accuracy)
            LabeledContent(L("最近错误", "Last error"), value: provider.lastError)
            Text(provider.message).font(.footnote)
            if let point = provider.location {
                LabeledContent(L("位置时间", "Location timestamp"), value: point.timestamp.formatted(date: .omitted, time: .standard))
                LabeledContent(L("位置精度", "Location accuracy"), value: String(format: "±%.0f m", point.horizontalAccuracy))
            }
            Button(L("重新定位", "Retry location")) { provider.retry() }
            #if targetEnvironment(simulator)
            Text(L("模拟器不会自动使用 iPhone 的 GPS。请在模拟器顶部菜单 Features → Location → Custom Location 设置经纬度。奥克兰示例：-36.8485, 174.7633。此位置仅用于模拟测试。", "Simulator does not automatically use your iPhone GPS. Set Features → Location → Custom Location. Auckland example: -36.8485, 174.7633. For simulated testing only."))
                .font(.footnote)
            #endif
        }
    }
}
