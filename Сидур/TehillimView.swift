import SwiftUI

struct TehillimView: View {
    @EnvironmentObject var app: AppState
    @State private var mode = "book"          // book | day
    @State private var favs: [Int] = Teh.favorites

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        ScreenTitle(text: app.s.tehillim)

                        modeSegment

                        if mode == "book" {
                            if !favs.isEmpty { favSection }
                            ForEach(0..<5, id: \.self) { bookSection($0) }
                        } else if mode == "day" {
                            daySection
                        } else {
                            segulotSection
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, 6)
                }
                .statusBarMask()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { favs = Teh.favorites }
        }
    }

    private var modeSegment: some View {
        Segmented(items: [
            .init(label: app.s.tehBook, active: mode == "book") { mode = "book" },
            .init(label: app.s.tehByDay, active: mode == "day") { mode = "day" },
            .init(label: app.s.segulot, active: mode == "seg") { mode = "seg" },
        ])
    }

    // MARK: favorites
    private var favSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.system(size: 15)).foregroundStyle(Palette.gold)
                Text(app.s.tehFavTitle).font(Typo.display(18)).foregroundStyle(Palette.ink)
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            grid(favs)
        }
        .padding(.bottom, Space.xs)
    }

    // MARK: books
    private func bookSection(_ bi: Int) -> some View {
        let rng = Teh.books[bi]
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 10) {
                Text(Teh.bookNumerals[bi])
                    .font(Typo.serif(13, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing)))
                Text(app.s.bookHdr[bi]).font(displayFont(18, app.lang)).foregroundStyle(Palette.ink)
                Text("\(rng.from)–\(rng.to)").font(Typo.sans(11.5)).foregroundStyle(Palette.gold).monospacedDigit()
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            grid(Array(rng.from...rng.to))
        }
        .padding(.bottom, Space.xs)
    }

    private func grid(_ nums: [Int]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(nums, id: \.self) { n in
                NavigationLink {
                    TehillimReaderView(title: "\(app.s.psalm) \(n)", chapters: [n], onFavChange: { favs = Teh.favorites })
                } label: {
                    numCell(n)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func numCell(_ n: Int) -> some View {
        let fav = favs.contains(n)
        return Text("\(n)")
            .font(Typo.serif(16, .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(fav ? Palette.cream : Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(fav ? Palette.gold : Palette.line, lineWidth: 1)))
            .overlay(alignment: .topTrailing) {
                if fav { Circle().fill(Palette.gold).frame(width: 6, height: 6).padding(6) }
            }
    }

    // MARK: segulot
    private var segulotSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(app.s.segIntro)
                .font(Typo.sans(12.5)).foregroundStyle(Palette.soft)
                .padding(.bottom, 2)
            ForEach(Teh.segulot) { s in
                NavigationLink {
                    TehillimReaderView(
                        title: s.name(app.lang),
                        chapters: s.psalms,
                        intro: s.desc(app.lang),
                        onFavChange: { favs = Teh.favorites })
                } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 40, height: 40)
                            Image(systemName: s.icon).font(.system(size: 17)).foregroundStyle(Palette.gold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name(app.lang)).font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
                            Text("\(app.s.psalm): \(s.psalms.map(String.init).joined(separator: " · "))")
                                .font(Typo.sans(12)).foregroundStyle(Palette.gold).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
                    }
                    .padding(15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: by day
    private var daySection: some View {
        let today = min(HebrewDate.dayOfMonth(tz: app.tz), 30)
        return VStack(spacing: 0) {
            ForEach(1...30, id: \.self) { day in
                let ch = Teh.chapters(day: day)
                NavigationLink {
                    TehillimReaderView(title: "\(app.s.tehDay) \(day)", chapters: ch, onFavChange: { favs = Teh.favorites })
                } label: {
                    HStack(spacing: 13) {
                        Text("\(day)")
                            .font(Typo.serif(19, .bold))
                            .foregroundStyle(day == today ? .white : Palette.gold)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(day == today ? Palette.gold : Palette.cream))
                        Text("\(app.s.tehDay) \(day)").font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        Text(ch.count == 1 ? "\(ch[0])" : "\(ch.first!)–\(ch.last!)")
                            .font(Typo.sans(13.5)).foregroundStyle(Palette.soft).monospacedDigit()
                        Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(day == today ? Palette.cream.opacity(0.6) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if day > 1 { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 16) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Psalm reader (fetched text, same reading options as ReaderView)
struct TehillimReaderView: View {
    @EnvironmentObject var app: AppState
    let baseTitle: String
    let intro: String?
    let onFavChange: () -> Void

    init(title: String, chapters: [Int], intro: String? = nil, onFavChange: @escaping () -> Void = {}) {
        self.baseTitle = title
        self.intro = intro
        self.onFavChange = onFavChange
        _psalms = State(initialValue: chapters)
    }

    @AppStorage("rdrMode") private var storedMode: String = "he"  // he | translit | ru
    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @State private var psalms: [Int]
    @State private var showSettings = false
    @State private var showPicker = false
    @State private var loaded: [Int: [String]] = [:]   // psalm → hebrew lines
    @State private var loadedRu: [Int: [String]] = [:]
    @State private var loading = true
    @State private var favTick = false
    @State private var zen = false
    @State private var scrollPos: Int?

    private var showLangToggle: Bool { app.lang != .he }
    private var lmode: String { showLangToggle ? storedMode : "he" }
    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { lmode == "he" }
    private var singlePsalm: Int? { psalms.count == 1 ? psalms[0] : nil }
    private var displayTitle: String { singlePsalm != nil ? "\(app.s.psalm) \(singlePsalm!)" : baseTitle }
    private var posKey: String { "teh_\(psalms.first ?? 0)_\(psalms.count)" }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if !zen && showLangToggle { langSegment }
                if loading {
                    Spacer()
                    ProgressView().tint(Palette.gold)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
                            if let intro {
                                Text(intro)
                                    .font(Typo.sans(13))
                                    .foregroundStyle(palette.fg.opacity(0.65))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 6)
                            }
                            ForEach(psalms, id: \.self) { n in
                                psalmBlock(n)
                            }
                        }
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.md)
                        .padding(.bottom, 110)
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $scrollPos, anchor: .top)
                }
            }
            if let n = singlePsalm, !zen { psalmNavBar(n) }
        }
        .readerChrome(title: displayTitle, tint: palette.fg, zen: $zen) {
            HStack(spacing: 6) {
                if let n = singlePsalm {
                    ReaderIconButton(symbol: Teh.favorites.contains(n) ? "heart.fill" : "heart", tint: palette.fg, a11y: "В избранное") {
                        Teh.toggleFav(n); favTick.toggle(); onFavChange()
                    }
                    .id(favTick)
                }
                ReaderIconButton(symbol: "textformat.size", tint: palette.fg, a11y: "Оформление текста") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPicker) { psalmPicker }
        .onChange(of: scrollPos) { _, new in
            if let new { ReadPos.save(posKey, new) }
        }
        .task {
            await load()
            if let n = singlePsalm {
                LastReadStore.save(kind: "psalm", refId: "\(n)", title: displayTitle)
            }
            if let saved = ReadPos.get(posKey) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                scrollPos = saved
            }
        }
    }

    // MARK: - Psalm navigation (single-psalm reading)

    private func goTo(_ n: Int) {
        let c = min(max(n, 1), 150)
        guard c != singlePsalm else { return }
        Haptics.tap()
        scrollPos = nil
        psalms = [c]
        Task {
            await load()
            LastReadStore.save(kind: "psalm", refId: "\(c)", title: displayTitle)
            onFavChange()
        }
    }

    private func psalmNavBar(_ n: Int) -> some View {
        HStack(spacing: 0) {
            navArrow("chevron.left", enabled: n > 1) { goTo(n - 1) }
            Button {
                Haptics.tap(); showPicker = true
            } label: {
                Text("\(app.s.psalm) \(n)")
                    .font(Typo.serif(15, .semibold)).foregroundStyle(palette.fg)
                    .frame(minWidth: 96)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            navArrow("chevron.right", enabled: n < 150) { goTo(n + 1) }
        }
        .background(Capsule().fill(.ultraThinMaterial)
            .overlay(Capsule().strokeBorder(palette.fg.opacity(0.12), lineWidth: 1)))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 28)
    }

    private func navArrow(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Palette.gold : palette.fg.opacity(0.25))
                .frame(width: 46, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var psalmPicker: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(1...150, id: \.self) { p in
                        Button {
                            showPicker = false
                            goTo(p)
                        } label: {
                            Text("\(p)")
                                .font(Typo.serif(16, .semibold))
                                .foregroundStyle(p == singlePsalm ? .white : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(p == singlePsalm ? Palette.gold : Palette.card)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: 1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Space.lg)
            }
            .background(Palette.paper)
            .navigationTitle(app.s.tehillim)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func load() async {
        loading = true
        for n in psalms {
            if loaded[n] == nil { loaded[n] = await TehTexts.shared.hebrew(n) ?? [] }
            if lmode == "ru", loadedRu[n] == nil { loadedRu[n] = await TehTexts.shared.russian(n) ?? [] }
        }
        loading = false
    }

    @ViewBuilder
    private func psalmBlock(_ n: Int) -> some View {
        let he = loaded[n] ?? []
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
            Text("\(app.s.psalm) \(n)")
                .font(Typo.serif(15, .semibold))
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)

            if he.isEmpty {
                Button {
                    Haptics.tap()
                    Task { loaded[n] = await TehTexts.shared.hebrew(n) ?? [] }
                } label: {
                    Label(app.s.needNet, systemImage: "arrow.clockwise")
                        .font(Typo.sans(13)).foregroundStyle(palette.fg.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(lines(n).enumerated()), id: \.offset) { i, line in
                    (Text("\(i + 1)  ").font(Typo.serif(size * 0.55)).foregroundColor(Palette.gold)
                     + Text(line).font(lmode == "he" ? Typo.serif(size) : Typo.sans(size - 4)).foregroundColor(palette.fg))
                        .lineSpacing(9)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
            }
        }
    }

    private func lines(_ n: Int) -> [String] {
        let he = loaded[n] ?? []
        switch lmode {
        case "ru":
            let ru = loadedRu[n] ?? []
            return ru.isEmpty ? he.map { Teh.translit($0) } : ru
        case "translit":
            return he.map { Teh.translit($0) }
        default:
            return he
        }
    }

    private var langSegment: some View {
        Segmented(items: [
            .init(label: app.s.he_, active: lmode == "he") { storedMode = "he"; Task { await load() } },
            .init(label: app.s.translit, active: lmode == "translit") { storedMode = "translit"; Task { await load() } },
            .init(label: app.s.ru_, active: lmode == "ru") { storedMode = "ru"; Task { await load() } },
        ], ink: palette.fg, muted: palette.fg.opacity(0.5), baseline: palette.fg.opacity(0.18))
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }
}

// Shared reader options (font size + background) — used by both readers.
struct ReaderOptionsSheet: View {
    @EnvironmentObject var app: AppState
    @Binding var size: Double
    @Binding var bgKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(app.s.fSize.uppercased()).font(Typo.label(10.5)).tracking(1.5).foregroundStyle(Palette.faint)
            HStack(spacing: 14) {
                sizeButton(15) { size = max(16, size - 1) }
                Text("\(Int(size)) px").font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity)
                sizeButton(23) { size = min(40, size + 1) }
            }
            Text(app.s.fBg.uppercased()).font(Typo.label(10.5)).tracking(1.5).foregroundStyle(Palette.faint)
            HStack(spacing: 10) {
                bgSwatch("paper", app.s.bgPaper)
                bgSwatch("sepia", app.s.bgSepia)
                bgSwatch("white", app.s.bgWhite)
                bgSwatch("night", app.s.bgNight)
            }
            Spacer()
        }
        .padding(Space.lg)
        .presentationBackground(Palette.card)
    }

    private func sizeButton(_ fontSize: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("A").font(Typo.serif(fontSize, .semibold)).foregroundStyle(Palette.ink)
                .frame(width: 54, height: 46)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func bgSwatch(_ key: String, _ name: String) -> some View {
        let p = ReaderBG.get(key)
        return Button { bgKey = key } label: {
            VStack(spacing: 5) {
                Text("א")
                    .font(Typo.serif(18))
                    .foregroundStyle(p.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(p.bg))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(bgKey == key ? Palette.gold : Palette.line, lineWidth: bgKey == key ? 2 : 1))
                Text(name).font(.system(size: 10)).foregroundStyle(Palette.faint)
            }
        }
        .buttonStyle(.plain)
    }
}
