import SwiftUI
import HexPickCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showClear = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section("外观") {
                Picker("主题", selection: $store.theme) {
                    Text("深色").tag("dark"); Text("浅色").tag("light"); Text("跟随系统").tag("system")
                }
            }
            Section("数据") {
                if let data = store.dataset {
                    LabeledContent("版本", value: "\(data.manifest.patch) · seq \(data.manifest.seq)")
                    LabeledContent("规则", value: data.manifest.modeLabel ?? data.manifest.mode)
                    LabeledContent("统计截至", value: data.manifest.snapshotAt)
                    if let start = data.meta.window?.start { LabeledContent("样本起始", value: start) }
                    if let end = data.meta.window?.endExclusive { LabeledContent("样本截止（不含）", value: end) }
                    if !data.bands.isEmpty { BandPicker() }
                }
                Text(store.status).font(.footnote).foregroundStyle(Theme.secondary)
                if let error = store.error { Text(error).font(.footnote).foregroundStyle(Theme.gold) }
                Button { Task { await store.update() } } label: {
                    HStack { Text("手动检查更新"); Spacer(); if store.updating { ProgressView() } }
                }.disabled(store.updating)
                Button("清除下载缓存", role: .destructive) { showClear = true }.disabled(store.updating)
                Text("清理后恢复内置真实快照，收藏和最近查看保留。数据随来源仓库更新，并非游戏补丁发布即刻更新。")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
            Section("关于") {
                NavigationLink("关于 HexPick") { AboutView() }
                NavigationLink("推荐算法与统计口径") { AlgorithmView() }
                NavigationLink("数据来源与授权") { LicenseView() }
                NavigationLink("隐私说明") { PrivacyView() }
            }
        }.hexBackground().navigationTitle("设置")
            .confirmationDialog("清除下载缓存？", isPresented: $showClear, titleVisibility: .visible) {
                Button("清除并恢复内置数据", role: .destructive) { Task { await store.clearCache() } }
            }
    }
}
struct AlgorithmView: View {
    var body: some View {
        List {
            Section("比较的是当前英雄") {
                Text("每个候选只使用当前英雄与该海克斯的组合胜场和样本数。当前英雄胜率作为先验，不使用所有英雄的平均胜率替代。")
            }
            Section("贝叶斯平滑") {
                Text("平滑胜率 =（组合胜场 + 英雄胜率 × 300）÷（组合样本数 + 300）。")
                Text("在 Beta 后验下计算标准差，保守评分 = 平滑胜率 − 1.645 × 后验标准差，下限为 0。按保守评分降序排列。该分数是排序启发式，不是精确置信区间或必胜概率。")
                Text("样本数小于 3000，或来源标记 low_sample 时，显示样本风险。缺少数据或零样本时不显示胜率、不参与评分。")
            }
            Section("统计适配度") {
                Text("页面显示平滑胜率相对英雄基准的百分点差。它反映样本中的关联，可能受玩家选择、搭配、存活时间与结算替换等因素影响，不能解释为因果提升。")
                Text(statisticalNotice)
            }
        }.navigationTitle("推荐算法")
    }
}
struct AboutView: View {
    var body: some View {
        List {
            Section { Text("HexPick").font(.largeTitle.bold()); Text("海克斯大乱斗攻略助手 · \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")（\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")）\n免费、无广告、无需登录。") }
            Section { Text("HexPick 并非由 Riot Games 认可，不代表 Riot Games 或任何参与制作、管理英雄联盟的人员的观点。League of Legends 及相关素材归 Riot Games 所有")
                Text("本应用仅根据用户提供的名称或照片分析公开统计，不读取 PC 游戏内存，不提供跨设备游戏悬浮窗。") }
        }.navigationTitle("关于应用")
    }
}
struct LicenseView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section("数据署名") {
                Text("海克斯大乱斗统计数据（github.com/czgreat/aramhex-data），CC BY-NC 4.0。作者：czgreat。")
                Text("统计数据保留原始内容；HexPick 增加推荐排序、平滑评分与展示。禁止商业使用。")
                Link("查看数据仓库", destination: URL(string: "https://github.com/czgreat/aramhex-data")!)
                Link("CC BY-NC 4.0 完整许可", destination: URL(string: "https://creativecommons.org/licenses/by-nc/4.0/")!)
            }
            Section("图像与名称") {
                Text("英雄头像来自 CommunityDragon 镜像的 Riot Games 游戏资源，版权归 Riot Games 及相关权利人所有；不受统计数据 CC 许可覆盖。强化图标通过 CommunityDragon 的 cherry-augments.json 按 ID、名称及稀有度校验后按需下载。无法匹配时显示几何兜底符号。")
                Text("HexPick was created under Riot Games' “Legal Jibber Jabber” policy using assets owned by Riot Games. Riot Games does not endorse or sponsor this project.")
                Link("Riot 粉丝作品政策", destination: URL(string: "https://www.riotgames.com/en/legal")!)
                Text("本交付面向个人免费使用，未取得应用商店发布授权。公开上架前需另行核对 Riot 和当地发行商的许可要求。")
            }
            Section("来源统计说明") {
                ForEach(store.dataset?.meta.limitations ?? [], id: \.self) { Text($0) }
                ForEach(store.dataset?.meta.notes ?? [], id: \.self) { Text($0) }
            }
        }.navigationTitle("数据与授权")
    }
}
struct PrivacyView: View {
    var body: some View {
        List {
            Section("本机处理") {
                Text("无需 Riot、腾讯或 QQ 账号。不接入广告、用户追踪或商业分析 SDK。不采集设备标识、游戏登录信息。")
                Text("照片由 Apple Vision 在设备本地识别，不上传、不写入应用数据缓存，处理后不保留副本。相册使用系统照片选择器，仅访问你选中的图片。相机仅用于你主动发起的拍摄。")
                Text("收藏、最近查看与主题保存在本机。删除应用可移除这些记录。是否纳入系统备份由你的 iOS 设置决定。")
            }
            Section("网络连接") {
                Text("启动及手动更新时请求 GitHub 的公开统计数据。英雄头像随应用内置；查看强化时会连接 raw.communitydragon.org 下载映射及图标。强化与装备图标共用内存／磁盘缓存。图标有效期为 7 天，并按游戏版本与缓存格式版本隔离。网络服务器可能按其政策记录 IP 等连接信息，HexPick 不主动传输用户账号或追踪标识。")
                Text("只有点击授权说明中的链接才会打开外部网站，攻略、识别与推荐均在应用内完成。")
            }
        }.navigationTitle("隐私说明")
    }
}
