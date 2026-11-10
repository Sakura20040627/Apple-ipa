import SwiftUI
import HexPickGuides

struct DataSourcesView: View {
    @Environment(GuideStore.self) private var guides
    var body: some View {
        List {
            Section("Mayhempedia · 构筑攻略") {
                Text("Copyright (c) 2026 Mayhempedia · MIT License")
                Link("项目与署名说明", destination: URL(string: "https://github.com/boxsbraindump/Mayhempedia")!)
                Link("MIT 原始许可", destination: GuideSource.mayhempedia.licenseURL)
                Text("部分内容引自第三方，版本和时效需核对。第三方原站的内容不因仓库采用 MIT 就自动变为 MIT；逐条保留上游引用来源。攻略不是官方权威数据。")
                Text("HexPick 修改：转换统一字段、增加中文展示标签、图标映射和占位；不改变上游出装顺序。")
                if let data = guides.library?.context.mayMetadata {
                    Text("资料目录：\(data.patch)\n仓库更新：\(data.updatedAt)\n快照：\(data.retrievedAt)\n修订：\(data.revision)").font(.caption)
                }
                DisclosureGroup("MIT 许可全文（保留原版权声明）") {
                    Text(GuideLicenses.mayhempedia).font(.caption).textSelection(.enabled)
                }
            }
            Section("ARAMMayhem · 组合与装备目录") {
                Text("Data: arammayhem.com · CC BY 4.0")
                Link("数据与署名说明", destination: URL(string: "https://arammayhem.com/data/")!)
                Link("Creative Commons Attribution 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                Text("作者署名采用原站要求的 Data: arammayhem.com。公开导出包含组合与编辑标签、装备目录；不包含强化胜率或完整中文玩法长文。")
                Text("HexPick 修改：字段转换、标签中文化及与 CommunityDragon 装备 ID 交叉核对；不新增胜率或推断未提供的玩法机制。")
                if let data = guides.library?.context.aramMetadata {
                    Text("数据版本：\(data.patch)\n发布更新：\(data.updatedAt)\n快照：\(data.retrievedAt)\n修订：\(data.revision)").font(.caption)
                }
            }
            Section("aramhex-data · 统计与原推荐算法") {
                Text("海克斯大乱斗统计数据（github.com/czgreat/aramhex-data）\n作者：czgreat · CC BY-NC 4.0")
                Link("统计数据仓库", destination: URL(string: "https://github.com/czgreat/aramhex-data")!)
                Link("CC BY-NC 4.0 协议", destination: URL(string: "https://creativecommons.org/licenses/by-nc/4.0/")!)
                Text("统计数据保留原始内容；HexPick 增加展示、平滑评分与推荐排序。禁止商业使用。本次构筑模块不修改统计数据、更新器或 RecommendationEngine。")
            }
            Section("游戏图像与名称") {
                Text("图标、装备说明、英雄与强化名称来自 CommunityDragon 镜像中的 Riot Games 游戏资源，归 Riot Games 及相关权利人所有，不受上述数据集的 CC 或代码 MIT 许可覆盖。图片按需下载，未作为攻略图片内置。")
                Text("HexPick 并非由 Riot Games 认可，不代表 Riot Games 或任何参与制作、管理英雄联盟的人员的观点。League of Legends 及相关素材归 Riot Games 所有")
                Link("CommunityDragon", destination: URL(string: "https://www.communitydragon.org/")!)
                Link("Riot 粉丝作品政策", destination: URL(string: "https://www.riotgames.com/en/legal")!)
            }
            Section("功能参考，不接入内容") {
                Text("AstrBot 海克斯插件仅参考特殊联动／避坑提示的交互思路。未导入插件代码、Apexlol 数据、攻略原文或接口；其 Adapter 在生产环境明确禁用。")
                Link("参考项目", destination: URL(string: "https://github.com/orange-guang/astrbot_plugin_hextech")!)
            }
        }.hexBackground().navigationTitle("数据来源与版权")
    }
}
