import SwiftUI

private struct VerifiedOffer: Identifiable {
    var id: String { ja }
    let ja: String
    let zh: String
    let detailJA: String
    let detailZH: String
    let url: String
}
struct VerifiedOffersView: View {
    let kind: String
    private var offers: [VerifiedOffer] {
        if kind == "amazon" {
            return [
                .init(ja: "Amazon.co.jp：2% / 1.5%", zh: "Amazon.co.jp：2%／1.5%", detailJA: "Prime会員2%、非会員1.5%。Prime Student・無料体験は対象。Amazon Payは通常1%。", detailZH: "Prime 會員 2%、非會員 1.5%；包含 Prime Student 與免費試用。Amazon Pay 屬一般 1%。", url: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp"),
                .init(ja: "対象コンビニ：1.5%", zh: "指定便利商店：1.5%", detailJA: "セブン‐イレブン・ファミリーマート・ローソン。月間対象利用を合算し200円単位。一部施設内店舗・ガソリンスタンド併設店・通販・配達・コード決済は対象外。", detailZH: "7-Eleven、FamilyMart、Lawson，每月合計以 200 日圓為單位。部分設施內與加油站分店、網購、外送及條碼支付不適用。", url: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp"),
                .init(ja: "7-Eleven：Apple Payで最大7%", zh: "7-Eleven：Apple Pay 最高 7%", detailJA: "Apple PayのMastercardタッチのみ：通常1.5%＋5.5%。現物カードのタッチ・iD・Google Payは追加対象外。たばこは追加5.5%対象外。200円ごとに計算。", detailZH: "僅限 Apple Pay Mastercard 感應：基本 1.5%＋加碼 5.5%。實體卡感應、iD、Google Pay 不適用加碼；菸品亦不適用額外 5.5%。每 200 日圓計算。", url: "https://www.smbc-card.com/mem/cardinfo/25/cardinfo4010980.jsp"),
                .init(ja: "ふるさと納税・対象外利用", zh: "故鄉納稅與不計點項目", detailJA: "Amazonふるさと納税は2025年10月1日以降、Primeを問わず1%。Suica・PASMO・ICOCA・Edy・WAON・nanaco等のチャージ、年会費・手数料・キャッシング・国民年金等は対象外。", detailZH: "Amazon 故鄉納稅自 2025/10/1 起，不論 Prime 均為 1%。Suica、PASMO、ICOCA、Edy、WAON、nanaco 等儲值，以及年費、手續費、預借現金、國民年金等不計點。", url: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp"),
                .init(ja: "新規入会・指定会員向け", zh: "新戶與指定會員優惠", detailJA: "ログイン後のAmazon公式ページで対象・金額・エントリー期限を確認。全員共通の固定入会ポイントは本アプリに登録していません。", detailZH: "請登入 Amazon 官方頁確認對象、額度及登錄期限；本 App 不假設所有人享有固定的新戶點數。", url: "https://www.smbc-card.com/nyukai/affiliate/amazon/index.jsp")
            ]
        }
        return [
            .init(ja: "通常1%・PayPayステップ最大1.5%", zh: "基本 1%・PayPay Step 最高 1.5%", detailJA: "クレジット設定と本人確認が必要。前月に200円以上の支払い30回かつ合計10万円で+0.5%。翌月2日〜翌々月1日に適用。アプリで資格を確認して設定してください。", detailZH: "須完成信用支付設定及身分驗證。前月每筆至少 200 日圓共 30 筆，且合計至少 10 萬日圓，可加 0.5%；適用下月 2 日至再下月 1 日。請先在 PayPay 確認資格再啟用。", url: "https://paypay.ne.jp/event/paypaystep/"),
            .init(ja: "公共料金・税金：0.5〜1%", zh: "公共費用／稅金：0.5～1%", detailJA: "指定の電気・ガス・水道・税金は基本0.5%、Step適用時は+0.5%。他社決済・交通系IC等チャージは対象外。", detailZH: "指定水電瓦斯及稅金基本 0.5%，Step 當期可加 0.5%。其他支付工具及交通 IC 等儲值不計點。", url: "https://www.paypay-card.co.jp/service/subscription/"),
            .init(ja: "開催予定：Yahoo!ショッピング500円OFF", zh: "即將開始：Yahoo! Shopping 折 500 日圓", detailJA: "2026/11/6〜11/19。3,480円以上、先着4万回、1人1回。クーポン表示・クレジット登録等の条件あり。一部店舗対象外。", detailZH: "2026/11/6～11/19，滿 3,480 日圓，限前 4 萬次、每人一次。須可見優惠券並完成信用支付登錄等條件，部分店鋪不適用。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "抽選：公共料金の支払い", zh: "抽獎：公共費用付款", detailJA: "2026/9/1〜終了日未定。対象の1回2,000円以上で毎月50名に4万pt・1,000名に1,000pt。PayPayクレジット利用は対象外。固定還元として計上しません。", detailZH: "2026/9/1 起，結束日未定。指定單筆滿 2,000 日圓，每月抽 50 名各 4 萬點、1,000 名各 1,000 點。PayPay 信用支付不適用，不列入固定回饋。", url: "https://www.paypay-card.co.jp/event/utility-bills-2609/index.html"),
            .init(ja: "抽選：ETC利用", zh: "抽獎：ETC 消費", detailJA: "2026/10/1〜終了日未定。月1,000円以上で50名に2万pt・1,000名に1,000pt、抽選は2カ月後。通常カードのETC年会費は1枚550円。", detailZH: "2026/10/1 起，結束日未定。每月滿 1,000 日圓，抽 50 名各 2 萬點、1,000 名各 1,000 點，兩個月後抽獎。普通卡 ETC 每張年費 550 日圓。", url: "https://www.paypay-card.co.jp/event/etc-card_2610/index.html"),
            .init(ja: "海外利用スクラッチ", zh: "海外消費刮刮樂", detailJA: "2026/3/31〜終了日未定。対象200円以上の海外利用、本人確認・クレジット設定が必要。スクラッチ期限60日。抽選結果により付与、固定率ではありません。", detailZH: "2026/3/31 起，結束日未定。指定海外消費滿 200 日圓，須身分驗證及信用支付設定，刮獎期限 60 日。依抽獎結果給點，並非固定回饋率。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "対象者限定：街・オンラインのクーポン", zh: "指定會員：實體／線上優惠券", detailJA: "2026/9/14〜終了日未定。アプリに表示された方のみ。取得・店舗・期間・上限を個別確認。PayPayクレジット指定で、現物カード払いとは異なります。", detailZH: "2026/9/14 起，結束日未定；限 App 顯示者。須逐一確認領取、店鋪、期限與上限，指定 PayPay 信用支付，與實體卡付款不同。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "Yahoo!ショッピング：毎日最大5%", zh: "Yahoo! Shopping：每日最高 5%", detailJA: "Yahoo! JAPAN IDとLINE連携等が条件。ストア分等を含む表示のため、カード基本分と二重加算しません。対象商品・上限・限定ポイントを確認。", detailZH: "須符合 Yahoo! JAPAN ID 與 LINE 連結等條件。最高值包含店鋪等回饋，不能再與卡片基本回饋重複相加；另有商品、上限及限定點數條件。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "Yahoo!オークション：指定日のクーポン", zh: "Yahoo! 拍賣：指定日期優惠券", detailJA: "2026/11/7〜8・11/21〜23は2万円以上で1,000円OFFの対象案内。会員・取得条件あり。11/28〜29はこのクーポンなし。", detailZH: "2026/11/7～8、11/21～23 公告滿 2 萬日圓折 1,000 日圓；有會員與領券條件。11/28～29 無此優惠券。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "対象経路限定：新規入会最大5,000pt", zh: "指定申辦管道：新戶最高 5,000 點", detailJA: "2025/11/20〜終了日未定。指定Yahoo!経由ページ等の対象者向け。通常3,000pt＋期間限定2,000ptの案内で、全員一律の入会特典ではありません。", detailZH: "2025/11/20 起，結束日未定；限指定 Yahoo! 管道等適用者。公告為一般 3,000 點＋限定 2,000 點，並非所有申請人一律享有。", url: "https://www.paypay-card.co.jp/event/"),
            .init(ja: "その他の対象者限定プログラム", zh: "其他指定會員方案", detailJA: "SoftBank・Y!mobile支払い設定、家族カード・2枚目、PayPayクエスト・証券積立は表示対象・達成条件が個別。リボ登録特典には手数料条件あり。通常カードにGold専用10%クーポンは適用しません。", detailZH: "SoftBank／Y!mobile 付款設定、家族卡、第二張卡、PayPay Quest 與證券定投均須個別確認。循環信用登錄禮涉及手續費條件；普通卡不適用 Gold 專屬 10% 優惠券。", url: "https://www.paypay-card.co.jp/event/")
        ]
    }
    var body: some View {
        List {
            Section { Text(L.t("公式公開情報 · 確認日2026/11/4（日本時間）。抽選・限定クーポンは自動加算しません。利用前にリンク先で条件を再確認。", "官方公開資訊 · 核對日 2026/11/4（日本時間）。抽獎與限定優惠券不自動加計，消費前請再核對原頁條件。")).font(.caption).foregroundStyle(.secondary) }
            ForEach(offers) { offer in Section { Text(L.isChinese ? offer.zh : offer.ja).font(.headline); Text(L.isChinese ? offer.detailZH : offer.detailJA).font(.subheadline); SafeLink(url: offer.url).font(.caption) } }
            if kind == "amazon" {
                Section(L.t("終了した活動", "已結束活動")) {
                    DisclosureGroup(L.t("過去のキャンペーン", "歷史活動")) {
                        Text(L.t("10万ポイント抽選（2026/6/16〜8/16）、7月登録の4,000円リボ特典（利用期限10/31）は新規参加期間が終了。2025年冬の活動も終了。今の固定回饋には含めません。", "10 萬點抽獎（2026/6/16～8/16）、7 月登錄的 4,000 日圓循環信用優惠（消費期限 10/31）均已結束新參加期限。2025 年冬季活動亦已結束，不計入目前回饋。"))
                        SafeLink(url: "https://www.smbc-card.com/mem/cardinfo/26/cardinfo7224677.jsp")
                        SafeLink(url: "https://www.smbc-card.com/nyukai/campaign/cardinfo3010676.jsp")
                    }
                }
            }
        }.navigationTitle(kind == "amazon" ? "Amazon Mastercard" : "PayPay Card").navigationBarTitleDisplayMode(.inline)
    }
}
