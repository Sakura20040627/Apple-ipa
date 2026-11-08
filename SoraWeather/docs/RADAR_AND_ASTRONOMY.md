# Radar and local astronomy verification

Verified 2026-11-09 JST against JMA's own viewer and a live PNG response.

- Viewer: https://www.jma.go.jp/bosai/nowc/
- Viewer configuration: https://www.jma.go.jp/bosai/nowc/table/nowc.properties__7d6f7d8dc6f16a416574.xml
- Runtime template in official viewer JavaScript: `.../{basetime}/{member or none}/{validtime}/surf/{element}/{z}/{x}/{y}.png`.
- Sources: https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N1.json and targetTimes_N2.json.
- Example actually returned HTTP 200, image/png, valid PNG bytes (2662 bytes): https://www.jma.go.jp/bosai/jmatile/data/nowc/20261108154000/none/20261108154000/surf/hrpns/6/56/25.png
- Times are obtained from metadata, never generated for production requests. Time-stamped tiles expire; the example is evidence, not a permanent downloadable fixture.
- Official config specifies even native zooms, maximum native zoom 10. Odd/overzoom requests crop an actual ancestor; missing sparse tiles try coarser even zooms.
- Original JMA PNG palette includes `(250,245,0)` while the normal SVG legend uses `(255,245,0)`. Both map to the same 20 mm/h bucket. Original thresholds remain <1, 1, 5, 10, 20, 30, 50, 80+ mm/h; only colors change.
- Visible viewport tiles preload up to 12 available frames on either side. At most four preload jobs run together; encoded tile cache is bounded to 32 MiB / 768 entries. Playback and preloading stop when the map closes. No background scraping.
- Endpoint paths are viewer implementation details, not an API stability guarantee. On failure remove the overlay, legend and playback; retain Apple map and forecast bubble. Missing future metadata does not create fake forecast frames.
- Attribution: 気象庁「高解像度降水ナウキャスト」をSora Weatherが配色加工・地図重畳して作成。
- JMA terms: https://www.jma.go.jp/jma/kishou/info/coment.html ; adopted Public Data License 1.0: https://www.digital.go.jp/resources/open_data/public_data_license_v1.0 . Attribution and processing disclosure are visible in the map and Data & Privacy. No claim of official endorsement or guaranteed emergency delivery.

Local astronomical equations reference SunCalc (BSD-2-Clause; full notice included in app). Sunrise/set use a flat horizon and solar altitude -0.833 degrees; lunar phase is a geocentric approximation. No network requests are used by LocalAstronomy. Polar/invalid results hide the card. Tests compare Osaka 2026-11-09 to NAOJ 06:26/16:58 JST within four minutes: https://eco.mtk.nao.ac.jp/koyomi/dni/2026/s2811.html.en .

Forecast HTTP, JMA/Yahoo parsers and merge logic are unchanged in this release. Wind speed/direction features are absent; official JMA warning names and actual place names are not censored.
