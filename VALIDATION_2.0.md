# 櫻卡 2.0 驗證記錄

日期：2026-11-03（日本時間）

- iPhone ARM64 Release archive：Xcode 26.6，成功。App source commit: `6cd34b67389c7e264198ad3a5ff38c91fe02a293`。
- 未簽名 IPA 已下載，ZIP CRC 完整性、平台、ARM64 Mach-O、版本 2.0、顯示名稱「櫻卡」、繁中資源及定位用途說明均已核對。
- IPA SHA-256：`c5004aa15c456d8e5bdfed0109af974cf408f19d291d2ad59fc5ad33e0fa2016`。
- 核心原生 Swift 檢查：8 組全部通過；檢查與正式 App 共用 Models / Catalog / Appearance / Store 原始碼。執行記錄：https://github.com/Sakura20040627/Apple-ipa/actions/runs/41651475571

通過項目：12 卡／64 店目錄唯一性；Prime 條件；PayPay 資格及端數；活動上限／過期／不疊加；繁中／英文別名；收藏排序穩定性；JSON 往返與 v1 相容；非法座標／重複 ID／非法計算單位拒絕。

限制：雲端 iOS 模擬器停留在系統 Data Migration，未取得 App 運行截圖，也未完成 iOS XCTest 或真機測試。附近搜尋、定位權限、地圖與實際 UI 操作仍需裝置驗證。不得將編譯成功描述成所有真機功能均已驗證。
