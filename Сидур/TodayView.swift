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
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        masthead
                        if isShabbatWindow { shabbatStrip.padding(.top, 20) }
                        resumeRow
                        hero.padding(.top, 26)
                        indexList.padding(.top, 28)
                        favoritesBlock
                        footerLinks.padding(.top, 30)
                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, Space.sm)
                }
                .refreshable {
                    Haptics.tap()
                    app.refreshZmanim()
                    try? await Task.sleep(nanoseconds: 500_000_000)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(HebrewDate.hebrew(app.lang, tz: app.tz))
                        .font(Typo.display(31))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(HebrewDate.gregorian(app.lang, tz: app.tz))
                        .font(Typo.sans(13))
                        .foregroundStyle(Palette.soft)
                    if let p = parsha {
                        Text(app.lang == .he ? p.hebrew : "\(p.hebrew) · \(ParshaService.shortTitle(p))")
                            .font(Typo.serif(13.5))
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
                VStack(spacing: 5) {
                    Text(app.s.nearest.uppercased())
                        .font(.system(size: 10, weight: .medium)).tracking(2.6)
                        .foregroundStyle(Palette.faint)
                    Text(p.name)
                        .font(Typo.display(22))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                    Text(app.fmt(p.start))
                        .font(Typo.digits(60))
                        .foregroundStyle(Palette.gold)
                        .monospacedDigit()
                        .padding(.top, 2)
                    if live {
                        Text(app.s.now)
                            .font(Typo.sans(11)).tracking(1)
                            .foregroundStyle(Palette.gold)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
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
            .padding(.top, 20)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        }
    }

    // MARK: - Index (editorial rows)

    private var indexList: some View {
        let day = min(HebrewDate.dayOfMonth(tz: app.tz), 30)
        return VStack(spacing: 0) {
            indexRow(app.s.prayers, "תְּפִלּוֹת") { app.tab = 2 }
            hair
            indexRow(app.s.brachot, "בְּרָכוֹת") { app.tab = 3 }
            hair
            indexRow(app.s.tehTitle, "\(app.s.psalm) \(TEHILLIM_RANGE(day))", trailingGold: true) { app.tab = 4 }
        }
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func indexRow(_ title: String, _ trailing: String, trailingGold: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Text(title).font(Typo.sans(16.5)).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(trailing)
                    .font(trailingGold ? Typo.serif(14) : Typo.serif(16))
                    .foregroundStyle(trailingGold ? Palette.gold : Palette.faint)
                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint.opacity(0.7))
            }
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hair: some View { Rectangle().fill(Palette.line).frame(height: 1) }

    // MARK: - Shabbat / Resume (quiet rows)

    private var isShabbatWindow: Bool {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = app.tz
        let wd = cal.component(.weekday, from: Date())
        return wd == 6 || wd == 7
    }

    @ViewBuilder
    private var shabbatStrip: some View {
        var cal = Calendar(identifier: .gregorian)
        let _ = { cal.timeZone = app.tz }()
        let isFriday = cal.component(.weekday, from: Date()) == 6
        let time = isFriday ? (z.t("CandleLighting") ?? z.shkia.map { $0.addingTimeInterval(-18 * 60) }) : z.tzeit
        HStack(spacing: 12) {
            Image(systemName: isFriday ? "flame" : "sparkles").font(.system(size: 15)).foregroundStyle(Palette.gold)
            Text(isFriday ? app.s.candleLighting : app.s.shabbatEnd)
                .font(Typo.sans(14)).foregroundStyle(Palette.ink)
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
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.s.continueReading)
                            .font(.system(size: 10, weight: .medium)).tracking(1.4).foregroundStyle(Palette.faint)
                        Text(lr.title).font(Typo.sans(14.5)).foregroundStyle(Palette.ink).lineLimit(1)
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(app.s.favorites.uppercased())
                        .font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(Palette.faint)
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
                .padding(.bottom, 2)
                ForEach(Array(bookmarks.enumerated()), id: \.element.id) { idx, b in
                    NavigationLink(value: b.kind == "text" ? Route.text(b.refId) : Route.service(b.refId)) {
                        HStack(spacing: 12) {
                            Image(systemName: b.icon).font(.system(size: 14)).foregroundStyle(Palette.gold)
                            Text(b.title(app.lang)).font(Typo.sans(15.5)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint.opacity(0.7))
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1) } }
                }
            }
            .padding(.top, 28)
        }
    }

    // MARK: - Footer links

    private var footerLinks: some View {
        HStack(spacing: 14) {
            Spacer()
            NavigationLink { MizrahView() } label: { footerLink(app.s.navDir) }.buttonStyle(.plain)
            dotSep
            NavigationLink { CalendarView() } label: { footerLink(app.s.navCal) }.buttonStyle(.plain)
            dotSep
            NavigationLink { TzedakaView() } label: { footerLink(app.s.navTz) }.buttonStyle(.plain)
            Spacer()
        }
    }

    private func footerLink(_ t: String) -> some View {
        Text(t).font(Typo.sans(12.5)).foregroundStyle(Palette.gold)
    }
    private var dotSep: some View { Circle().fill(Palette.faint.opacity(0.5)).frame(width: 3, height: 3) }

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
