# Pay Compass — 原生 iOS 支付比较工具

完整 SwiftUI 源码工程；最低 iOS 26，使用 Xcode 26 或更新版本，无第三方包。界面为日语，面向日本消费场景。没有复制「ペイえらび」的代码、数据库、图标或设计。

## 打开与运行
1. 解压，双击 `PayCompass.xcodeproj`，选择 PayCompass scheme。
2. 模拟器：选择已安装的 iOS 26 模拟器，⌘R。
3. 真机：Xcode Settings → Accounts 添加 Apple ID。Target → Signing & Capabilities 选择自己的 Team，将 `com.example.paycompass` 改成唯一 Bundle ID。测试 target 同样更改 ID 和 Team。
4. 连接 iPhone，启用开发者模式，选择设备后运行。免费 Personal Team 适合开发测试，有安装与有效期限制。

## 签名与导出 IPA
需要 Mac、Xcode 26、Apple 签名证书和相应 provisioning profile。本次运行环境是 Linux，没有 xcodebuild / Swift，**未实际编译、未运行 XCTest、未验证签名、没有 IPA**。工程仍须在 Xcode 中执行以下验证。

选择 Any iOS Device (arm64) → Product → Archive → Organizer → Distribute App。按账户资格选择 TestFlight/App Store Connect、Ad Hoc 或 Development，并在支持导出时导出 IPA。Ad Hoc 要把目标设备 UDID 加入 profile；IPA 无法绕过签名直接安装。

命令行模拟器构建（设备名称以 `xcrun simctl list devices available` 为准）：
```sh
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -destination 'platform=iOS Simulator,name=iPhone 17' test
```
签名归档：
```sh
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -configuration Release -destination 'generic/platform=iOS' -archivePath build/PayCompass.xcarchive DEVELOPMENT_TEAM=YOURTEAM -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PayCompass.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export
```
ExportOptions.plist 由自己的分发方式和 Team 决定，可先从 Organizer 成功导出时获取；不提供无效的伪造签名文件。已附原创基础图标；App Store 提交前仍需审核品牌、隐私政策和 App Store 元数据；开发运行不依赖这些素材。

## 已实现
- 所有卡片本地增删改、所有权切换；优先内置 PayPay Card / Amazon Mastercard，另含楽天卡和 JCB CARD W。可自建其他日本信用卡。
- 16 个日本常见商户，店名/分类搜索、编辑和删除。
- 购买金额计算、按预计日元等值排序、同分提示、Prime 和 PayPay 资格开关。
- 活动增删改，指定卡片/商户、开始结束时间、额外返还率、剩余上限、手动启用。未核实的限时优惠不预填；提供官方活动入口。
- 原子 JSON 本地保存、完整备份导入导出、导入替换确认、格式/范围/重复 ID/外键验证、错误提示。删除卡片或商户同步删除关联活动。
- SwiftUI 原生 TabView / NavigationStack / Form / Sheet / 文件选择器；iOS 26 系统控件自然使用 Liquid Glass，底部状态胶囊使用真实 glassEffect API；支持系统深浅色及动态字体。

## 计算边界
通常返还：floor(floor(金额 / 计算单位) × 计算单位 × 返还率 / 100)。活动奖励：floor(金额 × 额外率 / 100)，再限制为手动设置的剩余上限。有效活动不叠加，取奖励最大的一项，再加入基础奖励。这里只比较已标记持有的卡片。

金额范围 0–1亿日元；负数非法。普通卡片按单笔估算，JCB 月合计规则会有差异。积分以最大日元等值估算，兑换用途可能改变价值。没有把各平台购物积分、商户积分、PayPay Step、Apple Pay 优惠、税金/充值/公共事业减率等复杂条件自动叠加。用户可通过活动录入已核实的额外率。活动已用额度不自动跟踪，须手动调整剩余上限。

PayPay 默认未确认资格，按 0 估算；完成应用注册与本人确认后手动开启。Amazon 通常店铺 1%，Amazon.co.jp 普通购买按 Prime 2% / 非 Prime 1.5% 估算；寄付和其他特殊交易不适用。

## 数据与权利
只使用官方公开说明中的少量事实（名称、基本比例）独立编写结构化规则，不抓取整站，不复制官方正文或卡面图。商户名单是独立手工整理的通用名称索引，不是加盟店可用性数据库。所有品牌名称仅用于识别，权利归各自所有者。公开可访问不等于可以任意复制素材；本工程没有附带这些素材。

核实日期：2026-11-03。官方来源：
- https://www.paypay-card.co.jp/service/000263.html
- https://www.paypay-card.co.jp/service/000028.html
- https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp
- https://www.rakuten-card.co.jp/point/
- https://www.jcb.co.jp/ordercard/kojin_card/os_card_w2.html
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views

源代码以 LICENSE 的 MIT 条款提供；第三方品牌、事实来源页面不属于本项目许可。没有服务器、账号登录、支付功能、遥测或第三方 SDK。JSON 备份可能包含用户备注，请自行管理。端内文件采用 completeFileProtection；系统备份是否包含该文件由设备设置决定。

## 验收建议
⌘U 运行计算与导入校验测试，再检查：商户搜索；卡片开关；Amazon Prime 切换；PayPay 399円端数；活动过期与上限；JSON导出→修改→导入→重启；深浅色、大字体、横屏和小屏幕。当前仅做静态工程检查，不能代替 Xcode 编译或真机测试。
