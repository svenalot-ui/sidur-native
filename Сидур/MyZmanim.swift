import Foundation

// myzmanim.com HTTP JSON client. Times come back as local wall-clock (with a
// misleading "Z"); we parse the components in the location's timezone.
enum MyZmanimClient {
    private static let base = "https://api.myzmanim.com/engine1.json.aspx"

    private static func post(_ endpoint: String, _ fields: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "\(base)/\(endpoint)")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        let body = fields.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v)"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func locationID(lat: Double, lng: Double) async -> String? {
        let cacheKey = "mz_loc_\(Int((lat * 100).rounded()))_\(Int((lng * 100).rounded()))"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) { return cached }
        do {
            let j = try await post("searchGps", [
                "User": Secrets.myzmanimUser, "Key": Secrets.myzmanimKey, "Coding": "CS",
                "Latitude": String(lat), "Longitude": String(lng),
            ])
            if let id = j["LocationID"] as? String, !id.isEmpty {
                UserDefaults.standard.set(id, forKey: cacheKey)
                return id
            }
        } catch {}
        return nil
    }

    static func getDay(locationID: String, date: Date) async -> [String: String]? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        do {
            let j = try await post("getDay", [
                "User": Secrets.myzmanimUser, "Key": Secrets.myzmanimKey, "Coding": "CS",
                "Language": "en", "LocationID": locationID, "InputDate": f.string(from: date),
            ])
            if let err = j["ErrMsg"] as? String, !err.isEmpty { return nil }
            if let zman = j["Zman"] as? [String: Any] {
                return zman.compactMapValues { $0 as? String }
            }
        } catch {}
        return nil
    }

    // Parse a myzmanim wall-clock string ("2026-07-01T03:41:47Z") in `tz`.
    // Returns nil for the API's sentinel "does-not-occur" values.
    private static func parse(_ s: String?, tz: TimeZone) -> Date? {
        guard var str = s, !str.hasPrefix("0001") else { return nil }
        if str.hasSuffix("Z") { str.removeLast() }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        guard let d = f.date(from: str) else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let h = cal.component(.hour, from: d), m = cal.component(.minute, from: d)
        if h == 0 && m <= 1 { return nil }   // sentinel for zmanim that don't occur
        return d
    }

    private static func firstValid(_ zman: [String: String], _ keys: [String], tz: TimeZone) -> Date? {
        for k in keys { if let d = parse(zman[k], tz: tz) { return d } }
        return nil
    }

    // Map myzmanim fields → our internal named keys (same keys the native engine uses).
    // Field names verified against the live getDay response. Degree-based alos/tzais
    // are left to the native NOAA engine (accurate for the angle); everything with a
    // clear myzmanim equivalent is overridden so the list matches the myzmanim app.
    static func named(from zman: [String: String], tz: TimeZone) -> [String: Date] {
        var out: [String: Date] = [:]
        func put(_ key: String, _ candidates: [String]) {
            if let d = firstValid(zman, candidates, tz: tz) { out[key] = d }
        }
        put("Alos72",        ["Dawn72fix"])
        put("Alos90",        ["Dawn90"])
        put("Misheyakir11.5",["Yakir115", "YakirDefault"])
        put("Misheyakir11",  ["Yakir110"])
        put("Misheyakir10.2",["Yakir102"])
        put("Sunrise",       ["SunriseDefault", "SunriseElevated", "SunriseLevel"])
        put("SofShmaMGA",    ["ShemaMA72fix"])
        put("SofShmaGRA",    ["ShemaGra"])
        put("SofTfilaMGA",   ["ShachrisMA72fix"])
        put("SofTfilaGRA",   ["ShachrisGra"])
        put("Chatzos",       ["Midday"])
        put("MinchaGedola",  ["MinchaGra"])
        put("MinchaGedola30",["Mincha30fix"])
        put("MinchaKetana",  ["KetanaGra"])
        put("Plag",          ["PlagGra"])
        put("Sunset",        ["SunsetDefault", "SunsetElevated"])
        put("CandleLighting", ["Candles"])
        put("Tzais8.5",      ["NightGra240", "NightGra225"])   // geonim-style nightfall
        put("TzeisZalman",   ["NightZalman"])
        put("TzeisChazonIsh",["NightChazonIsh"])
        put("Tzeis50",       ["Night50fix"])
        put("Tzais72",       ["Night72fix"])
        put("Tzeis90",       ["Night90"])
        put("SolarMidnight", ["Midnight"])
        return out
    }

    /// One-shot: coordinates + date → named zmanim (or nil if offline/unavailable).
    static func fetchNamed(lat: Double, lng: Double, date: Date, tz: TimeZone) async -> [String: Date]? {
        guard let id = await locationID(lat: lat, lng: lng) else { return nil }
        guard let zman = await getDay(locationID: id, date: date) else { return nil }
        let mapped = named(from: zman, tz: tz)
        return mapped.isEmpty ? nil : mapped
    }
}

// Disk cache of the last myzmanim result per location+day, so the app shows the
// myzmanim times immediately on launch (and offline) instead of native fallbacks.
enum MyZmanimCache {
    static func load(_ key: String) -> [String: Date]? {
        guard let d = UserDefaults.standard.dictionary(forKey: key) as? [String: Double], !d.isEmpty else { return nil }
        return d.mapValues { Date(timeIntervalSince1970: $0) }
    }
    static func save(_ key: String, _ named: [String: Date]) {
        UserDefaults.standard.set(named.mapValues { $0.timeIntervalSince1970 }, forKey: key)
    }
}
