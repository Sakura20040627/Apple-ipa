import Foundation

enum Catalog {
    static let revision = 2
    static func enrich(_ db: inout Database) {
if let i = db.cards.firstIndex(where: { $0.name == "PayPay Card" }) {
            db.cards[i].issuer = "PayPayカード"; db.cards[i].pointsName = "PayPayポイント"; db.cards[i].brands = "Visa / Mastercard / JCB"; db.cards[i].color = "D34A57"
            db.cards[i].annualFee = "永年無料"; db.cards[i].annualFeeZH = "永久免年費"
            db.cards[i].noteZH = "需完成 PayPay App 登錄與身分驗證；一般消費以 200 日圓為單位，未計 PayPay Step 加碼。"; db.cards[i].details = db.cards[i].note; db.cards[i].detailsZH = "需完成 PayPay App 登錄與身分驗證；一般消費以 200 日圓為單位，未計 PayPay Step 加碼。"
        }
if let i = db.cards.firstIndex(where: { $0.name == "Amazon Mastercard" }) {
            db.cards[i].issuer = "三井住友カード"; db.cards[i].pointsName = "Amazonポイント"; db.cards[i].brands = "Mastercard"; db.cards[i].color = "3E4F65"
            db.cards[i].annualFee = "永年無料"; db.cards[i].annualFeeZH = "永久免年費"
            db.cards[i].noteZH = "一般店鋪 1%；Amazon 一般購物 Prime 2%、非 Prime 1.5%。便利商店等條件式加碼需另外確認。"; db.cards[i].details = db.cards[i].note; db.cards[i].detailsZH = "一般店鋪 1%；Amazon 一般購物 Prime 2%、非 Prime 1.5%。便利商店等條件式加碼需另外確認。"
        }
if let i = db.cards.firstIndex(where: { $0.name == "楽天カード" }) {
            db.cards[i].issuer = "楽天カード"; db.cards[i].pointsName = "楽天ポイント"; db.cards[i].brands = "Visa / Mastercard / JCB / American Express"; db.cards[i].color = "B74365"
            db.cards[i].annualFee = "永年無料"; db.cards[i].annualFeeZH = "永久免年費"
            db.cards[i].noteZH = "一般購物每 100 日圓 1 點；公共費用、稅金等部分交易回饋不同。"; db.cards[i].details = db.cards[i].note; db.cards[i].detailsZH = "一般購物每 100 日圓 1 點；公共費用、稅金等部分交易回饋不同。"
        }
if let i = db.cards.firstIndex(where: { $0.name == "JCB CARD W" }) {
            db.cards[i].issuer = "JCB"; db.cards[i].pointsName = "J-POINT"; db.cards[i].brands = "JCB"; db.cards[i].color = "4C688D"
            db.cards[i].annualFee = "永年無料"; db.cards[i].annualFeeZH = "永久免年費"
            db.cards[i].noteZH = "每月總額以 200 日圓為單位、2 J-POINT；每點最高 1 日圓，此處為單筆概算。"; db.cards[i].details = db.cards[i].note; db.cards[i].detailsZH = "每月總額以 200 日圓為單位、2 J-POINT；每點最高 1 日圓，此處為單筆概算。"
        }
        db.cards += [
Card(name: "三井住友カード（NL）", rate: 0.5, unit: 200, owned: false, source: "https://www.smbc-card.com/nyukai/card/numberless.jsp", note: "スマホタッチの対象店優遇は条件付き。通常購入のみ計算。", issuer: "三井住友カード", pointsName: "Vポイント", annualFee: "永年無料", annualFeeZH: "永久免年費", brands: "Visa / Mastercard", details: "スマホタッチの対象店優遇は条件付き。通常購入のみ計算。", detailsZH: "指定店手機感應加碼有條件，這裡僅計算一般購物。", noteZH: "指定店手機感應加碼有條件，這裡僅計算一般購物。", color: "267265"),
Card(name: "三井住友カード ゴールド（NL）", rate: 0.5, unit: 200, owned: false, source: "https://www.smbc-card.com/mem/update/pop/hikaku_proper.jsp", note: "年間利用ボーナス・年会費無料条件は自動計算しません。", issuer: "三井住友カード", pointsName: "Vポイント", annualFee: "5,500円 / 条件達成で翌年以降無料", annualFeeZH: "5,500 日圓／達成條件後次年起免年費", brands: "Visa / Mastercard", details: "年間利用ボーナス・年会費無料条件は自動計算しません。", detailsZH: "年度消費獎勵、免年費條件不會自動計算。", noteZH: "年度消費獎勵、免年費條件不會自動計算。", color: "A08036"),
Card(name: "イオンカード（WAON一体型）", rate: 0.5, unit: 200, owned: false, source: "https://www.aeon.co.jp/point/", note: "対象イオングループの2倍特典・割引日は別条件。基本分のみ計算。", issuer: "イオン銀行", pointsName: "WAON POINT", annualFee: "永年無料", annualFeeZH: "永久免年費", brands: "Visa / Mastercard / JCB", details: "対象イオングループの2倍特典・割引日は別条件。基本分のみ計算。", detailsZH: "AEON 集團指定店雙倍點數與折扣日另有條件，僅計基本回饋。", noteZH: "AEON 集團指定店雙倍點數與折扣日另有條件，僅計基本回饋。", color: "91469C"),
Card(name: "エポスカード", rate: 0.5, unit: 200, owned: false, source: "https://faq.eposcard.co.jp/faq/show/63", note: "200円単位。マルイ・モディの優遇、会員限定割引は別条件。", issuer: "エポスカード", pointsName: "エポスポイント", annualFee: "永年無料", annualFeeZH: "永久免年費", brands: "Visa", details: "200円単位。マルイ・モディの優遇、会員限定割引は別条件。", detailsZH: "每 200 日圓計點，丸井及 MODI 等優待另有條件。", noteZH: "每 200 日圓計點，丸井及 MODI 等優待另有條件。", color: "B44149"),
Card(name: "リクルートカード", rate: 1.2, unit: 1, owned: false, source: "https://recruit-card.jp/point/", note: "月間利用額×1.2%で集計。単一購入の概算です。チャージ等の例外あり。", issuer: "三菱UFJニコス / JCB", pointsName: "リクルートポイント", annualFee: "永年無料", annualFeeZH: "永久免年費", brands: "Visa / Mastercard / JCB", details: "月間利用額×1.2%で集計。単一購入の概算です。チャージ等の例外あり。", detailsZH: "按每月消費總額 ×1.2% 計點，此處為單筆概算；儲值等交易有例外。", noteZH: "按每月消費總額 ×1.2% 計點，此處為單筆概算；儲值等交易有例外。", color: "446A9B"),
Card(name: "dカード", rate: 1, unit: 100, owned: false, source: "https://dcard.docomo.ne.jp/st/dpoint_points/shopping/index.html", note: "一般購入100円単位。公共料金等は別率。2027年1月の制度改定に注意。", issuer: "NTTドコモ", pointsName: "dポイント", annualFee: "公式サイトの最新条件を確認", annualFeeZH: "請查閱官方最新年費條件", brands: "Visa / Mastercard", details: "一般購入100円単位。公共料金等は別率。2027年1月の制度改定に注意。", detailsZH: "一般購物每 100 日圓計點，公共費用等比例不同；請留意 2027 年 1 月制度變更。", noteZH: "一般購物每 100 日圓計點，公共費用等比例不同；請留意 2027 年 1 月制度變更。", color: "BD3443"),
Card(name: "au PAY カード", rate: 1, unit: 100, owned: false, source: "https://www.kddi-fs.com/merit/point/", note: "100円単位。au PAY残高チャージ等の対象外取引を除く。", issuer: "auフィナンシャルサービス", pointsName: "Pontaポイント", annualFee: "公式サイトの最新条件を確認", annualFeeZH: "請查閱官方最新年費條件", brands: "Visa / Mastercard", details: "100円単位。au PAY残高チャージ等の対象外取引を除く。", detailsZH: "每 100 日圓計點；不包含 au PAY 餘額儲值等不適用交易。", noteZH: "每 100 日圓計點；不包含 au PAY 餘額儲值等不適用交易。", color: "C06D24"),
Card(name: "Orico Card THE POINT", rate: 1, unit: 100, owned: false, source: "https://www.orico.co.jp/creditcard/list/thepoint/", note: "通常1%。入会後6か月の加算・上限は別管理。", issuer: "オリエントコーポレーション", pointsName: "オリコポイント", annualFee: "永年無料", annualFeeZH: "永久免年費", brands: "Mastercard / JCB", details: "通常1%。入会後6か月の加算・上限は別管理。", detailsZH: "一般回饋 1%；新戶前六個月加碼與上限需另外管理。", noteZH: "一般回饋 1%；新戶前六個月加碼與上限需另外管理。", color: "45515D")
        ]
        let shops = [
Merchant(name: "Amazon.co.jp", category: "オンライン", aliases: "amazon 亞馬遜 アマゾン", icon: "a", color: "393F49"),
Merchant(name: "セブン‐イレブン", category: "コンビニ", aliases: "7 eleven seven セブンイレブン 7-11 小七", icon: "7", color: "BD5128"),
Merchant(name: "ローソン", category: "コンビニ", aliases: "lawson 羅森", icon: "LAWSON", color: "2778B5"),
Merchant(name: "ファミリーマート", category: "コンビニ", aliases: "familymart 全家 ファミマ", icon: "FM", color: "24926B"),
Merchant(name: "すき家", category: "飲食", aliases: "sukiya 食其家", icon: "すき家", color: "B3473C"),
Merchant(name: "吉野家", category: "飲食", aliases: "yoshinoya", icon: "吉", color: "C47628"),
Merchant(name: "マクドナルド", category: "飲食", aliases: "mcdonalds 麥當勞 マック マクド", icon: "M", color: "B83E38"),
Merchant(name: "スターバックス", category: "カフェ", aliases: "starbucks 星巴克 スタバ", icon: "★", color: "287562"),
Merchant(name: "イオン", category: "スーパー", aliases: "aeon 永旺", icon: "AEON", color: "91469C"),
Merchant(name: "ライフ", category: "スーパー", aliases: "life 萊福", icon: "LIFE", color: "B97928"),
Merchant(name: "ウエルシア", category: "ドラッグストア", aliases: "welcia 藥妝", icon: "welcia", color: "585CB1"),
Merchant(name: "マツモトキヨシ", category: "ドラッグストア", aliases: "matsumoto kiyoshi 松本清 マツキヨ", icon: "マツキヨ", color: "997A0C"),
Merchant(name: "ユニクロ", category: "ショッピング", aliases: "uniqlo 優衣庫", icon: "UNIQLO", color: "C8393D"),
Merchant(name: "無印良品", category: "ショッピング", aliases: "muji", icon: "MUJI", color: "7F3540"),
Merchant(name: "ヨドバシカメラ", category: "家電", aliases: "yodobashi 友都八喜", icon: "YODO", color: "AC393A"),
Merchant(name: "ビックカメラ", category: "家電", aliases: "bic camera 必客", icon: "BIC", color: "B54145"),
Merchant(name: "ミニストップ", category: "コンビニ", aliases: "ministop 迷你島", icon: "MINI", color: "3A5895"),
Merchant(name: "デイリーヤマザキ", category: "コンビニ", aliases: "daily yamazaki 山崎", icon: "DY", color: "BD5D28"),
Merchant(name: "セイコーマート", category: "コンビニ", aliases: "seicomart", icon: "Seico", color: "BB6C25"),
Merchant(name: "ポプラ", category: "コンビニ", aliases: "poplar", icon: "POP", color: "AC3B48"),
Merchant(name: "オーケー", category: "スーパー", aliases: "ok 超市", icon: "OK", color: "B3454C"),
Merchant(name: "業務スーパー", category: "スーパー", aliases: "gyomu 業務超市", icon: "業務", color: "378153"),
Merchant(name: "サンディ", category: "スーパー", aliases: "sundi 桑迪", icon: "Sundi", color: "CA6B25"),
Merchant(name: "万代", category: "スーパー", aliases: "mandai 萬代", icon: "万代", color: "BF4A3C"),
Merchant(name: "イトーヨーカドー", category: "スーパー", aliases: "ito yokado 伊藤洋華堂", icon: "IY", color: "426A9C"),
Merchant(name: "西友", category: "スーパー", aliases: "seiyu 西友", icon: "SEIYU", color: "B33F51"),
Merchant(name: "マックスバリュ", category: "スーパー", aliases: "maxvalu", icon: "MAX", color: "9B4E9E"),
Merchant(name: "コープ", category: "スーパー", aliases: "coop 生協", icon: "COOP", color: "C45245"),
Merchant(name: "松屋", category: "飲食", aliases: "matsuya 松屋", icon: "松屋", color: "AB7927"),
Merchant(name: "なか卯", category: "飲食", aliases: "nakau 親子丼", icon: "なか卯", color: "B14744"),
Merchant(name: "くら寿司", category: "飲食", aliases: "kura sushi 藏壽司", icon: "くら", color: "8D6338"),
Merchant(name: "スシロー", category: "飲食", aliases: "sushiro 壽司郎", icon: "スシロー", color: "AF3D42"),
Merchant(name: "はま寿司", category: "飲食", aliases: "hama sushi 濱壽司", icon: "はま", color: "345E9A"),
Merchant(name: "CoCo壱番屋", category: "飲食", aliases: "coco ichibanya 咖哩", icon: "CoCo", color: "9F7A20"),
Merchant(name: "やよい軒", category: "飲食", aliases: "yayoi 彌生軒", icon: "やよい", color: "3E766B"),
Merchant(name: "サイゼリヤ", category: "飲食", aliases: "saizeriya 薩莉亞", icon: "Saize", color: "51835B"),
Merchant(name: "ガスト", category: "飲食", aliases: "gusto", icon: "ガスト", color: "B94E43"),
Merchant(name: "ケンタッキー", category: "飲食", aliases: "kfc 肯德基", icon: "KFC", color: "B33C47"),
Merchant(name: "モスバーガー", category: "飲食", aliases: "mos burger 摩斯漢堡", icon: "MOS", color: "9F3B44"),
Merchant(name: "餃子の王将", category: "飲食", aliases: "gyoza ohsho 餃子王將", icon: "王将", color: "A16726"),
Merchant(name: "丸亀製麺", category: "飲食", aliases: "marugame 丸龜製麵", icon: "丸亀", color: "AB403C"),
Merchant(name: "ドトール", category: "カフェ", aliases: "doutor 羅多倫", icon: "DOUTOR", color: "786744"),
Merchant(name: "タリーズ", category: "カフェ", aliases: "tullys 塔利", icon: "TULLY", color: "67514A"),
Merchant(name: "コメダ珈琲店", category: "カフェ", aliases: "komeda 客美多", icon: "KOMEDA", color: "A36537"),
Merchant(name: "サンマルクカフェ", category: "カフェ", aliases: "st marc 聖馬可", icon: "ST.MARC", color: "7D5149"),
Merchant(name: "スギ薬局", category: "ドラッグストア", aliases: "sugi 杉藥局", icon: "SUGI", color: "3F855C"),
Merchant(name: "サンドラッグ", category: "ドラッグストア", aliases: "sundrug 尚都樂客", icon: "SUN", color: "AE4351"),
Merchant(name: "ココカラファイン", category: "ドラッグストア", aliases: "cocokara fine 可開嘉來", icon: "coco", color: "B34F8D"),
Merchant(name: "ツルハドラッグ", category: "ドラッグストア", aliases: "tsuruha 鶴羽", icon: "鶴", color: "AD4B4C"),
Merchant(name: "ドン・キホーテ", category: "ショッピング", aliases: "don quijote 唐吉訶德 ドンキ", icon: "DONKI", color: "56537C"),
Merchant(name: "ダイソー", category: "ショッピング", aliases: "daiso 大創", icon: "DAISO", color: "B84883"),
Merchant(name: "セリア", category: "ショッピング", aliases: "seria 百元", icon: "Seria", color: "6D8540"),
Merchant(name: "GU", category: "ショッピング", aliases: "gu ジーユー", icon: "GU", color: "3969A1"),
Merchant(name: "しまむら", category: "ショッピング", aliases: "shimamura 思夢樂", icon: "しまむら", color: "B7434B"),
Merchant(name: "ロフト", category: "ショッピング", aliases: "loft 樂活", icon: "LOFT", color: "957D20"),
Merchant(name: "ニトリ", category: "ショッピング", aliases: "nitori 宜得利", icon: "NITORI", color: "277C75"),
Merchant(name: "東急ハンズ", category: "ショッピング", aliases: "hands 台隆 ハンズ", icon: "HANDS", color: "39715D"),
Merchant(name: "エディオン", category: "家電", aliases: "edion 愛電王", icon: "EDION", color: "3D5889"),
Merchant(name: "ヤマダデンキ", category: "家電", aliases: "yamada 山田電機", icon: "YAMADA", color: "AE444B"),
Merchant(name: "ジョーシン", category: "家電", aliases: "joshin 上新電機", icon: "Joshin", color: "B14747"),
Merchant(name: "高島屋", category: "百貨店", aliases: "takashimaya 高島屋", icon: "高", color: "9B3745"),
Merchant(name: "阪神百貨店", category: "百貨店", aliases: "hanshin 阪神", icon: "阪神", color: "475B74"),
Merchant(name: "阪急百貨店", category: "百貨店", aliases: "hankyu 阪急", icon: "阪急", color: "6D445A"),
Merchant(name: "大丸", category: "百貨店", aliases: "daimaru 大丸", icon: "大丸", color: "41785C")
        ]
        for shop in shops {
            if let i = db.merchants.firstIndex(where: { $0.name == shop.name }) {
                db.merchants[i].aliases = shop.aliases; db.merchants[i].icon = shop.icon; db.merchants[i].color = shop.color
                db.merchants[i].category = shop.category
            } else { db.merchants.append(shop) }
        }
    }
    static func matches(_ merchant: Merchant, query: String) -> Bool {
        query.isEmpty || (merchant.name + " " + merchant.category + " " + L.category(merchant.category) + " " + (merchant.aliases ?? "") + " " + (merchant.address ?? "")).localizedStandardContains(query)
    }
    static func sorted(_ merchants: [Merchant]) -> [Merchant] {
        merchants.enumerated().sorted {
            let a = $0.element.favorite == true, b = $1.element.favorite == true
            return a != b ? a : $0.offset < $1.offset
        }.map(\.element)
    }
}
