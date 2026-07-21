import Foundation

// Native Hebrew + Gregorian date strings (no API — Foundation's Hebrew calendar).
// All take the location timezone so the shown "today" matches the zmanim day.
enum HebrewDate {
    static func hebrew(_ lang: Lang, _ date: Date = Date(), tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = lang.locale
        cal.timeZone = tz
        let f = DateFormatter()
        f.calendar = cal
        f.locale = lang.locale
        f.timeZone = tz
        f.dateFormat = lang == .he ? "d בMMMM y" : "d MMMM y 'г.'"
        return f.string(from: date)
    }

    static func gregorian(_ lang: Lang, _ date: Date = Date(), tz: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.timeZone = tz
        f.setLocalizedDateFormatFromTemplate("EEE d MMMM")
        return f.string(from: date)
    }

    /// Day of the Hebrew month (1–30) — used for the daily Tehillim cycle.
    static func dayOfMonth(_ date: Date = Date(), tz: TimeZone = .current) -> Int {
        var cal = Calendar(identifier: .hebrew)
        cal.timeZone = tz
        return cal.component(.day, from: date)
    }

    /// Length of the current Hebrew month (29 or 30) — a short month has no 30th
    /// day, so its 29th must carry the 30th day's psalms too.
    static func daysInMonth(_ date: Date = Date(), tz: TimeZone = .current) -> Int {
        var cal = Calendar(identifier: .hebrew)
        cal.timeZone = tz
        return cal.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}
