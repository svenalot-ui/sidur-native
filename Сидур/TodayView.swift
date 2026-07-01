import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState
    @State private var pidx: Int? = nil
    @State private var favPsalms: [Int] = Teh.favorites

    private var z: Zmanim { app.currentZmanim }

    // (name, start, end) for Shacharit / Mincha / Maariv
    private var prayers: [(name: String, start: Date?, end: Date?)] {
        [(app.s.sh, z.netz, z.chatzot),
         (app.s.mi, z.minchaG, z.shkia),
         (app.s.ma, z.tzeit, nil)]
    }

    private var currentIdx: Int {
        let now = Date()
        if let c = z.chatzot, now < c { return 0 }
        if let s = z.shkia, now < s { return 1 }
        return 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        header
                        quickRow
                        prayerCard
                        tiles
                        tehillimCard
                        if !favPsalms.isEmpty {
                            favoritesHeader
                            favoritesGrid
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if pidx == nil { pidx = currentIdx }
            favPsalms = Teh.favorites
            app.refreshZmanim()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HebrewDate.hebrew(app.lang))
                .font(Typo.display(30))
                .foregroundStyle(Palette.ink)
            Text(HebrewDate.gregorian(app.lang))
                .font(Typo.sans(13))
                .foregroundStyle(Palette.soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.xs)
    }

    private var quickRow: some View {
        HStack(spacing: 7) {
            NavigationLink { MizrahView() } label: { quickPill("location.north.line", app.s.navDir) }
                .buttonStyle(.plain)
            NavigationLink { TzedakaView() } label: { quickPill("heart.circle", app.s.navTz) }
                .buttonStyle(.plain)
            NavigationLink { SettingsView() } label: { quickPill("gearshape", app.s.settings) }
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

            VStack(spacing: 3) {
                Text(p.name).font(Typo.display(23)).foregroundStyle(Palette.ink)
                Text(app.fmt(p.start)).font(Typo.serif(21, .semibold)).foregroundStyle(Palette.gold)
                if live {
                    Text(app.s.now).font(Typo.sans(11)).foregroundStyle(Palette.gold)
                }
            }
            .padding(.vertical, 10)

            Divider().background(Palette.line)

            HStack(spacing: 0) {
                ForEach(Array(prayers.enumerated()), id: \.offset) { idx, pr in
                    Button { pidx = idx } label: {
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
        let day = min(HebrewDate.dayOfMonth(), 30)
        return Button { app.tab = 4 } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    Text("\(day)").font(Typo.display(30)).foregroundStyle(.white)
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

    // Favorite psalms — one tap from the home screen.
    private var favoritesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(favPsalms, id: \.self) { n in
                NavigationLink {
                    TehillimReaderView(title: "\(app.s.psalm) \(n)", chapters: [n], onFavChange: { favPsalms = Teh.favorites })
                } label: {
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
        }
    }
}
