# SkyPlate · 最近航班铭牌

版本 **1.0.1 / build 2**：已修改定位错误处理、前后台生命周期和重试逻辑，加入定位诊断。TestFlight 的 Mac 验证、签名归档和导出请先阅读 `MAC_HANDOFF.md`。当前包仍为源码，未签名、未归档、未上传。

给 iPhone 使用的 SwiftUI 原生 App，支持 iOS 17.0 及以上。打开 App 后自动定位，每 15 秒查询附近空中飞机，并用全屏铭牌显示距离最近的一架。无需 API 密钥，无第三方 Swift 依赖。

## 在 Mac 上安装到你的 iPhone

1. 解压整个压缩包，双击 `SkyPlate.xcodeproj`。不要只打开某个 Swift 文件。
2. 在 Xcode → Settings → Accounts 中添加你的 Apple Account。
3. 左侧点击蓝色 SkyPlate 工程图标，选择 TARGETS → **SkyPlate** → Signing & Capabilities：勾选 Automatically manage signing，Team 选择你的账号；再选择 PROJECT → SkyPlate → Build Settings，搜索 `SKYPLATE_BUNDLE_ID`，将它改成你自己的唯一名称，例如 `com.zhexushi.skyplate2026`（如已有 App Store Connect 记录，沿用对应 ID）。
4. 同样设置 **SkyPlateWidget** 的 Team。它的 Bundle Identifier 会通过共享变量自动使用主 App ID 加 `.widget` 后缀。两个 target 的 Team 必须相同。测试 target 只在你运行测试时需要设置 Team。
5. 用数据线连接 iPhone，信任这台 Mac。在 iPhone 设置 → 隐私与安全性 → 开发者模式中启用开发者模式，按提示重启。
6. Xcode 顶部 Scheme 选择 **SkyPlate**，运行设备选择你的 **iPhone 17 Pro Max**，点击 ▶ 或按 Command + R。
7. 首次打开 App 选择“使用 App 期间允许”定位。数据加载需要网络和附近接收站覆盖，航线信息可能稍晚出现。
8. 点击“显示到锁屏与灵动岛”，然后锁屏查看。长按灵动岛查看展开铭牌，轻点返回 App。

如果手机系统比 Xcode 支持的版本更新，请先升级 Xcode。此工程使用常规 iOS 17 API，可在支持你手机系统的新版 Xcode 中打开。

不需要先购买航班 API 或 Apple 开发者付费会员。个人真机运行通常可选择 Personal Team；个人免费签名可能需要定期连接 Xcode 重新安装。不要把账户密码或签名证书发给别人。

## 先看界面

可以选择一个 iPhone 模拟器运行，进入右上角设置，开启“演示模式”。演示使用虚构航班 NZ123，所有界面明确标示演示；网络失败时不会偷偷切换成假数据。

真实模式在模拟器中需要提供模拟定位：模拟器菜单 Features → Location → Custom Location，可用 Auckland `-36.8485, 174.7633`。真机使用手机定位。

## 已实现的功能与边界

| 内容 | 当前行为 |
|---|---|
| 最近飞机 | 在指定半径内、位置年龄不超过 60 秒、确认处于空中的飞机中，按球面水平距离选择；包含通航飞机及直升机 |
| 搜索半径 | 25 / 50 / 100 / 250 海里；默认 100 海里（约 185 km） |
| 刷新频率 | 前台每 15 / 30 / 60 秒；网络错误和限流时延后重试 |
| 航班号 | adsbdb 返回的商业航班号；找不到时显示 N/A，并独立显示广播呼号，不把呼号冒充商业航班号 |
| 起降机场 | adsbdb 按呼号匹配的航线参考；不是当天实际航线的确认，可能不准或缺失 |
| 高度 | 优先气压高度，缺失时使用几何高度；不代表距地高度；英尺 / 米可切换 |
| 速度 | 地速，不是空速；节 / km/h 可切换 |
| 已飞时间 | 当前免费来源不提供可信起飞时间，因此 N/A |
| 预计到达时间 | 当前免费来源不提供 ETA，因此 N/A |
| 锁屏 / 灵动岛 | ActivityKit 实时活动界面；App 前台刷新时同步；后台显示最后一份数据，60 秒后标记过期 |
| 持续后台跟踪 | **本版未实现**。不是锁屏后仍能持续追踪的完整后台服务，见下文 |

“实时”表示定期获取数据源最新可用数据，不保证无延迟、无覆盖缺口。无数据不代表附近没有飞机。当前版本不估算缺失的航班时间，不将第一次发现飞机的时间当作起飞时间。

## 锁屏后为什么不会持续更新？

iOS 不保证普通 App 在后台持续执行轮询；实时活动本身不能联网或定位。本版在 App 离开前台时停止定位与请求，不使用音频保活等绕过方式。锁屏与灵动岛会展示最后一次数据并标记过期。展开铭牌可以看到全部字段，紧凑灵动岛空间有限，只显示航班号与距离/过期状态。

若之后要做持续后台版本，需要：

- 有持续运行能力的服务器查询航班并向 Apple Push Notification service（APNs）发送 ActivityKit 更新。
- 配置 Apple 推送凭证、App 签名权限及实时活动 push token 注册（通常需要 Apple Developer Program）。本工程没有启用该能力，也没有内置推送服务。
- 决定是继续使用最后已知用户位置，还是另外设计经用户授权的后台定位。只加推送不能解决用户移动后的“最近飞机”计算。
- 若要真正显示已飞时间及 ETA，需要额外接入能提供当前航段实际起飞时间、预计到达时间的数据服务。

## 隐私与数据来源

仅在前台请求使用位置。坐标通过 HTTPS 发送给 ADSB.lol 查询附近飞机；呼号发送给 adsbdb 查询航线。无分析 SDK、账号系统或自建服务器，不持久保存坐标或航班历史；航线只在内存缓存，失败缓存 5 分钟、成功缓存 30 分钟。系统或网络服务的自身日志不由本 App 控制。

- ADSB.lol API（ODbL 1.0）：https://www.adsb.lol/docs/open-data/api/
- API 源码与文档入口：https://github.com/adsblol/api
- 航线查询：https://www.adsbdb.com
- Apple 实时活动：https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- Apple 个人账号与真机调试：https://developer.apple.com/help/account/basics/about-your-developer-account

本项目按个人使用设计。将来公开上架或商业分发前，需要重新核对数据源使用条款、署名和数据再分发要求。

## 工程结构

- `App/`：SwiftUI 界面、Core Location、网络服务、最近航班追踪和实时活动管理。
- `Shared/`：纯数据模型、距离/新鲜度筛选、App 与扩展共用的 ActivityAttributes。
- `Widget/`：锁屏和灵动岛布局。
- `Tests/`：过期数据、地面飞机、搜索半径、缺失值和航线解析等 XCTest。
- `Scripts/check-on-mac.sh`：在 Mac 上进行未签名模拟器构建。

没有 Swift Package 依赖，不需要 Homebrew、CocoaPods 或 XcodeGen。

## 验证状态

生成环境为 Linux，**没有 Xcode / Apple SDK，因此没有实际编译或进行真机验收**。已通过 Swift 语法解析检查（不等于编译），并使用独立 OpenStep 解析器检查工程文件；已检查工程对象引用、文件路径、target 依赖、Info.plist 和 scheme XML，并对真实公共 API 的字段进行了核对。XCTest 已写入工程，尚未执行。

在 Mac 可用终端执行：

```bash
cd /你的路径/SkyPlate
bash Scripts/check-on-mac.sh
```

在 Xcode 中选择 iPhone 模拟器，再按 Command + U 运行测试。真机验收时检查：允许/拒绝定位、切换单位、移动后的最近飞机切换、开启实时活动、锁屏超过一分钟变为过期、断网后错误提示、重新进入 App 恢复刷新。因为免费接收站覆盖有限，界面可能暂时显示无数据。

如果安装时提示签名错误，先检查主 App 与 Widget 的 Team 和 Bundle Identifier。若遇到 Swift 编译错误，可提供第一条红色错误及所在行，以便定位。
