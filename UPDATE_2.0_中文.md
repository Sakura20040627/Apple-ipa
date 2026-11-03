# 櫻卡 2.0

改名：櫻卡 / Sakura Card。沿用 Bundle ID com.example.paycompass，便於使用相同簽名及識別碼覆蓋更新；若重簽時變更識別碼，系統會視為另一個 App。圖示使用本次使用者提供的原圖，只調整輸出尺寸。

新增：八款主題與深淺色設定；日文及繁體中文（跟隨系統或手動切換）；12 張日本信用卡；64 個商戶獨立文字識別徽章；店鋪名稱、英文、繁中別名、分類搜尋；卡片搜尋；店鋪收藏預設置頂；附近實際店鋪搜尋、直線距離、地址、地圖、步行導航及分店收藏。

附近資料：使用 MapKit 即時查詢 Apple 地圖，首次點擊搜尋時請求使用中定位，約 3 公里內、依查詢回傳結果，不是完整商戶清單。定位拒絕、無網路或無結果均有提示；不依賴自建後端，也不持續追蹤。收藏分店座標會隨 JSON 備份匯出。

圖示：店鋪採獨立製作的品牌文字縮寫與識別色，並非擷取原 App 的官方商標圖檔。卡片卡面為自製漸層識別圖，不儲存信用卡敏感資訊。

卡片新增：三井住友 NL / Gold NL、イオン、エポス、リクルート、dカード、au PAY Card、Orico THE POINT。補充發卡機構、積分名稱、國際組織、年費說明、日文和繁中條件及來源連結。以一般購物基本率估算；年度獎勵、指定感應支付、免年費條件及部分特殊商戶不會盲目加計。dカード 須留意 2027 年 1 月制度調整。

升級：首次啟動一次性合併新版目錄，保留原卡片 ID、持有狀態、費率、活動、備註及使用者編輯。v1 JSON 匯入仍可解碼，新增欄位為可選；匯入按原有流程取代資料。主題和語言屬裝置設定，不放入 JSON 備份。

官方資料核對：2026-11-03。
- https://www.smbc-card.com/nyukai/card/numberless.jsp
- https://www.smbc-card.com/mem/update/pop/hikaku_proper.jsp
- https://www.aeon.co.jp/point/
- https://faq.eposcard.co.jp/faq/show/63
- https://recruit-card.jp/point/
- https://dcard.docomo.ne.jp/st/dpoint_points/shopping/index.html
- https://www.kddi-fs.com/merit/point/
- https://www.orico.co.jp/creditcard/list/thepoint/

雲端編譯、測試和模擬器截圖由 .github/workflows/ios-build.yml 執行；最新版執行紀錄與實際 IPA 以 GitHub Actions 的輸出為準。未簽名 IPA 需要簽名後才能安裝，模擬器驗證不代表已經過真機完整測試。
