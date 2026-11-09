# Sora Weather 1.9.0

The former precipitation map is removed. The left floating control opens a full-screen disaster information page using the existing JMA announcement service. Official announcement names are retained, including severe-weather notices.

- Current-city announcements are grouped by special warning / warning / advisory, with issue time, prefecture scope, expandable text and severity colors.
- Other saved cities list their highest announcement level and count, and select the corresponding city.
- The ten latest earthquake records expose occurrence time, epicenter, magnitude and color-coded maximum seismic intensity. Unavailable fields are not fabricated.
- Successful JMA announcement components are stored in Application Support. Failed components retain their previous data and original timestamp, and are explicitly labeled offline. A successful empty response clears an old announcement. Late older responses cannot resurrect cleared data.
- Existing JMA data is prefecture-level, not municipality-specific. Geographic scope is explicit. Old offline announcements require verification against JMA.
- Existing ordinary rainfall notification scheduling, cooldown and authorization remain unchanged. Taps resolve the city from payload or the existing request identifier and open its disaster page, including cold launch. This does not add guaranteed real-time emergency push, tsunami push, evacuation instructions or Critical Alerts.
- Semantic/scaled typography, multiline layouts, spoken forecast/severity labels, portrait-only iPhone orientation, full-screen background, ProMotion opt-in and city management are preserved.
- JMA/Yahoo forecast HTTP, forecast decoding and merge implementation are unchanged.

Verification includes cache round-trip / partial failure / empty-success clearing / out-of-order response tests, earthquake projection, notification destination resolution, UI entry/exit, empty state, expanded announcements, saved-city navigation and cold-launch navigation at accessibility sizes.
