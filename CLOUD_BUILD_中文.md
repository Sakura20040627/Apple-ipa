# 无需自有 Mac 的 GitHub Actions 云端构建

本目录可直接作为独立 GitHub 仓库根目录。包含隐藏目录 `.github`，上传时不可遗漏。

1. 创建名为 `paycompass-ios` 的专用仓库（建议 Private），启用 Actions。
2. 将本目录全部内容放入 main 分支；push 或 Actions → Build Pay Compass IPA → Run workflow 会启动构建。
3. 云端使用 macos-26 自带 Xcode，输出工具链版本、完整构建日志以及 `PayCompass-unsigned.ipa`。
4. 在该次运行底部 Artifacts 下载 `PayCompass-iOS-device`。

当前仅已准备配置，**尚未触发云端构建，不能声称编译成功**。首次构建出现任何 Swift 或工程错误后，应读取构建日志修正并重新运行。使用账户现有 Actions 额度，不应为此开启付费 runner 或增加预算。

## 签名 IPA（可选）

未签名 IPA 不能直接安装到普通 iPhone。云端签名需要有效 Apple 证书、对应私钥及匹配的 provisioning profile。请在 GitHub 仓库 Settings → Secrets and variables → Actions 中自行设置，不要在聊天或源码里粘贴私钥与密码。

- `IOS_P12_BASE64`：证书和私钥的 .p12 文件 Base64
- `IOS_P12_PASSWORD`：P12 导出密码，可为空
- `IOS_PROFILE_BASE64`：mobileprovision 文件 Base64
- `IOS_TEAM_ID`：Apple Team ID
- `IOS_BUNDLE_ID`：与 profile 匹配的唯一 Bundle ID
- `IOS_EXPORT_METHOD`：默认 release-testing（Ad Hoc），也可 debugging / app-store-connect，必须与证书及 profile 类型匹配

全部必要字段存在时会额外构建并导出签名版本到 artifact 的 signed 目录。Ad Hoc profile 需要包含目标手机的 UDID；App Store Connect 分发应通过对应上传流程与 TestFlight 安装。临时证书和 keychain 在任务结束时删除。日志不打印秘密内容。

源代码保持原生 iOS，构建实际发生在 GitHub 的 macOS 云端机器上，当前 Linux 容器不伪装执行 Xcode。
