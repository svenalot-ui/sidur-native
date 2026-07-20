import SwiftUI

// A full prayer service bundled in-app (three versions: Hebrew / transliteration /
// Russian), organised into parts and blocks. Conditional inserts (seasonal,
// Rosh Chodesh / Chol HaMoed, Chanukah / Purim, fast days…) are flagged so the
// reader can highlight them.
struct BundledService: Codable {
    let id: String
    let titleHe: String
    let titleRu: String
    let parts: [Part]

    struct Part: Codable, Identifiable {
        let he: String
        let ru: String
        let blocks: [Block]
        var id: String { (ru.isEmpty ? he : ru) + he }
        func name(_ lang: Lang) -> String { lang == .he ? he : (ru.isEmpty ? he : ru) }
    }

    struct Block: Codable {
        let k: String            // body | rubric | sub
        let he: String
        let translit: String
        let ru: String
        let insert: Bool?
        var isInsert: Bool { insert == true }
    }

    static func load(_ id: String) -> BundledService? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(BundledService.self, from: data) else { return nil }
        return s
    }
    static func exists(_ id: String) -> Bool {
        Bundle.main.url(forResource: id, withExtension: "json") != nil
    }
}

// Scroll-progress + content-height preference keys.
private struct SvcOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct SvcHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct PartTopKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// Reader for a bundled service — beautiful part navigation + a reading-progress bar.
struct BundledServiceReaderView: View {
    @EnvironmentObject var app: AppState
    let service: BundledService
    let title: String
    let icon: String

    @AppStorage("svcMode") private var storedMode: String = "he"   // he | translit | ru
    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @State private var zen = false
    @State private var bookmarked = false
    @State private var showSections = false
    @State private var showSettings = false
    @State private var activePart: String?
    @State private var pendingScroll: String?
    @State private var progress: CGFloat = 0
    @State private var viewportH: CGFloat = 1
    @State private var contentH: CGFloat = 1

    private var showLangToggle: Bool { app.lang != .he }
    private var mode: String { showLangToggle ? storedMode : "he" }
    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { mode == "he" }
    private var posKey: String { "svcpos_\(service.id)" }

    var body: some View {
        ZStack(alignment: .top) {
            palette.bg.ignoresSafeArea()
            content
            if !zen { progressBar }
        }
        .readerChrome(title: title, tint: palette.fg, zen: $zen) {
            HStack(spacing: 6) {
                if service.parts.count > 1 {
                    ReaderIconButton(symbol: "list.bullet", tint: palette.fg, a11y: "Разделы") { showSections = true }
                }
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", tint: palette.fg, a11y: "Закладка", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size", tint: palette.fg, a11y: "Оформление текста") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSections) {
            sectionsSheet.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .onAppear {
            bookmarked = Bookmarks.contains(kind: "service", refId: service.id)
            LastReadStore.save(kind: "service", refId: service.id, title: title)
        }
    }

    // MARK: content

    private var content: some View {
        GeometryReader { outer in
            VStack(spacing: 0) {
                if !zen {
                    if showLangToggle { langSegment }
                    if service.parts.count > 1 { partChips }
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
                            ForEach(Array(service.parts.enumerated()), id: \.element.id) { _, part in
                                partHeader(part)
                                    .id(part.id)
                                    .background(GeometryReader { gp in
                                        Color.clear.preference(key: PartTopKey.self,
                                            value: [part.id: gp.frame(in: .named("svc")).minY])
                                    })
                                ForEach(Array(part.blocks.enumerated()), id: \.offset) { _, b in
                                    blockView(b)
                                }
                            }
                        }
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.sm)
                        .padding(.bottom, 120)
                        .background(GeometryReader { g in
                            Color.clear
                                .preference(key: SvcOffsetKey.self, value: g.frame(in: .named("svc")).minY)
                                .preference(key: SvcHeightKey.self, value: g.size.height)
                        })
                    }
                    .coordinateSpace(name: "svc")
                    .onPreferenceChange(SvcOffsetKey.self) { minY in
                        let denom = max(contentH - viewportH, 1)
                        progress = min(max(-minY / denom, 0), 1)
                    }
                    .onPreferenceChange(SvcHeightKey.self) { contentH = $0 }
                    .onPreferenceChange(PartTopKey.self) { ys in
                        let cur = service.parts.last(where: { (ys[$0.id] ?? .infinity) <= 140 })?.id ?? service.parts.first?.id
                        if cur != activePart { activePart = cur }
                    }
                    .onChange(of: pendingScroll) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .top) }
                        DispatchQueue.main.async { pendingScroll = nil }
                    }
                }
            }
            .onAppear { viewportH = outer.size.height }
            .onChange(of: outer.size.height) { _, h in viewportH = h }
        }
    }

    // A slim reading-progress bar just under the chrome.
    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(palette.fg.opacity(0.08)).frame(height: 2.5)
                Rectangle().fill(Palette.gold).frame(width: g.size.width * progress, height: 2.5)
            }
        }
        .frame(height: 2.5)
    }

    // MARK: blocks

    @ViewBuilder
    private func blockView(_ b: BundledService.Block) -> some View {
        switch b.k {
        case "sub":
            Text(b.he)
                .font(Typo.serif(17, .semibold))
                .foregroundStyle(Palette.gold.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
        case "rubric":
            Text(text(b))
                .font(Typo.sans(12.5).italic())
                .foregroundStyle(b.isInsert ? Palette.gold : palette.fg.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.vertical, 3)
        default:
            bodyText(b)
        }
    }

    @ViewBuilder
    private func bodyText(_ b: BundledService.Block) -> some View {
        let t = Text(text(b))
            .font(mode == "he" ? Typo.serif(size) : Typo.sans(size - 5))
            .foregroundStyle(palette.fg)
            .lineSpacing(9)
        if b.isInsert {
            t.frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.gold.opacity(0.07)))
                .overlay(alignment: isRTL ? .trailing : .leading) {
                    Rectangle().fill(Palette.gold.opacity(0.6)).frame(width: 2.5)
                }
        } else {
            t.frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
    }

    private func text(_ b: BundledService.Block) -> String {
        switch mode {
        case "translit": return b.translit.isEmpty ? b.he : b.translit
        case "ru": return b.ru.isEmpty ? b.he : b.ru
        default: return b.he
        }
    }

    // MARK: part navigation

    @ViewBuilder
    private func partHeader(_ part: BundledService.Part) -> some View {
        if service.parts.count > 1 {
        VStack(spacing: 3) {
            HStack(spacing: 12) {
                line(true)
                Text(part.he.isEmpty ? part.name(app.lang) : part.he)
                    .font(Typo.serif(21, .semibold))
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                line(false)
            }
            if app.lang != .he && !part.ru.isEmpty {
                Text(part.ru)
                    .font(Typo.label(9.5)).tracking(1.5)
                    .foregroundStyle(palette.fg.opacity(0.45)).textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26).padding(.bottom, 4)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private func line(_ leading: Bool) -> some View {
        LinearGradient(colors: leading ? [.clear, Palette.goldL.opacity(0.6)] : [Palette.goldL.opacity(0.6), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1).frame(maxWidth: 60)
    }

    private var partChips: some View {
        ScrollViewReader { chip in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(service.parts) { part in
                        let active = part.id == activePart
                        Button {
                            Haptics.tap(); pendingScroll = part.id
                        } label: {
                            Text(part.name(app.lang))
                                .font(Typo.sans(13, active ? .semibold : .regular))
                                .foregroundStyle(active ? palette.bg : palette.fg.opacity(0.7))
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(Capsule().fill(active ? Palette.gold : palette.fg.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(palette.fg.opacity(active ? 0 : 0.12), lineWidth: 1)))
                        }
                        .buttonStyle(.plain)
                        .id("chip_\(part.id)")
                    }
                }
                .padding(.horizontal, Space.lg).padding(.bottom, 10).padding(.top, showLangToggle ? 0 : 12)
            }
            .onChange(of: activePart) { _, p in
                guard let p else { return }
                withAnimation(.easeInOut(duration: 0.25)) { chip.scrollTo("chip_\(p)", anchor: .center) }
            }
        }
    }

    private var sectionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(service.parts) { part in
                        Button {
                            Haptics.tap(); showSections = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pendingScroll = part.id }
                        } label: {
                            HStack(spacing: 13) {
                                Circle().fill(part.id == activePart ? Palette.gold : Palette.line)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(part.he).font(Typo.serif(17, .semibold)).foregroundStyle(Palette.gold)
                                    if app.lang != .he && !part.ru.isEmpty {
                                        Text(part.ru).font(Typo.sans(12)).foregroundStyle(Palette.faint)
                                    }
                                }
                                Spacer(minLength: 0)
                                if part.id == activePart {
                                    Image(systemName: "location.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 12).fill(part.id == activePart ? Palette.gold.opacity(0.09) : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Palette.paper)
            .navigationTitle(app.s.sections)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var langSegment: some View {
        Segmented(items: [
            .init(label: app.s.he_, active: mode == "he") { storedMode = "he" },
            .init(label: app.s.translit, active: mode == "translit") { storedMode = "translit" },
            .init(label: app.s.ru_, active: mode == "ru") { storedMode = "ru" },
        ], ink: palette.fg, muted: palette.fg.opacity(0.5), baseline: palette.fg.opacity(0.18))
        .padding(.horizontal, Space.lg).padding(.vertical, 12)
    }

    private func toggleBookmark() {
        Bookmarks.toggle(Bookmark(kind: "service", refId: service.id, titleRu: service.titleRu, titleHe: service.titleHe, icon: icon))
        bookmarked.toggle()
    }
}
