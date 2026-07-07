import SwiftUI

// Full weekday service reader. All section texts are prefetched (concurrently,
// disk-cached) before display — stable layout makes section jumps reliable.
struct ServiceReaderView: View {
    @EnvironmentObject var app: AppState
    let service: ServiceKind
    let title: String

    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @AppStorage("svcMode") private var storedMode: String = "he"   // he | translit
    // Transliteration is only offered on a Russian interface.
    private var showLangToggle: Bool { app.lang != .he }
    private var mode: String { showLangToggle ? storedMode : "he" }
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
    @State private var activePart: String? = nil

    // Only parts that actually have text (Sefaria has some empty placeholder nodes).
    private var parts: [ServicePart] {
        sections.parts.compactMap { part in
            let withText = part.sections.filter { !(texts[$0.ref] ?? []).isEmpty }
            guard !withText.isEmpty else { return nil }
            return ServicePart(he: part.he, en: part.en, sections: withText)
        }
    }
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
                    if !zen {
                        if showLangToggle { langSegment }
                        if parts.count > 1 { partChips.padding(.top, showLangToggle ? 0 : 12) }
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                                ForEach(parts) { part in
                                    partHeader(part)
                                        .id("part_\(part.id)")
                                        .background(GeometryReader { gp in
                                            Color.clear.preference(
                                                key: PartYKey.self,
                                                value: [part.id: gp.frame(in: .named("svcScroll")).minY])
                                        })
                                    ForEach(part.sections) { sec in
                                        sectionBlock(sec, hideTitle: part.sections.count == 1 && sec.heTitle == part.he)
                                            .id(sec.id)
                                    }
                                }
                            }
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.sm)
                            .padding(.bottom, 110)
                        }
                        .coordinateSpace(name: "svcScroll")
                        .onPreferenceChange(PartYKey.self) { ys in
                            // The active part is the last one whose header passed the top.
                            let current = parts.last(where: { (ys[$0.id] ?? .infinity) <= 150 })?.id ?? parts.first?.id
                            if current != activePart { activePart = current }
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
        .readerChrome(title: title, tint: palette.fg, zen: $zen) {
            HStack(spacing: 6) {
                ReaderIconButton(symbol: "list.bullet", tint: palette.fg, a11y: "Разделы") { showSections = true }
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", tint: palette.fg, a11y: "Закладка", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size", tint: palette.fg, a11y: "Оформление текста") { showSettings = true }
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

    // MARK: - Part navigation (chips + headers)

    /// Horizontal strip of the service's major parts — tap to jump, follows the scroll.
    private var partChips: some View {
        ScrollViewReader { chipProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(parts) { part in
                        let active = part.id == activePart
                        Button {
                            Haptics.tap()
                            if let anchor = part.anchorRef {
                                UserDefaults.standard.set(anchor, forKey: posKey)
                                pendingScroll = "part_\(part.id)"
                            }
                        } label: {
                            Text(part.he)
                                .font(Typo.serif(14.5, active ? .semibold : .regular))
                                .foregroundStyle(active ? palette.bg : palette.fg.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule()
                                    .fill(active ? Palette.gold : palette.fg.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(palette.fg.opacity(active ? 0 : 0.12), lineWidth: 1)))
                        }
                        .buttonStyle(.plain)
                        .id("chip_\(part.id)")
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, 10)
            }
            .onChange(of: activePart) { p in
                guard let p else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    chipProxy.scrollTo("chip_\(p)", anchor: .center)
                }
            }
        }
    }

    /// Ornamental header opening a major part of the service.
    @ViewBuilder
    private func partHeader(_ part: ServicePart) -> some View {
        if parts.count > 1 {
            VStack(spacing: 3) {
                HStack(spacing: 12) {
                    line(leading: true)
                    Text(part.he)
                        .font(Typo.serif(20, .semibold))
                        .foregroundStyle(Palette.gold)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    line(leading: false)
                }
                if app.lang != .he && !part.en.isEmpty {
                    Text(part.en)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.8)
                        .foregroundStyle(palette.fg.opacity(0.45))
                        .textCase(.uppercase)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.bottom, 4)
        }
    }

    private func line(leading: Bool) -> some View {
        LinearGradient(
            colors: leading ? [.clear, Palette.goldL.opacity(0.6)] : [Palette.goldL.opacity(0.6), .clear],
            startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .frame(maxWidth: 70)
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
    private func sectionBlock(_ sec: ServiceSection, hideTitle: Bool = false) -> some View {
        let lines = texts[sec.ref] ?? []
        if !lines.isEmpty {
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                if !hideTitle {
                    Text(sec.heTitle)
                        .font(Typo.serif(15, .semibold))
                        .foregroundStyle(Palette.gold.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                }

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

    // Table of contents — parts (ornamental headers) with their sections on a gold
    // spine; the current spot is highlighted. Tap any to jump (with a light tap).
    private var sectionsSheet: some View {
        let current = UserDefaults.standard.string(forKey: posKey)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(parts) { part in
                        HStack(spacing: 10) {
                            Rectangle().fill(Palette.goldL.opacity(0.5)).frame(width: 20, height: 1)
                            Text(part.he)
                                .font(Typo.serif(17, .semibold)).foregroundStyle(Palette.gold)
                                .lineLimit(1)
                            if app.lang != .he && !part.en.isEmpty {
                                Text(part.en)
                                    .font(Typo.label(9)).tracking(1.2)
                                    .foregroundStyle(Palette.faint).textCase(.uppercase)
                            }
                            Rectangle().fill(Palette.line).frame(height: 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 22).padding(.bottom, 8)

                        ForEach(part.sections) { sec in
                            let isCurrent = sec.id == current
                            Button {
                                Haptics.tap()
                                UserDefaults.standard.set(sec.id, forKey: posKey)
                                showSections = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pendingScroll = sec.id }
                            } label: {
                                HStack(spacing: 13) {
                                    ZStack {
                                        Circle()
                                            .fill(isCurrent ? Palette.gold : Palette.card)
                                            .overlay(Circle().strokeBorder(isCurrent ? Palette.gold : Palette.line, lineWidth: 1.5))
                                            .frame(width: 11, height: 11)
                                    }
                                    Text(sec.heTitle)
                                        .font(Typo.serif(16.5, isCurrent ? .semibold : .regular))
                                        .foregroundStyle(isCurrent ? Palette.gold : Palette.ink)
                                    Spacer(minLength: 8)
                                    if app.lang != .he {
                                        Text(sec.enTitle)
                                            .font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
                                            .lineLimit(1)
                                    }
                                    if isCurrent {
                                        Image(systemName: "location.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Palette.gold.opacity(0.09) : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
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
        Segmented(items: [
            .init(label: app.s.he_, active: mode == "he") { storedMode = "he" },
            .init(label: app.s.translit, active: mode == "translit") { storedMode = "translit" },
        ], ink: palette.fg, muted: palette.fg.opacity(0.5), baseline: palette.fg.opacity(0.18))
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
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

// Tracks part-header scroll positions to highlight the active chip.
private struct PartYKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}
