import SwiftUI

enum BrandAssets {
    struct Source: Identifiable {
        var id: String { name }
        let name: String
        let mark: String
        let asset: String
        let url: String
    }
    static let sources: [Source] = [
        Source(name: "Amazon.co.jp", mark: "a", asset: "Brand_00", url: "https://www.amazon.co.jp/"),
        Source(name: "セブン‐イレブン", mark: "7", asset: "Brand_01", url: "https://www.sej.co.jp/"),
        Source(name: "ローソン", mark: "LAWSON", asset: "Brand_02", url: "https://www.lawson.co.jp/"),
        Source(name: "ファミリーマート", mark: "FM", asset: "Brand_03", url: "https://www.family.co.jp/"),
        Source(name: "すき家", mark: "すき家", asset: "Brand_04", url: "https://www.sukiya.jp/"),
        Source(name: "吉野家", mark: "吉", asset: "Brand_05", url: "https://www.yoshinoya.com/"),
        Source(name: "マクドナルド", mark: "M", asset: "Brand_06", url: "https://www.mcdonalds.co.jp/"),
        Source(name: "スターバックス", mark: "★", asset: "Brand_07", url: "https://www.starbucks.co.jp/"),
        Source(name: "イオン", mark: "AEON", asset: "Brand_08", url: "https://www.aeon.com/"),
        Source(name: "ライフ", mark: "LIFE", asset: "Brand_09", url: "https://www.lifecorp.jp/"),
        Source(name: "ウエルシア", mark: "welcia", asset: "Brand_10", url: "https://www.welcia-yakkyoku.co.jp/assets/front/img/head_logo.png"),
        Source(name: "マツモトキヨシ", mark: "マツキヨ", asset: "Brand_11", url: "https://www.matsukiyococokara-online.com/"),
        Source(name: "ユニクロ", mark: "UNIQLO", asset: "Brand_12", url: "https://www.uniqlo.com/jp/ja/"),
        Source(name: "無印良品", mark: "MUJI", asset: "Brand_13", url: "https://www.muji.com/jp/ja/"),
        Source(name: "ヨドバシカメラ", mark: "YODO", asset: "Brand_14", url: "https://www.yodobashi.com/"),
        Source(name: "ビックカメラ", mark: "BIC", asset: "Brand_15", url: "https://www.biccamera.com/"),
        Source(name: "ミニストップ", mark: "MINI", asset: "Brand_16", url: "https://www.ministop.co.jp/"),
        Source(name: "デイリーヤマザキ", mark: "DY", asset: "Brand_17", url: "https://www.daily-yamazaki.jp/"),
        Source(name: "セイコーマート", mark: "Seico", asset: "Brand_18", url: "https://www.seicomart.co.jp/"),
        Source(name: "ポプラ", mark: "POP", asset: "Brand_19", url: "https://www.poplar-cvs.co.jp/"),
        Source(name: "オーケー", mark: "OK", asset: "Brand_20", url: "https://ok-corporation.jp/"),
        Source(name: "業務スーパー", mark: "業務", asset: "Brand_21", url: "https://www.gyomusuper.jp/"),
        Source(name: "サンディ", mark: "Sundi", asset: "Brand_22", url: "https://www.sundi.co.jp/"),
        Source(name: "万代", mark: "万代", asset: "Brand_23", url: "https://www.mandai-net.co.jp/"),
        Source(name: "イトーヨーカドー", mark: "IY", asset: "Brand_24", url: "https://www.itoyokado.co.jp/"),
        Source(name: "西友", mark: "SEIYU", asset: "Brand_25", url: "https://www.seiyu.co.jp/"),
        Source(name: "マックスバリュ", mark: "MAX", asset: "Brand_26", url: "https://www.mv-tokai.co.jp/"),
        Source(name: "コープ", mark: "COOP", asset: "Brand_27", url: "https://jccu.coop/"),
        Source(name: "松屋", mark: "松屋", asset: "Brand_28", url: "https://www.matsuyafoods.com.hk/"),
        Source(name: "なか卯", mark: "なか卯", asset: "Brand_29", url: "https://www.nakau.co.jp/"),
        Source(name: "くら寿司", mark: "くら", asset: "Brand_30", url: "https://www.kurasushi.co.jp/"),
        Source(name: "スシロー", mark: "スシロー", asset: "Brand_31", url: "https://www.akindo-sushiro.co.jp/"),
        Source(name: "はま寿司", mark: "はま", asset: "Brand_32", url: "https://www.hama-sushi.co.jp/"),
        Source(name: "CoCo壱番屋", mark: "CoCo", asset: "Brand_33", url: "https://www.ichibanya.co.jp/"),
        Source(name: "やよい軒", mark: "やよい", asset: "Brand_34", url: "https://www.yayoiken.com/"),
        Source(name: "サイゼリヤ", mark: "Saize", asset: "Brand_35", url: "https://www.saizeriya.co.jp/"),
        Source(name: "ガスト", mark: "ガスト", asset: "Brand_36", url: "https://www.skylark.co.jp/gusto/"),
        Source(name: "ケンタッキー", mark: "KFC", asset: "Brand_37", url: "https://www.kfc.co.jp/"),
        Source(name: "モスバーガー", mark: "MOS", asset: "Brand_38", url: "https://www.mos.jp/"),
        Source(name: "餃子の王将", mark: "王将", asset: "Brand_39", url: "https://www.ohsho.co.jp/"),
        Source(name: "丸亀製麺", mark: "丸亀", asset: "Brand_40", url: "https://jp.marugame.com/"),
        Source(name: "ドトール", mark: "DOUTOR", asset: "Brand_41", url: "https://www.doutor.co.jp/"),
        Source(name: "タリーズ", mark: "TULLY", asset: "Brand_42", url: "https://www.tullys.co.jp/"),
        Source(name: "コメダ珈琲店", mark: "KOMEDA", asset: "Brand_43", url: "https://www.komeda.co.jp/"),
        Source(name: "サンマルクカフェ", mark: "ST.MARC", asset: "Brand_44", url: "https://www.saint-marc-hd.com/saintmarccafe/"),
        Source(name: "スギ薬局", mark: "SUGI", asset: "Brand_45", url: "https://www.sugi-net.jp/"),
        Source(name: "サンドラッグ", mark: "SUN", asset: "Brand_46", url: "https://www.sundrug.co.jp/"),
        Source(name: "ココカラファイン", mark: "coco", asset: "Brand_47", url: "https://tsuminami.aeonmall.jp/shop/38e0e462-b90b-4bef-9677-6378087fdc7f"),
        Source(name: "ツルハドラッグ", mark: "鶴", asset: "Brand_48", url: "https://www.tsuruha.co.jp/"),
        Source(name: "ドン・キホーテ", mark: "DONKI", asset: "Brand_49", url: "https://www.donki.com/"),
        Source(name: "ダイソー", mark: "DAISO", asset: "Brand_50", url: "https://www.daiso-sangyo.co.jp/en/"),
        Source(name: "セリア", mark: "Seria", asset: "Brand_51", url: "https://zama.aeonmall.jp/shop/9d826543-d9d1-4e9e-8f66-64369b659eec"),
        Source(name: "GU", mark: "GU", asset: "Brand_52", url: "https://www.gu-global.com/jp/ja/"),
        Source(name: "しまむら", mark: "しまむら", asset: "Brand_53", url: "https://www.shimamura.gr.jp/"),
        Source(name: "ロフト", mark: "LOFT", asset: "Brand_54", url: "https://www.loft.co.jp/"),
        Source(name: "ニトリ", mark: "NITORI", asset: "Brand_55", url: "https://www.nitori-net.jp/"),
        Source(name: "東急ハンズ", mark: "HANDS", asset: "Brand_56", url: "https://info.hands.net/"),
        Source(name: "エディオン", mark: "EDION", asset: "Brand_57", url: "https://www.edion.com/"),
        Source(name: "ヤマダデンキ", mark: "YAMADA", asset: "Brand_58", url: "https://www.yamada-denkiweb.com/"),
        Source(name: "ジョーシン", mark: "Joshin", asset: "Brand_59", url: "https://joshinweb.jp/"),
        Source(name: "高島屋", mark: "高", asset: "Brand_60", url: "https://www.takashimaya.co.jp/"),
        Source(name: "阪神百貨店", mark: "阪神", asset: "Brand_61", url: "https://www.hanshin-dept.jp/hshonten/assets/img/common/favicon.ico"),
        Source(name: "阪急百貨店", mark: "阪急", asset: "Brand_62", url: "https://www.hankyu-dept.co.jp/"),
        Source(name: "大丸", mark: "大丸", asset: "Brand_63", url: "https://www.daimaru.co.jp/"),
    ]
    static func image(for merchant: Merchant) -> String? {
        if let exact = sources.first(where: { $0.name == merchant.name }) { return exact.asset }
        if let mark = merchant.icon, let matched = sources.first(where: { $0.mark == mark }) { return matched.asset }
        return sources.first(where: { merchant.name.localizedStandardContains($0.name) })?.asset
    }
}
