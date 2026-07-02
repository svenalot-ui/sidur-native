import SwiftUI

// Full weekday service reader — sections stream in from Sefaria (cached on disk).
struct ServiceReaderView: View {
    @EnvironmentObject var app: AppState
    let service: ServiceKind
    let title: String

    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @AppStorage("svcMode") private var mode: String = "he"    // he | translit
    @State private var sections: [ServiceSection] = []
    @State private var loadFailed = false
    @State private var loading = true
    @State private var showSettings = false
    @State private var zen = false
    @State private var bookmarked = false

    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { mode == "he" }
    private var serviceIcon: String {
        switch service { case .shacharit: return "sun.max"; case .mincha: return "clock"; case .maariv: return "moon.stars" }
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            if loading {
                ProgressView().tint(Palette.gold)
            } else if loadFailed {
                retryState
            } else {
                VStack(spacing: 0) {
                    if !zen { langSegment }
                    ScrollView {
                        LazyVStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                            ForEach(sections) { sec in
                                SectionBlock(section: sec, mode: mode, size: size, palette: palette)
                            }
                        }
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.sm)
                        .padding(.bottom, 110)
                    }
                }
            }
        }
        .readerChrome(title: title, zen: $zen) {
            HStack(spacing: 6) {
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .task { await reload() }
        .onAppear {
            bookmarked = Bookmarks.contains(kind: "service", refId: service.rawValue)
            LastReadStore.save(kind: "service", refId: service.rawValue, title: title)
        }
    }

    private var retryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash").font(.system(size: 26)).foregroundStyle(palette.fg.opacity(0.4))
            Text(app.s.needNet).font(Typo.sans(13.5)).foregroundStyle(palette.fg.opacity(0.65))
            Button {
                Haptics.tap()
                Task { await reload() }
            } label: {
                Label(app.s.retry, systemImage: "arrow.clockwise")
                    .font(Typo.sans(13, .medium)).foregroundStyle(Palette.gold)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().strokeBorder(Palette.gold, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(Space.lg)
    }

    private func reload() async {
        loading = true
        let s = await SiddurClient.shared.sections(nusach: app.nusach ?? "ashkenaz", service: service)
        sections = s
        loadFailed = s.isEmpty
        loading = false
    }

    private var serviceNames: (ru: String, he: String) {
        switch service {
        case .shacharit: return ("Шахарит", "שַׁחֲרִית")
        case .mincha: return ("Минха", "מִנְחָה")
        case .maariv: return ("Маарив", "מַעֲרִיב")
        }
    }

    private func toggleBookmark() {
        let n = serviceNames
        Bookmarks.toggle(Bookmark(kind: "service", refId: service.rawValue, titleRu: n.ru, titleHe: n.he, icon: serviceIcon))
        bookmarked.toggle()
    }

    private var langSegment: some View {
        HStack(spacing: 6) {
            seg("he", app.s.he_)
            seg("translit", app.s.translit)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }

    private func seg(_ key: String, _ label: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { mode = key } } label: {
            Text(label)
                .font(Typo.sans(13, mode == key ? .semibold : .regular))
                .foregroundStyle(mode == key ? .white : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(mode == key ? Palette.gold : Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: mode == key ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }
}

// One service section: gold Hebrew header + streamed text.
private struct SectionBlock: View {
    @EnvironmentObject var app: AppState
    let section: ServiceSection
    let mode: String
    let size: Double
    let palette: ReaderBG

    @State private var lines: [String] = []
    @State private var loaded = false

    private var isRTL: Bool { mode == "he" }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
            if !lines.isEmpty {
                Text(isRTL ? section.heTitle : section.heTitle)
                    .font(Typo.serif(15, .semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 14)

                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(mode == "he" ? Typo.serif(size) : Typo.sans(size - 5))
                        .foregroundStyle(palette.fg)
                        .lineSpacing(9)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
            } else if !loaded {
                ProgressView().tint(Palette.gold).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
        }
        .task {
            guard lines.isEmpty else { return }
            lines = await SiddurClient.shared.text(ref: section.ref)
            loaded = true
        }
    }

    private var displayLines: [String] {
        mode == "translit" ? lines.map { Teh.translit($0) } : lines
    }
}
