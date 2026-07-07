import SwiftUI

// Editorial-minimalism layout: a serif masthead, one dominant focal point
// (the nearest prayer's time), quiet index rows, and understated footer links.
struct TodayView: View {
    @EnvironmentObject var app: AppState
    @State private var pidx: Int? = nil
    @State private var bookmarks: [Bookmark] = Bookmarks.all
    @State private var lastRead: LastRead? = LastReadStore.current
    @State private var path: [Route] = []
    @State private var parsha: ParshaService.Parsha? = nil
    @State private var editingFavs = false

    private var z: Zmanim { app.currentZmanim }

    private var prayers: [(name: String, start: Date?, end: Date?)] {
        [(app.s.sh, z.netz, z.chatzot),
         (app.s.mi, z.minchaG, z.shkia),
         (app.s.ma, z.tzeit, z.t("SolarMidnight"))]
    }

    private var currentIdx: Int {
        let now = Date()
        if let c = z.chatzot, now < c { return 0 }
        if let s = z.shkia, now < s { return 1 }
        return 2
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    Palette.paper.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            masthead
                            quickRow.padding(.top, 20)
                            if isShabbatWindow { shabbatStrip.padding(.top, 20) }
                            resumeRow
                            hero.padding(.top, 26)
                            indexList.padding(.top, 28)
                            favoritesBlock
                            Spacer(minLength: 28)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 6)
                    }
                    .refreshable {
                        Haptics.tap()
                        app.refreshZmanim()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    // mask the status-bar area so scrolled content never collides with the clock
                    Rectangle().fill(Palette.paper)
                        .frame(height: max(geo.safeAreaInsets.top, 12))
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .text(let id):
                    if let t = Liturgy.bracha(id) { ReaderView(text: t) }
                case .psalm(let n):
                    TehillimReaderView(title: "\(app.s.psalm) \(n)", chapters: [n])
                case .service(let raw):
                    if let kind = ServiceKind(rawValue: raw) {
                        ServiceReaderView(service: kind, title: serviceTitle(kind))
                    }
                }
            }
        }
        .onAppear {
            if pidx == nil { pidx = currentIdx }
            bookmarks = Bookmarks.all
            lastRead = LastReadStore.current
            app.refreshZmanim()
        }
        .task { parsha = await ParshaService.shared.next() }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(HebrewDate.gregorian(app.lang, tz: app.tz).uppercased())
                        .font(Typo.label(10.5)).tracking(1.5)
                        .foregroundStyle(Palette.faint)
                    Text(HebrewDate.hebrew(app.lang, tz: app.tz))
                        .font(displayFont(32, app.lang))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if let p = parsha {
                        Text(app.lang == .he ? p.hebrew : "\(p.hebrew) · \(ParshaService.ruName(p))")
                            .font(Typo.serif(14))
                            .foregroundStyle(Palette.gold)
                            .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette.soft)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.s.settings)
            }
            // signature: a single short gold rule
            Rectangle().fill(Palette.gold).frame(width: 40, height: 2).padding(.top, 12)
        }
        .padding(.top, Space.xs)
    }

    // MARK: - Hero (dominant focal point)

    private var hero: some View {
        let i = pidx ?? currentIdx
        let p = prayers[i]
        let now = Date()
        let live = (p.start != nil && p.end != nil && now >= p.start! && now < p.end!)
        return VStack(spacing: 0) {
            Button {
                Haptics.tap()
                let kinds: [ServiceKind] = [.shacharit, .mincha, .maariv]
                path.append(.service(kinds[i].rawValue))
            } label: {
                VStack(spacing: 6) {
                    Text(app.s.nearest.uppercased())
                        .font(Typo.label(10)).tracking(2.4)
                        .foregroundStyle(Palette.faint)
                    Text(p.name)
                        .font(displayFont(23, app.lang))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                    Text(app.fmt(p.start))
                        .font(Typo.digits(62))
                        .foregroundStyle(Palette.gold)
                        .monospacedDigit()
                        .padding(.top, 4)
                    if live {
                        Text(app.s.now.uppercased())
                            .font(Typo.label(10)).tracking(1.5)
                            .foregroundStyle(Palette.gold)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // prayer switch — quiet text tabs under a hairline
            HStack(spacing: 0) {
                ForEach(Array(prayers.enumerated()), id: \.offset) { idx, pr in
                    Button { Haptics.tap(); pidx = idx } label: {
                        VStack(spacing: 6) {
                            Text(pr.name)
                                .font(Typo.sans(12.5, idx == i ? .semibold : .regular))
                                .foregroundStyle(idx == i ? Palette.ink : Palette.faint)
                            Rectangle()
                                .fill(idx == i ? Palette.gold : .clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 32)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        }
    }

    // MARK: - Index (editorial rows)

    private var indexList: some View {
        let day = min(HebrewDate.dayOfMonth(tz: app.tz), 30)
        return VStack(spacing: 10) {
            navCard(app.s.prayers, "תְּפִלּוֹת", "book", nil) { app.tab = 2 }
            navCard(app.s.brachot, "בְּרָכוֹת", "leaf", nil) { app.tab = 3 }
            navCard(app.s.tehTitle, "תְּהִלִּים", "star", "\(app.s.psalm) \(TEHILLIM_RANGE(day))") { app.tab = 4 }
        }
    }

    private func navCard(_ title: String, _ he: String, _ icon: String, _ trailing: String?, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LinearGradient(colors: [Palette.gold.opacity(0.16), Palette.cream], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 21)).foregroundStyle(Palette.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typo.sans(16.5, .semibold)).foregroundStyle(Palette.ink)
                    if let trailing {
                        Text(trailing).font(Typo.sans(12)).foregroundStyle(Palette.gold).monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                if app.lang != .he {
                    Text(he).font(Typo.serif(17)).foregroundStyle(Palette.faint)
                }
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint.opacity(0.7))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shabbat / Resume (quiet rows)

    // Tomorrow's Yom Tov (erev chag) — shown like erev Shabbat.
    private var erevChag: HolidayService.Day? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = app.tz
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return nil }
        return app.yomTov(on: tomorrow)
    }

    private var isShabbatWindow: Bool {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = app.tz
        let wd = cal.component(.weekday, from: Date())
        return wd == 6 || wd == 7 || erevChag != nil
    }

    @ViewBuilder
    private var shabbatStrip: some View {
        var cal = Calendar(identifier: .gregorian)
        let _ = { cal.timeZone = app.tz }()
        let isFriday = cal.component(.weekday, from: Date()) == 6
        let candles = isFriday || erevChag != nil
        let time = candles ? (z.t("CandleLighting") ?? z.shkia.map { $0.addingTimeInterval(-18 * 60) }) : z.tzeit
        let label: String = {
            if isFriday { return app.s.candleLighting }
            if let yt = erevChag {
                let name = app.lang == .he ? HolidayService.heName(yt.hebrew) : HolidayService.ruName(yt.title)
                return "\(app.s.candleLighting) · \(name)"
            }
            return app.s.shabbatEnd
        }()
        HStack(spacing: 12) {
            Image(systemName: candles ? "flame" : "sparkles").font(.system(size: 15)).foregroundStyle(Palette.gold)
            Text(label)
                .font(Typo.sans(14)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Text(app.fmt(time)).font(Typo.digits(18)).foregroundStyle(Palette.gold).monospacedDigit()
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    @ViewBuilder
    private var resumeRow: some View {
        if let lr = lastRead, Date().timeIntervalSince(lr.ts) < 3 * 86400 {
            Button {
                Haptics.tap()
                switch lr.kind {
                case "text": path.append(.text(lr.refId))
                case "psalm": if let n = Int(lr.refId) { path.append(.psalm(n)) }
                case "service": path.append(.service(lr.refId))
                default: break
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "play.circle").font(.system(size: 18)).foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.s.continueReading.uppercased())
                            .font(Typo.label(9.5)).tracking(1.4).foregroundStyle(Palette.faint)
                        Text(lr.title).font(Typo.sans(15)).foregroundStyle(Palette.ink).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        Haptics.tap(); LastReadStore.dismiss(); withAnimation { lastRead = nil }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.faint)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
    }

    // MARK: - Favorites

    @ViewBuilder
    private var favoritesBlock: some View {
        if !bookmarks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(app.s.favorites.uppercased())
                        .font(Typo.label(10)).tracking(2).foregroundStyle(Palette.faint)
                    Rectangle().fill(Palette.line).frame(height: 1)
                    Button {
                        Haptics.tap(); withAnimation { editingFavs.toggle() }
                    } label: {
                        Text(editingFavs ? app.s.editDone : app.s.edit)
                            .font(Typo.sans(12, .medium)).foregroundStyle(Palette.gold)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(bookmarks) { b in favRow(b) }
            }
            .padding(.top, 28)
        }
    }

    @ViewBuilder
    private func favRow(_ b: Bookmark) -> some View {
        if editingFavs {
            favContent(b)
        } else {
            NavigationLink(value: b.kind == "text" ? Route.text(b.refId) : Route.service(b.refId)) {
                favContent(b)
            }
            .buttonStyle(.plain)
        }
    }

    private func favContent(_ b: Bookmark) -> some View {
        HStack(spacing: 13) {
            if editingFavs {
                Button {
                    Haptics.tap()
                    Bookmarks.remove(id: b.id)
                    withAnimation { bookmarks = Bookmarks.all }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundStyle(Color.red.opacity(0.85))
                }
                .buttonStyle(.plain)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 40, height: 40)
                    Image(systemName: b.icon).font(.system(size: 17)).foregroundStyle(Palette.gold)
                }
            }
            Text(b.title(app.lang)).font(Typo.sans(15.5, .medium)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            if !editingFavs {
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint.opacity(0.7))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1)))
        .contentShape(Rectangle())
    }

    // MARK: - Quick actions (clear, tappable row)

    private var quickRow: some View {
        HStack(spacing: 0) {
            NavigationLink { MizrahView() } label: { quickItem("location.north.line", app.s.navDir) }.buttonStyle(.plain)
            vDivider
            NavigationLink { CalendarView() } label: { quickItem("calendar", app.s.navCal) }.buttonStyle(.plain)
            vDivider
            NavigationLink { TzedakaView() } label: { quickItem("heart", app.s.navTz) }.buttonStyle(.plain)
        }
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func quickItem(_ symbol: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 17, weight: .regular)).foregroundStyle(Palette.gold)
            Text(label).font(Typo.sans(11.5)).foregroundStyle(Palette.soft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private var vDivider: some View { Rectangle().fill(Palette.line).frame(width: 1, height: 28) }

    private func serviceTitle(_ k: ServiceKind) -> String {
        switch k { case .shacharit: return app.s.sh; case .mincha: return app.s.mi; case .maariv: return app.s.ma }
    }
}

// Compact chapter range for a given day of the 30-day Tehillim cycle.
private func TEHILLIM_RANGE(_ day: Int) -> String {
    let ch = Teh.chapters(day: day)
    guard let f = ch.first, let l = ch.last else { return "" }
    return f == l ? "\(f)" : "\(f)–\(l)"
}
