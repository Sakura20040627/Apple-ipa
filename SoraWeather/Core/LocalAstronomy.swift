import Foundation

// Local approximate solar/lunar equations, adapted from SunCalc (BSD-2-Clause).
// No ephemeris service or network request. See Resources/THIRD_PARTY_NOTICES.txt.
public struct LocalAstronomy: Sendable {
    public let sunrise: Date
    public let sunset: Date
    public let moonPhase: Int
    public let illumination: Double
    private static let rad = Double.pi / 180
    public static func calculate(date: Date, latitude: Double, longitude: Double) -> LocalAstronomy? {
        guard date.timeIntervalSince1970.isFinite, latitude.isFinite, longitude.isFinite,
              abs(latitude) < 90, abs(longitude) <= 180,
              let noon = JapanTime.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else { return nil }
        let lw = -longitude * rad, phi = latitude * rad
        let d = noon.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545
        let n = (d - 0.0009 - lw / (2 * .pi)).rounded()
        let ds = 0.0009 + lw / (2 * .pi) + n
        func solar(_ days: Double) -> (m: Double, l: Double, dec: Double, ra: Double) {
            let m = rad * (357.5291 + 0.98560028 * days)
            let c = rad * (1.9148 * sin(m) + 0.0200 * sin(2*m) + 0.0003 * sin(3*m))
            let l = m + c + rad * 102.9372 + .pi
            return (m, l, asin(sin(l) * sin(rad * 23.4397)), atan2(sin(l) * cos(rad * 23.4397), cos(l)))
        }
        let sun = solar(ds)
        let h = (sin(-0.833 * rad) - sin(phi)*sin(sun.dec)) / (cos(phi)*cos(sun.dec))
        guard h.isFinite, (-1...1).contains(h) else { return nil } // Polar day/night: no empty card.
        let w = acos(h)
        let transit = 2451545 + ds + 0.0053*sin(sun.m) - 0.0069*sin(2*sun.l)
        let set = 2451545 + 0.0009 + (w+lw)/(2 * .pi) + n + 0.0053*sin(sun.m) - 0.0069*sin(2*sun.l)
        let riseDate = Date(timeIntervalSince1970: (2*transit-set-2440587.5)*86400)
        let setDate = Date(timeIntervalSince1970: (set-2440587.5)*86400)
        guard riseDate < setDate, JapanTime.key(riseDate) == JapanTime.key(date), JapanTime.key(setDate) == JapanTime.key(date) else { return nil }
        let md = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545
        let s = solar(md)
        let ml = rad*(218.316 + 13.176396*md), mm = rad*(134.963 + 13.064993*md)
        let mf = rad*(93.272 + 13.229350*md), l = ml + rad*6.289*sin(mm), b = rad*5.128*sin(mf)
        let dec = asin(sin(b)*cos(rad*23.4397) + cos(b)*sin(rad*23.4397)*sin(l))
        let ra = atan2(sin(l)*cos(rad*23.4397) - tan(b)*sin(rad*23.4397), cos(l))
        let separation = acos(min(1, max(-1, sin(s.dec)*sin(dec) + cos(s.dec)*cos(dec)*cos(s.ra-ra))))
        let inc = atan2(149598000*sin(separation), 385001-20905*cos(mm)-149598000*cos(separation))
        let angle = atan2(cos(s.dec)*sin(s.ra-ra), sin(s.dec)*cos(dec)-cos(s.dec)*sin(dec)*cos(s.ra-ra))
        let phase = 0.5 + 0.5*inc*(angle < 0 ? -1.0 : 1.0)/Double.pi
        let illumination = (1+cos(inc))/2
        guard phase.isFinite, illumination.isFinite else { return nil }
        return LocalAstronomy(sunrise: riseDate, sunset: setDate, moonPhase: Int((phase*8).rounded()) % 8, illumination: illumination)
    }
}
