# 在 Mac 上继续：定位验证与 TestFlight

这是一份源码工程，版本 1.1.0 / build 3。云端没有 Mac 访问通道、Xcode 或签名凭据：**尚未生成 .xcarchive / .ipa，也没有上传 TestFlight**。不要把 ZIP 当成可直接上传的 IPA。

## 已做的定位修复

- 临时 `kCLErrorDomain / 0`（locationUnknown）不再被误报为权限问题，继续等待定位；保留仍有效的位置。
- 仅用 `startUpdatingLocation()` 持续定位，不混用单次请求。
- 权限弹窗触发 `.inactive` 时不停止定位，真正进入 `.background` 时才停止。
- 没有新定位时节流重试；排除无效精度、过旧和异常未来时间的位置。
- 设置页加入运行环境、授权、精度、时间和错误码，以及“重新定位”。不会自动伪造用户位置。

这些是代码中确认存在的问题及改进，尚不能证明它们就是用户设备上定位失败的唯一原因。

## 请 Mac 上的 Codex 完成

1. 使用本次下载解压的工程，先检查所在目录及用户已有改动。若合并到原工程，保留用户配置的 Team 和 Bundle ID；不要直接覆盖其签名配置。
2. 检查本地 AGENTS.md（如有）、`xcodebuild -version`、可用 iPhone 模拟器和连接的真机。使用本地可用能力，不假定具有桌面鼠标控制。
3. 运行 `bash Scripts/check-on-mac.sh`，修复实际编译错误。然后选定真实存在的模拟器目的地，执行 `xcodebuild test` 或 Xcode Command + U。16 个 XCTest 包含新增的 5 个定位回归测试。
4. 确认用户是在真机还是模拟器遇到问题。模拟器需要设置位置：模拟器菜单 Features → Location → Custom Location，输入 `-36.8485, 174.7633`。也可在 Xcode 的 Debug → Simulate Location 选择项目里的 GPX；不要把模拟定位当作真机 GPS 已修复。
5. 真机检查系统定位总开关、App 的“使用期间允许”及诊断错误码。连接调试时先排除 Xcode 的模拟定位覆盖（Debug → Simulate Location → Don't Simulate Location）。验证首次授权、暂时定位失败、拒绝后恢复、切回前台、静止超过两分钟。需要截图或设备日志时，只索取相关内容。
6. 先完成真机定位验收，再归档。确认用户有有效 Apple Developer Program 会员、正确 Team 和 App Store Connect App 记录。只看到 Xcode 已登录不等于具备分发权限。
7. 用户已请求准备 TestFlight 版本：可以进行签名归档及导出。若存在多个 Team / App 记录且无法确定目标，应先询问。不要创建付费会员、公开发布 App Store 版本或擅自邀请测试者。
8. 使用下面脚本生成签名归档和 IPA。报告真实的构建和测试结果、输出路径以及仍存在的阻碍。只有上传成功并完成处理后才能说“TestFlight 已可用”。

## 归档 / 导出

先在 App Store Connect 建立对应 Bundle ID 的 App 记录（如果已有记录，必须沿用）。主 App 和 Widget 需使用同一 Team，Widget 的 Bundle ID 必须以主 App ID 为前缀。

在工程目录中执行，替换示例值：

```bash
SKYPLATE_TEAM_ID=ABCDEFGHIJ \
SKYPLATE_BUNDLE_ID=com.yourname.skyplate \
SKYPLATE_BUILD_NUMBER=3 \
bash Scripts/archive-testflight.sh
```

脚本使用共享自定义设置 `SKYPLATE_BUNDLE_ID`，自动令扩展使用 `.widget` 后缀。不要通过全局 `PRODUCT_BUNDLE_IDENTIFIER=...` 覆盖全部 target，否则会使扩展和主 App 的 ID 相同。再次上传需要递增 build number。

脚本会通过 Xcode 自动签名功能申请所需 provisioning profile，在工程目录下新建独立输出文件夹，生成 `.xcarchive` 并尝试导出 App Store Connect 格式 `.ipa`；不会自动上传。若导出失败，成功生成的 archive 仍保留，可在 Organizer 中处理签名问题。Personal Team 不能完成 TestFlight 分发签名。

也可以在 Xcode 配置签名，选择 Any iOS Device (arm64)，执行 Product → Archive。在 Organizer 中选择 Distribute App → App Store Connect，按 Xcode 提示验证、上传。完成后在 App Store Connect 的 TestFlight 页面等待处理并完成要求的信息，再配置你自己的内部测试。外部测试另有 Apple 测试审核要求。

仅系统 HTTPS 通信，无自定义加密实现；上传时按 App Store Connect 的实际问题完成出口合规问答。不要凭空填写联系人、隐私政策 URL、会员状态或其他账号资料。

## 验证状态

云端可做：Swift 语法解析、工程 / plist / 资源引用检查、脚本语法检查。
云端不能做：Apple SDK 类型检查、XCTest 执行、真机定位验证、签名归档、IPA 导出或上传。

## Apple 资料

- 定位请求：https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()
- 上传构建：https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- TestFlight：https://developer.apple.com/testflight/
- 会员与 Personal Team：https://developer.apple.com/help/account/basics/about-your-developer-account

## 本次新增功能验收

在设置切换中文 / English 并重启 App，检查选择保留。开启 Live Activity 后切换语言，确认锁屏与展开灵动岛同步语言、航空公司和 Squawk。机场专名不强制翻译。检查 0042 的前导零、N/A 回退、照片失败占位、切换飞机时不残留上一架照片、关闭照片开关后停止照片请求。演示航班的名称和代码是虚构示例，不显示真实照片。

语言和照片开关使用本机 UserDefaults 持久保存。已在 App 与 Widget 资源中加入 PrivacyInfo.xcprivacy，声明 CA92.1 的本 App 偏好设置用途。归档时检查隐私报告和资源打包。
