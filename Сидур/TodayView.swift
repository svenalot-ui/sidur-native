import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @State private var pidx: Int? = nil
    @State private var favPsalms: [Int] = Teh.favorites
    @State private var bookmarks: [Bookmark] = Bookmarks.all
    @State private var lastRead: LastRead? = LastReadStore.current
    @State private var path: [Route] = []
    @State private var parsha: ParshaService.Parsha? = nil

    private var z: Zmanim { app.currentZmanim }

    // (name, start, end) for Shacharit / Mincha / Maariv.
    // Maariv runs until solar midnight, so the "идёт сейчас" badge works in the evening;
    // after midnight the day rolls over and Shacharit becomes the nearest prayer again.
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
                    VStack(alignment: .leading, spacing: Space.md) {
                        header
                        quickRow
                        shabbatCard
                        resumeBanner
                        prayerCard
                        tiles
                        tehillimCard
                        if !favPsalms.isEmpty || !bookmarks.isEmpty {
                            favoritesHeader
                            favoritesGrid
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.lg)
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
                    TehillimReaderView(title: "\(app.s.psalm) \(n)", chapters: [n], onFavChange: { favPsalms = Teh.favorites })
                case .service(let raw):
                    if let kind = ServiceKind(rawValue: raw) {
                        ServiceReaderView(service: kind, title: serviceTitle(kind))
                    }
                }
            }
        }
        .onAppear {
            if pidx == nil { pidx = currentIdx }
            favPsalms = Teh.favorites
            bookmarks = Bookmarks.all
            lastRead = LastReadStore.current
            app.refreshZmanim()
        }
        .task { parsha = await ParshaService.shared.next() }
    }

    // Friday → candle lighting; Saturday → Shabbat end. Weekday is location-local.
    @ViewBuilder
    private var shabbatCard: some View {
        var cal = Calendar(identifier: .gregorian)
        let _ = { cal.timeZone = app.tz }()
        let wd = cal.component(.weekday, from: Date())
        if wd == 6 || wd == 7 {
            let isFriday = wd == 6
            let time = isFriday
                ? (z.t("CandleLighting") ?? z.shkia.map { $0.addingTimeInterval(-18 * 60) })
                : z.tzeit
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                    Image(systemName: isFriday ? "flame" : "sparkles").font(.system(size: 17)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.s.shabbatShalom.uppercased())
                        .font(.system(size: 10, weight: .medium)).tracking(1.2).foregroundStyle(Palette.gold)
                    Text(isFriday ? app.s.candleLighting : app.s.shabbatEnd)
                        .font(Typo.sans(14.5, .medium)).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 0)
                Text(app.fmt(time))
                    .font(Typo.digits(22)).foregroundStyle(Palette.gold).monospacedDigit()
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.cream)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.goldL.opacity(0.4), lineWidth: 1)))
        }
    }

    private func serviceTitle(_ k: ServiceKind) -> String {
        switch k { case .shacharit: return app.s.sh; case .mincha: return app.s.mi; case .maariv: return app.s.ma }
    }

    @ViewBuilder
    private var resumeBanner: some View {
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
                HStack(spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                        Image(systemName: "play.fill").font(.system(size: 15)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.s.continueReading.uppercased())
                            .font(.system(size: 10, weight: .medium)).tracking(1.2).foregroundStyle(Palette.gold)
                        Text(lr.title).font(Typo.sans(14.5, .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        Haptics.tap()
                        LastReadStore.dismiss()
                        withAnimation { lastRead = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.soft)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Palette.card).overlay(Circle().strokeBorder(Palette.line, lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.cream)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HebrewDate.hebrew(app.lang, tz: app.tz))
                    .font(Typo.display(30))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(HebrewDate.gregorian(app.lang, tz: app.tz))
                    .font(Typo.sans(13))
                    .foregroundStyle(Palette.soft)
                if let p = parsha {
                    Text(app.lang == .he ? p.hebrew : "\(p.hebrew) · \(ParshaService.shortTitle(p))")
                        .font(Typo.serif(13))
                        .foregroundStyle(Palette.gold)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
            NavigationLink { SettingsView() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.soft)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.card).overlay(Circle().strokeBorder(Palette.line, lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Space.xs)
    }

    private var quickRow: some View {
        HStack(spacing: 7) {
            NavigationLink { MizrahView() } label: { quickPill("location.north.line", app.s.navDir) }
                .buttonStyle(.plain)
            NavigationLink { CalendarView() } label: { quickPill("calendar", app.s.navCal) }
                .buttonStyle(.plain)
            NavigationLink { TzedakaView() } label: { quickPill("heart.circle", app.s.navTz) }
                .buttonStyle(.plain)
        }
    }

    private func quickPill(_ symbol: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Palette.gold)
            Text(label).font(Typo.sans(12)).foregroundStyle(Palette.soft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var prayerCard: some View {
        let i = pidx ?? currentIdx
        let p = prayers[i]
        let now = Date()
        let live = (p.start != nil && p.end != nil && now >= p.start! && now < p.end!)
        return VStack(spacing: 0) {
            Text(app.s.nearest.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Space.md)

            // Tapping the prayer opens its full service text.
            Button {
                Haptics.tap()
                let kinds: [ServiceKind] = [.shacharit, .mincha, .maariv]
                path.append(.service(kinds[i].rawValue))
            } label: {
                VStack(spacing: 3) {
                    Text(p.name).font(Typo.display(23)).foregroundStyle(Palette.ink)
                    Text(app.fmt(p.start)).font(Typo.digits(22)).foregroundStyle(Palette.gold).monospacedDigit()
                    if live {
                        Text(app.s.now).font(Typo.sans(11)).foregroundStyle(Palette.gold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().background(Palette.line)

            HStack(spacing: 0) {
                ForEach(Array(prayers.enumerated()), id: \.offset) { idx, pr in
                    Button { Haptics.tap(); pidx = idx } label: {
                        Text(pr.name)
                            .font(Typo.sans(11))
                            .foregroundStyle(idx == i ? Palette.ink : Palette.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(idx == i ? Palette.cream : Color.clear)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tiles: some View {
        HStack(spacing: Space.sm) {
            tile(app.s.prayers, "תְּפִלּוֹת", "book", emphasizedDark: true) { app.tab = 2 }
            tile(app.s.brachot, "בְּרָכוֹת", "leaf", emphasizedDark: false) { app.tab = 3 }
        }
    }

    private func tile(_ title: String, _ he: String, _ symbol: String, emphasizedDark: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(emphasizedDark ? Palette.ink.opacity(0.06) : Palette.gold.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: symbol).font(.system(size: 18))
                        .foregroundStyle(emphasizedDark ? Palette.ink : Palette.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typo.sans(15.5, .medium)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(he).font(Typo.serif(13)).foregroundStyle(Palette.soft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var tehillimCard: some View {
        let day = min(HebrewDate.dayOfMonth(tz: app.tz), 30)
        return Button { app.tab = 4 } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    Text("\(day)").font(Typo.digits(30)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(app.s.tehTitle)").font(Typo.sans(14.5, .medium)).foregroundStyle(Palette.ink)
                    Text(app.s.tehOpen).font(Typo.sans(12.5)).foregroundStyle(Palette.soft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var favoritesHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(Palette.gold)
            Text(app.s.favorites.uppercased())
                .font(.system(size: 10.5, weight: .medium))
                .tracking(2)
                .foregroundStyle(Palette.faint)
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .padding(.top, Space.sm)
    }

    // Favorite psalms + bookmarked brachot/services — one tap from the home screen.
    private var favoritesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(favPsalms, id: \.self) { n in
                NavigationLink(value: Route.psalm(n)) {
                    HStack(spacing: 7) {
                        Text("\(n)")
                            .font(Typo.serif(16, .semibold)).foregroundStyle(Palette.gold).monospacedDigit()
                        Text(app.s.psalm)
                            .font(Typo.sans(11.5)).foregroundStyle(Palette.soft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            ForEach(bookmarks) { b in
                NavigationLink(value: b.kind == "text" ? Route.text(b.refId) : Route.service(b.refId)) {
                    HStack(spacing: 6) {
                        Image(systemName: b.icon).font(.system(size: 12)).foregroundStyle(Palette.gold)
                        Text(b.title(app.lang))
                            .font(Typo.sans(12.5, .medium)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
