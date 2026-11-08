# 数据契约与来源

核对与样本获取：2026-11-08（JST）。公开数据访问成功不等于持续可用性或再分发许可。

| 用途 | URL / 契约 | 降级方式 |
|---|---|---|
| Yahoo 大阪日预报 | https://weather.yahoo.co.jp/weather/jp/27/6200.html · `forecastCity` 两日 + `yjw_week` 周预报 | 结构不符、非 200、过期则切换 JMA |
| Yahoo 大阪住吉区 | https://weather.yahoo.co.jp/weather/jp/27/6200/27120.html · 两日 3 小时温度/降水量 | 失败仍保留日预报和 6 小时概率 |
| Yahoo 短时降雨 | https://map.yahooapis.jp/weather/V1/place · `Feature[].Property.WeatherList.Weather[]` | 无 Client ID 或 API 失败时使用普通时段提醒 |
| JMA 大阪 | https://www.jma.go.jp/bosai/forecast/data/forecast/270000.json | 失败显示明确的旧缓存 / 无可用天气 |
| JMA 警报 | https://www.jma.go.jp/bosai/warning/data/warning/270000.json | 失败显示未取得，不推断安全 |
| JMA 地震列表 | https://www.jma.go.jp/bosai/quake/data/list.json | 失败显示未取得；近期全国列表，不是预测 |

Yahoo 地区 HTML 为非正式可变契约。只提取预报表格，校验列数、行标签与时间；页面调整时应更新解析器和真实样本。HTTP 访问不会绕过登录墙、验证码或限流；遇到错误退回 JMA。不携带用户 Yahoo Cookie。

Yahoo 气象 API 文档：https://developer.yahoo.co.jp/webapi/map/openlocalplatform/v1/weather.html

- `appid` 是必需的开发者 Client ID，不要求 App 用户登录 Yahoo。
- 坐标参数顺序为经度、纬度。
- Rainfall 单位为 mm/h，是降水**强度**，不是降水概率。
- observation / forecast 分开处理；仅预测未来时间可以触发起雨提醒。
- 官方文档描述约未来 60 分钟，不提供完整逐小时/7 日天气。
- 本次没有开发者 Client ID，未执行真实雨 API 请求；其 JSON 解析以合成契约样本验收。

JMA 的网页 JSON 供网站使用，不是本项目可承诺 SLA 的实时 API。预报按 `timeDefines[i]` 对齐字段；按目标地区和气温站 code 精确匹配；空字符串保留为 nil。00:00 / 09:00 温度字段分别作为最低 / 最高预报，**不是当前温度**。常用天气代码有说明，未识别代码明确显示代码，不自动冒充晴天。

JMA 警报只显示所选府县汇总，未解析逐街道避难信息。解除不算有效警报；“当前响应无有效警报”不表示当前安全。报告时间可能较早（例如警报长期未更新），界面同时显示获取和发布两个时间，不将旧发布时间改成新发布时间。

JMA 地震按 `eid` 去重，保留较新 `rdt` 的版本；使用 `anm`, `mag`, `maxi`, `at`。展示“全国最大震度”，不称为大阪当地震度。不会从最大震度推断用户当前位置危险程度。列表同一事件的取消版本不会作为新的警报通知；此列表没有任何通知侧作用。

出处：气象厅主页，数据经 Sora Weather 整理。官方使用条款：https://www.jma.go.jp/jma/kishou/info/coment.html

官方开发者信息：https://www.data.jma.go.jp/developer/

Apple：
- Liquid Glass: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- Background strategies: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
- Notifications authorization: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- Signing/distribution: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases

GitHub runner 镜像：https://github.com/actions/runner-images
