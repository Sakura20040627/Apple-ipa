# 验证记录与尚未验证部分

日期：2026-11-08 JST。

## 已实际执行

| 检查 | 结果 |
|---|---|
| Yahoo 大阪地区 HTML、住吉区 HTML、JMA 大阪预报、警报、地震列表下载 | 成功；仅作为当时的样本，不保证服务持续可用 |
| Swift 6.0.3 Linux 核心编译与 XCTest | 41 项通过，0 失败；命令见下 |
| Swift 编译器对所有 App/Core 文件的语法解析 | 通过；不等价于 Apple SDK 类型检查 |
| Xcode pbxproj 的 OpenStep 结构与引用检查 | 44 对象、引用解析通过 |
| plist / scheme XML / fixture JSON / Python AST / bash 语法 | 通过 |

运行记录：`docs/swift-tests.log`、`docs/structure-checks.log`。Linux 运行时依赖为临时下载的官方 Swift 6.0.3 工具链；未随项目打包。为避免本运行容器中并发驱动异常，实际采用单任务无 batch 编译；最终因本容器的 SwiftPM 进程监控偶发异常，直接执行已编译的 XCTest 二进制完成全部 41 项（退出码 0）：

```bash
swift test --jobs 1 -Xswiftc -disable-batch-mode
./.build/x86_64-unknown-linux-gnu/debug/SoraWeatherCorePackageTests.xctest
swiftc -frontend -parse App/*.swift Core/*.swift
python3 scripts/validate_project.py
```

41 项覆盖包括：真实表格数值、3 小时间隔、日/时段概率区别、列结构变化拒绝、JSON 缺失值、地区代码、JST 跨年、温度预报时刻、10 日空缺、缓存 round-trip、警报解除、地震版本去重、拒绝权限/关闭开关、过期/未来数据、降雨阈值、起雨提前量、已下雨抑制、冷却、乱序样本与时段提醒。

## 未实际执行（不能报告通过）

- macOS Xcode / iOS 26 SDK 的原生 App 类型检查、编译、链接和资产编译。
- GitHub Actions 远程运行、模拟器启动或 UI 截图验收。
- UserNotifications 的真实系统权限弹窗、投递、专注模式和系统设置变更。
- Core Location 在真实 iPhone 上的权限/精度行为。
- BGAppRefresh 在暂停、强制退出、省电模式下的调度。
- 真实 Yahoo Client ID 的降雨 API 调用。
- Apple 证书、provisioning profile、codesign、archive/export 与 IPA 安装。
- 六城市中大阪以外的真实响应逐项验收。

## CI 会执行

结构检查 → 核心 XCTest → iOS 26 模拟器编译、安装、启动（仅 smoke test）→ 真机无签名 Archive → 验证 Payload 路径 → 上传 IPA。

可选签名 Job 仅 workflow_dispatch 启动，在依赖检查 Job 成功后使用 `ios-signing` 环境证书，检查 profile/Team/Bundle ID/有效期，再进行 archive/export/codesign verify。**提供流程不等于该流程已成功运行**。

## iPhone / Mac 验收步骤

| 操作 | 应观察到的结果 |
|---|---|
| 初次打开、不允许定位 | 默认大阪可查看；设置可选城市，不强迫登录 |
| 大阪允许近似定位 | 选择附近大阪预报区，提示地区预报范围 |
| 在六城市覆盖之外定位 | 明确“当前位置尚未覆盖”，不把大阪冒充当前位置 |
| 切换中文/日文 | 所有应用导航、说明、按钮、提醒文本切换；官方防灾原文保留日文 |
| 下拉刷新 | 显示进度；高频刷新受节流，时间不伪造更新 |
| Yahoo 失败 | 尝试 JMA，并显示备用来源；JMA 也失败时显示缓存和原发布时间或无数据 |
| 真正逐小时/第 9–10 日 | 明确说明来源未提供；不得出现推算填补值 |
| 首次拒绝通知 | 无预约；权限状态为未允许，可跳系统设置 |
| 允许通知，开启提醒 | 有有效湿时段才预约，内容说明是普通天气预报 |
| 关闭提醒/换城市 | 清除旧雨提醒；不会投递旧城市的新预约 |
| 新预报转干燥 | 撤销原雨预约 |
| 前台收到普通通知 | 以普通 banner / sound / list 展示，无 critical interruption |
| 离线/强制退出/省电 | 不承诺更新；已预约提醒可能仍投递，但不保证准时或正确 |
| 打开防灾页 | 展示发布/获取时间、府县汇总与全国地震；不自动发紧急通知 |
| 大字号/减少透明度 | 卡片可滚动；减少透明度时使用不透明背景；需真机视觉核对 |
| 签名 IPA 安装 | 证书和 profile 有效且设备在允许范围后才能安装；未签名 IPA 不可直接安装 |

当前项目以**工程源代码交付 + 已通过的核心测试**为验收范围，不能视为实时防灾服务。
