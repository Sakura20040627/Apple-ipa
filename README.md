# 櫻卡 / Sakura Card 2.1

Native SwiftUI app for iOS 26. Current catalog supports **PayPay Card and Amazon Mastercard only**, with real card artwork, 64 merchant brand images, nearby Apple Maps search, pinned favorites, Japanese / Traditional Chinese, local JSON backup, and conditional reward comparisons. Theme, language, eligibility, backup and attribution live on secondary settings pages.

Open `PayCompass.xcodeproj` in Xcode 26+, select the PayCompass scheme, choose your development team and unique bundle identifier, then build. Unsigned cloud IPA: Actions → Build Sakura Card IPA → SakuraCard-unsigned-IPA. It must be signed before installation. See `CLOUD_BUILD_中文.md` for signing/export details.

Reward information was checked against public issuer sources on 2026-11-04 (Japan). Fixed benefits are calculated only for selected conditions; lotteries, targeted coupons and welcome offers are described separately. Source links and image attribution are in the app. Brand artwork is excluded from the source-code MIT license.

See `UPDATE_2.1_中文.md` for this revision and older update/validation documents for historical versions.
