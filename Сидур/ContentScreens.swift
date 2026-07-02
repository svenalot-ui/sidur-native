import SwiftUI

// Shared building blocks for content list screens.
struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Text(text.uppercased())
                .font(.system(size: 10.5, weight: .medium)).tracking(2)
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
                Image(systemName: item.icon).font(.system(size: 19)).foregroundStyle(Palette.gold)
            }
            Text(item.ru == item.name(app.lang) ? item.ru : item.name(app.lang))
                .font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            if app.lang != .he {
                Text(item.he).font(Typo.serif(16)).foregroundStyle(Palette.ink)
            }
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Palette.line).frame(height: 1) } }
        .contentShape(Rectangle())
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
                        Text(app.s.brachot).font(Typo.display(29)).foregroundStyle(Palette.ink)
                        section(app.s.often, Liturgy.brachotOften)
                        section(app.s.beforeEat, Liturgy.brachotBefore)
                        section(app.s.afterEat, Liturgy.brachotAfter)
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Space.lg).padding(.top, Space.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func section(_ label: String, _ items: [SacredText]) -> some View {
        SectionLabel(text: label)
        GroupCard {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, it in
                NavigationLink { ReaderView(text: it) } label: { TextRow(item: it, first: idx == 0) }
                    .buttonStyle(.plain)
            }
        }
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
                        Text(app.s.prayers).font(Typo.display(29)).foregroundStyle(Palette.ink)

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
                                NavigationLink { ReaderView(text: it) } label: { TextRow(item: it, first: idx == 0) }
                                    .buttonStyle(.plain)
                            }
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Space.lg).padding(.top, Space.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
