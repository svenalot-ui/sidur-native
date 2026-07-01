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
                        Text(app.s.tehillim)
                            .font(Typo.display(29))
                            .foregroundStyle(Palette.ink)

                        modeSegment

                        if mode == "book" {
                            if !favs.isEmpty { favSection }
                            ForEach(0..<5, id: \.self) { bookSection($0) }
                        } else {
                            daySection
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { favs = Teh.favorites }
        }
    }

    private var modeSegment: some View {
        HStack(spacing: 6) {
            seg("book", app.s.tehBook)
            seg("day", app.s.tehByDay)
        }
    }

    private func seg(_ key: String, _ label: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { mode = key } } label: {
            Text(label)
                .font(Typo.sans(13.5, mode == key ? .semibold : .regular))
                .foregroundStyle(mode == key ? Palette.paper : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(mode == key ? Palette.ink : Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: mode == key ? 0 : 1)))
        }
        .buttonStyle(.plain)
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
                Text(app.s.bookHdr[bi]).font(Typo.display(18)).foregroundStyle(Palette.ink)
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

    // MARK: by day
    private var daySection: some View {
        let today = min(HebrewDate.dayOfMonth(), 30)
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
    let title: String
    let chapters: [Int]
    var onFavChange: () -> Void = {}

    @AppStorage("rdrMode") private var lmode: String = "he"      // he | translit | ru
    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @State private var showSettings = false
    @State private var loaded: [Int: [String]] = [:]   // psalm → hebrew lines
    @State private var loadedRu: [Int: [String]] = [:]
    @State private var loading = true
    @State private var favTick = false

    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { lmode == "he" }
    private var singlePsalm: Int? { chapters.count == 1 ? chapters[0] : nil }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                langSegment
                if loading {
                    Spacer()
                    ProgressView().tint(Palette.gold)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
                            ForEach(chapters, id: \.self) { n in
                                psalmBlock(n)
                            }
                        }
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.md)
                        .padding(.bottom, 110)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let n = singlePsalm {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Teh.toggleFav(n); favTick.toggle(); onFavChange()
                    } label: {
                        Image(systemName: Teh.favorites.contains(n) ? "heart.fill" : "heart")
                            .foregroundStyle(Palette.gold)
                    }
                    .id(favTick)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "textformat.size").foregroundStyle(Palette.gold)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        for n in chapters {
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
                Text(app.s.needNet)
                    .font(Typo.sans(13)).foregroundStyle(palette.fg.opacity(0.6))
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
        HStack(spacing: 6) {
            seg("he", app.s.he_)
            seg("translit", app.s.translit)
            seg("ru", app.s.ru_)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }

    private func seg(_ key: String, _ label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { lmode = key }
            Task { await load() }
        } label: {
            Text(label)
                .font(Typo.sans(13, lmode == key ? .semibold : .regular))
                .foregroundStyle(lmode == key ? .white : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(lmode == key ? Palette.gold : Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: lmode == key ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }
}

// Shared reader options (font size + background) — used by both readers.
struct ReaderOptionsSheet: View {
    @EnvironmentObject var app: AppState
    @Binding var size: Double
    @Binding var bgKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(app.s.fSize.uppercased()).font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(Palette.faint)
            HStack(spacing: 14) {
                sizeButton(15) { size = max(16, size - 1) }
                Text("\(Int(size)) px").font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity)
                sizeButton(23) { size = min(40, size + 1) }
            }
            Text(app.s.fBg.uppercased()).font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(Palette.faint)
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
