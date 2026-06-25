import Foundation

// NOAA-based solar position / event calculator.
// Computes the time the sun crosses a given depression angle below the horizon.
struct SolarTime {
    let lat: Double
    let lng: Double   // east positive
    let tz: TimeZone

    private func julianDay0h(y: Int, m: Int, d: Int) -> Double {
        var Y = y, M = m
        if M <= 2 { Y -= 1; M += 12 }
        let A = floor(Double(Y) / 100)
        let B = 2 - A + floor(A / 4)
        return floor(365.25 * Double(Y + 4716)) + floor(30.6001 * Double(M + 1)) + Double(d) + B - 1524.5
    }

    // Returns (declination°, equationOfTime minutes) for the given Julian century.
    private func sunParams(T: Double) -> (decl: Double, eqTime: Double) {
        let deg = Double.pi / 180
        let M = 357.52911 + T * (35999.05029 - 0.0001537 * T)
        let L0 = (280.46646 + T * (36000.76983 + 0.0003032 * T)).truncatingRemainder(dividingBy: 360)
        let e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
        let Mr = M * deg
        let C = sin(Mr) * (1.914602 - T * (0.004817 + 0.000014 * T))
              + sin(2 * Mr) * (0.019993 - 0.000101 * T)
              + sin(3 * Mr) * 0.000289
        let trueLong = L0 + C
        let appLong = trueLong - 0.00569 - 0.00478 * sin((125.04 - 1934.136 * T) * deg)
        let meanObliq = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
        let obliqCorr = meanObliq + 0.00256 * cos((125.04 - 1934.136 * T) * deg)
        let decl = asin(sin(obliqCorr * deg) * sin(appLong * deg)) / deg
        let y = pow(tan(obliqCorr / 2 * deg), 2)
        let L0r = L0 * deg
        let eqTime = 4 / deg * (y * sin(2 * L0r)
                              - 2 * e * sin(Mr)
                              + 4 * e * y * sin(Mr) * cos(2 * L0r)
                              - 0.5 * y * y * sin(4 * L0r)
                              - 1.25 * e * e * sin(2 * Mr))
        return (decl, eqTime)
    }

    private func dateComponents(_ day: Date) -> (y: Int, m: Int, d: Int)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: day)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return (y, m, d)
    }

    private func dateAt(minutesFromMidnight: Double, y: Int, m: Int, d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 0; c.minute = 0; c.second = 0
        let midnight = cal.date(from: c) ?? Date()
        return midnight.addingTimeInterval(minutesFromMidnight * 60)
    }

    /// Time the sun reaches `angleBelowHorizon`° below the horizon on `day`.
    /// morning=true for the rising crossing, false for the setting crossing.
    func event(day: Date, angleBelowHorizon: Double, morning: Bool) -> Date? {
        guard let (y, m, d) = dateComponents(day) else { return nil }
        let deg = Double.pi / 180
        let tzOffH = Double(tz.secondsFromGMT(for: day)) / 3600
        let jdNoonUT = julianDay0h(y: y, m: m, d: d) + (12 - tzOffH) / 24
        let T = (jdNoonUT - 2451545.0) / 36525
        let (decl, eqTime) = sunParams(T: T)
        let zenith = 90 + angleBelowHorizon
        let cosH = (cos(zenith * deg) - sin(lat * deg) * sin(decl * deg)) / (cos(lat * deg) * cos(decl * deg))
        if cosH > 1 || cosH < -1 { return nil }
        let ha = acos(cosH) / deg
        let solarNoonMin = 720 - 4 * lng - eqTime + tzOffH * 60
        let tMin = morning ? solarNoonMin - 4 * ha : solarNoonMin + 4 * ha
        return dateAt(minutesFromMidnight: tMin, y: y, m: m, d: d)
    }

    func solarNoon(day: Date) -> Date? {
        guard let (y, m, d) = dateComponents(day) else { return nil }
        let tzOffH = Double(tz.secondsFromGMT(for: day)) / 3600
        let jdNoonUT = julianDay0h(y: y, m: m, d: d) + (12 - tzOffH) / 24
        let T = (jdNoonUT - 2451545.0) / 36525
        let (_, eqTime) = sunParams(T: T)
        let solarNoonMin = 720 - 4 * lng - eqTime + tzOffH * 60
        return dateAt(minutesFromMidnight: solarNoonMin, y: y, m: m, d: d)
    }
}
