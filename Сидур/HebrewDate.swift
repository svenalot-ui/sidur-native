import Foundation

// Native Hebrew + Gregorian date strings (no API — Foundation's Hebrew calendar).
enum HebrewDate {
    static func hebrew(_ lang: Lang, _ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = lang.locale
        let f = DateFormatter()
        f.calendar = cal
        f.locale = lang.locale
        f.dateFormat = lang == .he ? "d בMMMM y" : "d MMMM y 'г.'"
        return f.string(from: date)
    }

    static func gregorian(_ lang: Lang, _ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("EEE d MMMM")
        return f.string(from: date)
    }

    /// Day of the Hebrew month (1–30) — used for the daily Tehillim cycle.
    static func dayOfMonth(_ date: Date = Date()) -> Int {
        let cal = Calendar(identifier: .hebrew)
        return cal.component(.day, from: date)
    }
}
