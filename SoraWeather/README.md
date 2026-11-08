# Sora Weather · 空の天気

SwiftUI 原生 iPhone / iPad 天气 App，最低 **iOS 26.0**，使用系统 `glassEffect` Liquid Glass。深蓝渐变背景、地区预报、预报时段横向卡片、最多 7 日列表与防灾信息。中日双语、无需 Yahoo 用户登录，无广告 SDK、无网页脚本、无注册、无自建服务器。

## 交付状态与数据范围

本项目包含可直接打开的 `.xcodeproj`、共享 Scheme、Swift Package 核心测试、精简真实数据样本、IPA 构建脚本与 GitHub Actions。

核心解析、7 日范围、缓存迁移和降雨提醒使用 `swift test` 验证；Xcode 归档与城市交互回归结果见 GitHub Actions。编译通过不等于通过真机体验与通知投递验收；模拟器也不能证明稳定 120fps。

| 请求功能 | 当前实现与限制 |
|---|---|
| Yahoo 补充 | 读取公开 HTML 补充时段气温和降水；不保存风速、风向，失败时只显示 JMA |
| JMA 主天气 | 地区代码和气温站代码匹配，保留真正的发布时间；不按数组第一个地区盲选 |
| 逐小时 | 保留时间预报入口，**实际显示 Yahoo 3 小时与 Yahoo/JMA 6 小时降雨概率**。这些免费来源未提供真正逐小时值，不做插值伪造 |
| 7 日预报 | 从日本时间今天起最多 7 日；只显示来源实际提供的日期，少于 7 日时不补行 |
| 实时气温 | 未接实时观测源；显示最低/最高预报，不把预报写成实测气温 |
| 自动定位 | 首次请求 When In Use；选择 45 km 内最近的受支持城市；不覆盖时明确提示、保留所选城市，初始大阪 |
| 城市覆盖 | 大阪、东京、京都、神户、名古屋、福冈；目前用真实样本验收了大阪，其他城市映射需 CI/真机网络核对。非日本全国覆盖 |
| 大阪细分 | 地区日预报为大阪；3 小时详细预报为住吉区。其他城市使用中心区，设置中说明 |
| 降雨概率 | 保留来源时段与空值；不把降水量换算为概率，不把各时段最大概率冒充全天概率 |
| 普通降雨提醒 | 不填任何密钥即可按预报时段降水量/概率安排本地提醒。非精确起雨提醒 |
| 短时降雨提醒 | 可选开发者 Yahoo Client ID；约未来 60 分钟降雨强度。开发者申请需要自行办理，终端用户不用登录 |
| 气象/地震 | JMA 府县级警报/注意报摘要、全国最近地震；显示原文、发布时间及获取时间，入口链接至官方防灾页 |
| 紧急预警 | **不提供 EEW 实时地震预警、海啸警报推送、避难指示或 Critical Alerts** |

要实现来源未提供的完整逐小时预报，需要另行接入经授权、确实覆盖该字段的预报服务。Yahoo 公开降雨 API 并不是完整天气预报 API。项目没有擅自添加第三方预报源来填补这些空缺。

## 用 Xcode 打开

1. 在 Mac 安装 Xcode 26.x，解压后打开 `SoraWeather.xcodeproj`，选择共享 Scheme `SoraWeather`。
2. 使用 iOS 26 模拟器可直接构建。真机：在 Signing & Capabilities 选择自己的 Team，将 Bundle Identifier 改为自己可用的唯一值。
3. Run。默认大阪，首次可允许定位。通知权限通过设置页主动请求；拒绝后可以跳转系统设置重新开启。
4. `swift test` 运行核心测试（它们是 Swift Package tests，**不是 Xcode App Scheme 下的测试 target**）。

命令行：

```bash
swift test
python3 scripts/validate_project.py
xcodebuild -project SoraWeather.xcodeproj -scheme SoraWeather \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Swift Package 无外部依赖。App 只使用 Apple 系统框架。无第三方工程生成工具依赖。

## GitHub Actions 构建 IPA

将解压目录的**全部内容，包含隐藏的 `.github` 文件夹**，上传到你自己的 GitHub 仓库根目录。未创建或发布任何远程仓库。

Actions → **Sora Weather iOS** → Run workflow。默认 `signed=false`：

1. 选择 runner 中安装的最高 Xcode 26.x；没有 26 则明确失败，不静默使用旧 SDK。
2. 运行结构检查与 `swift test --enable-code-coverage`。
3. 构建 iOS 26 模拟器 App，安装、启动并保存诊断截图。启动检查不等于所有 UI 或网络请求通过。
4. Archive 无签名真机 App，将真正的 `Payload/SoraWeather.app` 打包为 `SoraWeather-unsigned.ipa`。
5. 下载 artifact。**未签名 IPA 不能直接安装**；需要有效签名或你已有的重签流程。

### 生成已签名 IPA

在 GitHub 建立环境 `ios-signing`，添加以下 Environment secrets（不要提交到源码）：

| Secret | 内容 |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | 含私钥的 Apple Development / Distribution `.p12` 文件的 Base64 |
| `IOS_CERTIFICATE_PASSWORD` | 该 p12 的密码 |
| `IOS_PROVISION_PROFILE_BASE64` | 与 Bundle ID、Team 和导出方式匹配的 `.mobileprovision` Base64 |
| `IOS_TEAM_ID` | Apple Developer Team ID |

可选 Environment variable `IOS_BUNDLE_ID`，默认 `app.sora.weather`。需与明确 App ID 的描述文件一致，不支持 wildcard profile。

Run workflow：勾选 `signed`，选择 `method`：

| method | 所需签名材料与用途 |
|---|---|
| `release-testing` | Apple Distribution + Ad Hoc profile；设备 UDID 必须在 profile 中 |
| `debugging` | Apple Development + development profile；注册设备调试 |
| `app-store-connect` | Apple Distribution + App Store profile；导出包，**不会自动上传 TestFlight/App Store** |

脚本检查 Team、Bundle ID、profile 有效期与类型；创建临时 keychain，archive / export 后清理证书和描述文件。建议给 `ios-signing` 设置保护规则，避免在不可信提交上使用私钥。Actions 的证书签名路径尚未在本次环境实际运行；如果 profile 权限与证书不匹配，构建会失败。

macOS runner 镜像会调整；`scripts/select_xcode.sh` 会列出所选 Xcode 和 SDK。runner 不再提供 26 时，需要更新 runner 标签/工具链配置。

## 降雨通知到底能做什么

- 默认：下一 24 小时内，预报时段概率 ≥50% 或降水量 ≥0.5 mm，约时段开始前 30 分钟安排**普通**本地通知。
- 可选 API：未来 60 分钟预报强度 ≥0.5 mm/h，约起雨预测前 10 分钟安排通知；临近时至少 5 秒后触发。近期实测已下雨则不再发“开始下雨”通知。
- 关闭提醒、切换城市、干燥新预报、失效数据会撤销旧预约；正常更新替换预约。单次只保留一个降雨预约；已投递/已过预约时间使用一小时冷却，防止重复。
- App 活跃时每 10 分钟尝试更新；前台手动刷新有节流；天气源 5 分钟内复用内存缓存。后台 `BGAppRefreshTask` 请求最早 30 分钟后运行，**不是固定轮询周期**。iOS 可以延迟或完全不运行。
- 无后台常驻、远程 APNs 服务或实时监测通道。强制结束、低电量、离线、专注模式都会影响通知；预约后天气变化也可能导致误报。已通知内容不能预测性保证。
- 防灾信息不触发通知。保持 iPhone 系统紧急警报开启，查阅气象厅和当地政府信息。

## 文件结构

- `App/`：SwiftUI 界面、Core Location、网络与缓存、UserNotifications、后台任务。
- `Core/`：模型、日本时区、Yahoo/JMA 解析、纯函数提醒策略。
- `Tests/`：41 个 XCTest，真实页面精简表格 / JMA JSON，合成 Yahoo 降雨契约样本。
- `Resources/`：定位用途说明、中日文权限本地化、Privacy manifest、App icon。
- `scripts/`：结构验证、Xcode 选择、模拟器启动、未签名打包与手动签名导出。
- `docs/VALIDATION.md`：实际验证证据与真机验收清单。
- `docs/DATA_SOURCES.md`：数据字段、公开接口限制与来源链接。

## 隐私与数据使用

本项目无广告、分析 SDK 或用户账号。URLSession 使用临时会话，不保存 Yahoo Cookie；不执行抓到的 HTML。定位只用于本地选择预报区；可选降雨 API 将所选预报区坐标与 Client ID 发送给 Yahoo。所有请求仍会让数据提供方看到网络 IP 等通常的请求信息。

天气缓存为本地 JSON，包含地区、预报与时间。语言、所选城市、提醒开关、可选 Client ID 和去重时间保存在本机 UserDefaults。Client ID 是应用标识，不是账号密码，分发前应评估其使用限制。无自建服务器、无上传 GPS 历史。

Yahoo 公开 HTML 不构成稳定的开发者 API，也不表示取得再分发许可。本代码是个人读取实现，**未取得 Yahoo/Weather Map 数据再分发授权**。公开发行前应解决适用的数据授权；不能将此工程自称官方 Yahoo/JMA App。JMA 来源经过整理，依其公开条款标注出处；没有修改源数据来发布独立预测。
