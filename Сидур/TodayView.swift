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

    // start = earliest, end = latest permissible time to pray.
    private var prayers: [(name: String, start: Date?, end: Date?)] {
        [(app.s.sh, z.netz, z.t("SofTfilaGRA")),   // Shacharit until Sof Zman Tfila (Gra)
         (app.s.mi, z.minchaG, z.shkia),           // Mincha until sunset
         (app.s.ma, z.tzeit, z.t("SolarMidnight"))] // Maariv until midnight
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
                            shmaLine
                            quickRow.padding(.top, 18)
                            tehillimTodayCard
                            if isShabbatWindow { shabbatStrip.padding(.top, 18) }
                            resumeRow
                            hero.padding(.top, 26)
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
                    // bundled services (mincha, birkat_hamazon, birkat_halevana…) win
                    if let svc = BundledService.load(raw) {
                        BundledServiceReaderView(service: svc, title: routeTitle(raw), icon: Liturgy.bracha(raw)?.icon ?? "book")
                    } else if let kind = ServiceKind(rawValue: raw) {
                        ServiceReaderView(service: kind, title: serviceTitle(kind))
                    }
                case .tehillimDay(let day):
                    TehillimReaderView(title: "\(app.s.tehDay) \(day)", chapters: Teh.chapters(day: day))
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
                        .font(displayFontLining(32, app.lang))
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
                    if let end = p.end {
                        Text("\(app.s.untilShort) \(app.fmt(end))")
                            .font(Typo.sans(13, .medium))
                            .foregroundStyle(Palette.soft)
                            .monospacedDigit()
                            .padding(.top, 2)
                    }
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

    // MARK: - Shma quick control (under the masthead rule)

    @ViewBuilder
    private var shmaLine: some View {
        let now = Date()
        let sofShma = z.t("SofShmaGRA")
        if let sofShma, now < sofShma {
            // daytime: (zman tzitzit) – Sof Zman Shma (Gra)
            let start = z.t("Misheyakir11.5")
            shmaRow("sun.max", app.s.shmaWord,
                    (start != nil ? "\(app.fmt(start)) – " : "\(app.s.untilShort) ") + "\(app.fmt(sofShma)) · \(app.s.graShort)")
        } else {
            // after Sof Zman Shma: night Shma, from tzeit (chosen variant) until midnight
            let vk = ZmanDisplay.get("tzeit") ?? "Tzais8.5"
            let tzeit = z.t(vk) ?? z.tzeit
            shmaRow("moon.stars", "\(app.s.shmaWord) · \(app.s.nightWord)",
                    "\(app.fmt(tzeit)) – \(app.fmt(z.t("SolarMidnight")))")
        }
    }

    private func shmaRow(_ icon: String, _ title: String, _ times: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Palette.gold)
            Text(title.uppercased()).font(Typo.label(9.5)).tracking(1.3).foregroundStyle(Palette.faint)
            Text(times).font(Typo.sans(12.5, .medium)).foregroundStyle(Palette.ink).monospacedDigit()
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    // MARK: - Tehillim of the day (highlighted, opens the day's text directly)

    // Same visual family as the quick-actions row, but a full-width highlighted strip.
    private var tehillimTodayCard: some View {
        let day = min(HebrewDate.dayOfMonth(tz: app.tz), 30)
        return Button {
            Haptics.tap()
            path.append(.tehillimDay(day))
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "star.fill").font(.system(size: 15)).foregroundStyle(Palette.gold)
                Text(app.s.tehTitle).font(Typo.sans(14.5, .semibold)).foregroundStyle(Palette.ink)
                Text("· \(app.s.psalm) \(TEHILLIM_RANGE(day))")
                    .font(Typo.sans(12.5, .medium)).foregroundStyle(Palette.gold).monospacedDigit()
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.gold.opacity(0.85))
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Palette.gold.opacity(0.07))
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
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

    // MARK: - Favorites (3-per-row, live drag-to-reorder)

    @State private var dragId: String? = nil
    @State private var dragLoc: CGPoint = .zero

    @ViewBuilder
    private var favoritesBlock: some View {
        if !bookmarks.isEmpty {
            let spacing: CGFloat = 10
            let itemH: CGFloat = 104
            let rows = (bookmarks.count + 2) / 3
            let gridH = CGFloat(rows) * itemH + CGFloat(max(rows - 1, 0)) * spacing
            VStack(alignment: .leading, spacing: 12) {
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
                GeometryReader { geo in
                    favGrid(width: geo.size.width, spacing: spacing, itemH: itemH)
                }
                .frame(height: gridH)
            }
            .padding(.top, 28)
        }
    }

    private func favGrid(width: CGFloat, spacing: CGFloat, itemH: CGFloat) -> some View {
        let itemW = (width - spacing * 2) / 3
        func center(_ idx: Int) -> CGPoint {
            CGPoint(x: CGFloat(idx % 3) * (itemW + spacing) + itemW / 2,
                    y: CGFloat(idx / 3) * (itemH + spacing) + itemH / 2)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(bookmarks.enumerated()), id: \.element.id) { idx, b in
                favCard(b)
                    .frame(width: itemW, height: itemH)
                    .scaleEffect(dragId == b.id ? 1.06 : 1)
                    .shadow(color: dragId == b.id ? Color.black.opacity(0.18) : .clear, radius: 9, y: 5)
                    .position(dragId == b.id ? dragLoc : center(idx))
                    .zIndex(dragId == b.id ? 1 : 0)
                    // Reorder only in edit mode → a normal tap always opens the item.
                    .applyIf(editingFavs) { $0.gesture(reorderGesture(b, itemW: itemW, itemH: itemH, spacing: spacing)) }
                    .onTapGesture {
                        guard !editingFavs else { return }
                        Haptics.tap()
                        switch b.kind {
                        case "text": path.append(.text(b.refId))
                        case "service": path.append(.service(b.refId))
                        default: break
                        }
                    }
            }
        }
        .coordinateSpace(name: "favgrid")
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: bookmarks.map(\.id))
    }

    private func reorderGesture(_ b: Bookmark, itemW: CGFloat, itemH: CGFloat, spacing: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("favgrid")))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if dragId != b.id { dragId = b.id; Haptics.tap() }
                dragLoc = drag.location
                let col = min(max(Int(drag.location.x / (itemW + spacing)), 0), 2)
                let row = max(Int(drag.location.y / (itemH + spacing)), 0)
                let target = min(max(row * 3 + col, 0), bookmarks.count - 1)
                if let from = bookmarks.firstIndex(where: { $0.id == b.id }), from != target {
                    let it = bookmarks.remove(at: from)
                    bookmarks.insert(it, at: target)
                }
            }
            .onEnded { _ in
                dragId = nil
                Bookmarks.saveOrder(bookmarks)
                Haptics.success()
            }
    }

    // A favorite as a compact card.
    private func favCard(_ b: Bookmark) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Palette.cream).frame(width: 44, height: 44)
                Glyph(name: b.icon, size: 20, color: Palette.gold)
            }
            Text(b.title(app.lang))
                .font(Typo.sans(11.5, .medium)).foregroundStyle(Palette.ink)
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(dragId == b.id ? Palette.gold : Palette.line, lineWidth: 1)))
        .overlay(alignment: .topTrailing) {
            if editingFavs {
                Button {
                    Haptics.tap()
                    Bookmarks.remove(id: b.id)
                    withAnimation { bookmarks = Bookmarks.all }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 19)).foregroundStyle(Color.red.opacity(0.9))
                        .background(Circle().fill(.white).frame(width: 15, height: 15))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
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

    /// Short chrome title for a bundled-service route: the daily service name, or
    /// the liturgy entry's name (Биркат а-мазон, Биркат а-левана…).
    private func routeTitle(_ raw: String) -> String {
        if let kind = ServiceKind(rawValue: raw) { return serviceTitle(kind) }
        return Liturgy.bracha(raw)?.name(app.lang) ?? raw
    }
}

// Compact chapter range for a given day of the 30-day Tehillim cycle.
private func TEHILLIM_RANGE(_ day: Int) -> String {
    let ch = Teh.chapters(day: day)
    guard let f = ch.first, let l = ch.last else { return "" }
    return f == l ? "\(f)" : "\(f)–\(l)"
}
