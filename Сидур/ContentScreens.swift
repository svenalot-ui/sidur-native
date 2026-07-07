import SwiftUI

// Shared building blocks for content list screens.
struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .font(Typo.label(10.5)).tracking(1.8)
                .foregroundStyle(Palette.faint)
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .padding(.top, Space.sm)
    }
}

struct TextRow: View {
    @EnvironmentObject var app: AppState
    let item: SacredText
    let first: Bool
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 40, height: 40)
                Image(systemName: item.icon).font(.system(size: 19)).foregroundStyle(item.ready ? Palette.gold : Palette.faint)
            }
            Text(item.name(app.lang))
                .font(Typo.sans(15, .medium)).foregroundStyle(item.ready ? Palette.ink : Palette.faint)
            Spacer(minLength: 0)
            if !item.ready {
                Text(app.s.soonBadge.uppercased())
                    .font(Typo.label(9)).tracking(1).foregroundStyle(Palette.faint)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().strokeBorder(Palette.line, lineWidth: 1))
            } else {
                if app.lang != .he {
                    Text(item.he).font(Typo.serif(16)).foregroundStyle(Palette.ink)
                }
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Palette.line).frame(height: 1) } }
        .contentShape(Rectangle())
    }
}

// A text row that navigates when ready, or sits as a "Скоро" placeholder otherwise.
struct LiturgyRow: View {
    let item: SacredText
    let first: Bool
    var body: some View {
        if item.ready {
            NavigationLink { ReaderView(text: item) } label: { TextRow(item: item, first: first) }
                .buttonStyle(.plain)
        } else {
            TextRow(item: item, first: first)
        }
    }
}

struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: Brachot
struct BrachotView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        ScreenTitle(text: app.s.brachot)

                        SectionLabel(text: app.s.often)
                        GroupCard {
                            ForEach(Array(Liturgy.brachotOften.enumerated()), id: \.element.id) { idx, it in
                                LiturgyRow(item: it, first: idx == 0)
                            }
                        }

                        SectionLabel(text: app.s.brachotMore)
                        ForEach(Liturgy.brachotFolders) { folder in
                            NavigationLink { BrachotFolderView(folder: folder) } label: { folderCard(folder) }
                                .buttonStyle(.plain)
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Space.lg).padding(.top, 6)
                }
                .statusBarMask()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func folderCard(_ folder: LiturgyFolder) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Palette.cream).frame(width: 46, height: 46)
                Image(systemName: folder.icon).font(.system(size: 20)).foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name(app.lang)).font(Typo.sans(16, .semibold)).foregroundStyle(Palette.ink)
                Text("\(folder.items.count)").font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
                    + Text(app.lang == .he ? " ברכות" : " шт.").font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 0)
            if app.lang != .he {
                Text(folder.he).font(Typo.serif(15)).foregroundStyle(Palette.faint)
            }
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
        .contentShape(Rectangle())
    }
}

// Drill-in list of one blessing folder.
struct BrachotFolderView: View {
    @EnvironmentObject var app: AppState
    let folder: LiturgyFolder
    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    GroupCard {
                        ForEach(Array(folder.items.enumerated()), id: \.element.id) { idx, it in
                            LiturgyRow(item: it, first: idx == 0)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Space.lg).padding(.top, Space.sm)
            }
        }
        .navigationTitle(folder.name(app.lang))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Prayers
struct PrayersView: View {
    @EnvironmentObject var app: AppState

    // Daily services — full texts fetched per-nusach from Sefaria.
    private var daily: [(kind: ServiceKind, name: String, he: String, icon: String)] {
        [(.shacharit, app.s.sh, "שַׁחֲרִית", "sun.max"),
         (.mincha, app.s.mi, "מִנְחָה", "clock"),
         (.maariv, app.s.ma, "מַעֲרִיב", "moon.stars")]
    }

    private var nusachName: String {
        Nusach(rawValue: app.nusach ?? "")?.name(app.lang) ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        ScreenTitle(text: app.s.prayers)

                        SectionLabel(text: app.s.daily)
                        GroupCard {
                            ForEach(Array(daily.enumerated()), id: \.offset) { idx, d in
                                NavigationLink {
                                    ServiceReaderView(service: d.kind, title: d.name)
                                } label: {
                                    HStack(spacing: 13) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 40, height: 40)
                                            Image(systemName: d.icon).font(.system(size: 19)).foregroundStyle(Palette.gold)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(d.name).font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
                                            if !nusachName.isEmpty {
                                                Text(nusachName).font(Typo.sans(11)).foregroundStyle(Palette.faint)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        if app.lang != .he {
                                            Text(d.he).font(Typo.serif(16)).foregroundStyle(Palette.ink)
                                        }
                                        Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
                                    }
                                    .padding(.horizontal, 18).padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .top) { if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1) } }
                            }
                        }

                        SectionLabel(text: app.s.personal)
                        GroupCard {
                            ForEach(Array(Liturgy.personal.enumerated()), id: \.element.id) { idx, it in
                                LiturgyRow(item: it, first: idx == 0)
                            }
                        }

                        SectionLabel(text: Liturgy.havdalah.name(app.lang))
                        GroupCard { LiturgyRow(item: Liturgy.havdalah, first: true) }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Space.lg).padding(.top, 6)
                }
                .statusBarMask()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
