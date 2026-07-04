import SwiftUI

// Full weekday service reader. All section texts are prefetched (concurrently,
// disk-cached) before display — stable layout makes section jumps reliable.
struct ServiceReaderView: View {
    @EnvironmentObject var app: AppState
    let service: ServiceKind
    let title: String

    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @AppStorage("svcMode") private var mode: String = "he"    // he | translit
    @State private var sections: [ServiceSection] = []
    @State private var texts: [String: [String]] = [:]        // ref → hebrew paragraphs
    @State private var loadFailed = false
    @State private var loading = true
    @State private var progress = 0
    @State private var showSettings = false
    @State private var showSections = false
    @State private var zen = false
    @State private var bookmarked = false
    @State private var pendingScroll: String? = nil

    private var posKey: String { "svcPos_\(service.rawValue)" }

    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { mode == "he" }
    private var serviceIcon: String {
        switch service { case .shacharit: return "sun.max"; case .mincha: return "clock"; case .maariv: return "moon.stars" }
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            if loading {
                VStack(spacing: 10) {
                    ProgressView().tint(Palette.gold)
                    if !sections.isEmpty {
                        Text("\(progress)/\(sections.count)")
                            .font(Typo.sans(12)).foregroundStyle(palette.fg.opacity(0.5)).monospacedDigit()
                    }
                }
            } else if loadFailed {
                retryState
            } else {
                VStack(spacing: 0) {
                    if !zen { langSegment }
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                                ForEach(sections) { sec in
                                    sectionBlock(sec)
                                        .id(sec.id)
                                }
                            }
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.sm)
                            .padding(.bottom, 110)
                        }
                        .onChange(of: pendingScroll) { target in
                            guard let target else { return }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                            DispatchQueue.main.async { pendingScroll = nil }
                        }
                    }
                }
            }
        }
        .readerChrome(title: title, zen: $zen) {
            HStack(spacing: 6) {
                ReaderIconButton(symbol: "list.bullet") { showSections = true }
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSections) {
            sectionsSheet
                .presentationDetents([.medium, .large])
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
        progress = 0
        let secs = await SiddurClient.shared.sections(nusach: app.nusach ?? "ashkenaz", service: service)
        sections = secs
        guard !secs.isEmpty else {
            loadFailed = true
            loading = false
            return
        }
        // Prefetch every section concurrently (6 at a time) — instant from disk cache afterwards.
        var loadedTexts: [String: [String]] = [:]
        await withTaskGroup(of: (String, [String]).self) { group in
            var iterator = secs.makeIterator()
            func addNext(_ group: inout TaskGroup<(String, [String])>) {
                if let sec = iterator.next() {
                    group.addTask { (sec.ref, await SiddurClient.shared.text(ref: sec.ref)) }
                }
            }
            for _ in 0..<6 { addNext(&group) }
            for await (ref, lines) in group {
                loadedTexts[ref] = lines
                progress = loadedTexts.count
                addNext(&group)
            }
        }
        texts = loadedTexts
        // A service with no text at all → network problem.
        loadFailed = loadedTexts.values.allSatisfy { $0.isEmpty }
        loading = false
        // Restore the last section the user jumped to.
        if !loadFailed,
           let saved = UserDefaults.standard.string(forKey: posKey),
           secs.contains(where: { $0.id == saved }) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            pendingScroll = saved
        }
    }

    @ViewBuilder
    private func sectionBlock(_ sec: ServiceSection) -> some View {
        let lines = texts[sec.ref] ?? []
        if !lines.isEmpty {
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                Text(sec.heTitle)
                    .font(Typo.serif(15, .semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 14)

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(mode == "translit" ? Teh.translit(line) : line)
                        .font(mode == "he" ? Typo.serif(size) : Typo.sans(size - 5))
                        .foregroundStyle(palette.fg)
                        .lineSpacing(9)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
            }
        }
    }

    // Table of contents — jump to any section of the service.
    private var sectionsSheet: some View {
        NavigationStack {
            ScrollView {
                let current = UserDefaults.standard.string(forKey: posKey)
                VStack(spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { idx, sec in
                        let isCurrent = sec.id == current
                        Button {
                            Haptics.tap()
                            UserDefaults.standard.set(sec.id, forKey: posKey)
                            showSections = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                pendingScroll = sec.id
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(Typo.digits(13)).foregroundStyle(Palette.faint).monospacedDigit()
                                    .frame(width: 26, alignment: .trailing)
                                Text(sec.heTitle)
                                    .font(Typo.serif(16, isCurrent ? .semibold : .regular))
                                    .foregroundStyle(isCurrent ? Palette.gold : Palette.ink)
                                if isCurrent {
                                    Circle().fill(Palette.gold).frame(width: 5, height: 5)
                                }
                                Spacer(minLength: 8)
                                if app.lang != .he {
                                    Text(sec.enTitle)
                                        .font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(isCurrent ? Palette.cream.opacity(0.6) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 18) }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Palette.paper)
            .navigationTitle(app.s.sections)
            .navigationBarTitleDisplayMode(.inline)
        }
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
}
