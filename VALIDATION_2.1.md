# 櫻卡 2.1 驗證

核對日期：2026-11-04（日本時間）。

- 雲端環境：GitHub Actions macOS 26 Intel，Xcode 26.6。
- App 來源 commit：a648a0dc296172f3aab5ec19e962c8abac15c9a7。
- [完整構建與核心測試](https://github.com/Sakura20040627/Apple-ipa/actions/runs/41677366052)：成功。
- Device Archive：ARCHIVE SUCCEEDED。
- 11 組原生 Swift 核心回歸測試全部通過：兩卡／64 店資料、Prime、PayPay 資格與取整、活動期限與上限、Apple Pay／菸品／排除分店／儲值、東京時區 Step 邊界、雙語搜尋、收藏置頂、備份相容、無效匯入攔截、舊卡片資料遷移。
- IPA ZIP CRC 驗證通過；顯示名稱櫻卡；版本 2.1（3）；最低 iOS 26.0；ARM64；Assets.car 存在；無 _CodeSignature。
- IPA：3,067,083 bytes。
- SHA-256：a6e5acba692059116dc8cff6c3b9023eb51c488adf3a152512597e9bf415f501。

限制：本次未進行真機或模擬器 UI 執行驗證。附近店鋪仍有 MapKit 舊介面的棄用警告，但未造成編譯失敗。部分官方 favicon 解析度偏低。未簽名 IPA 須自行簽名後安裝。
