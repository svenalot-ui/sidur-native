import SwiftUI

struct ZmanimView: View {
    @EnvironmentObject var app: AppState

    private var rows: [ZmanRow] { app.currentZmanim.rows() }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text(app.s.zmanim)
                            .font(Typo.display(29))
                            .foregroundStyle(Palette.ink)
                        Text(app.s.zIntro)
                            .font(Typo.sans(12.5))
                            .foregroundStyle(Palette.soft)

                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                NavigationLink {
                                    ZmanDetailView(row: row)
                                } label: {
                                    rowView(row, first: idx == 0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        Text("\(app.usingMyZmanim ? "myzmanim · " : "")\(app.loc.name ?? "Jerusalem")")
                            .font(Typo.sans(11))
                            .foregroundStyle(Palette.faint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func rowView(_ row: ZmanRow, first: Bool) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 38, height: 38)
                Image(systemName: row.icon).font(.system(size: 18)).foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name(app.lang)).font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
                if app.lang != .he {
                    Text(row.he).font(Typo.serif(12)).foregroundStyle(Palette.faint)
                }
            }
            Spacer(minLength: 0)
            Text(app.fmt(row.main))
                .font(Typo.sans(16, .semibold))
                .foregroundStyle(row.main == nil ? Palette.faint : Palette.gold)
                .monospacedDigit()
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Palette.line).frame(height: 1) }
        }
        .contentShape(Rectangle())
    }
}

struct ZmanDetailView: View {
    @EnvironmentObject var app: AppState
    let row: ZmanRow

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text(row.name(app.lang))
                        .font(Typo.display(26))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 6) {
                        Text(app.fmt(row.main))
                            .font(Typo.display(46))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                        if app.lang != .he {
                            Text(row.he).font(Typo.serif(18)).foregroundStyle(Palette.gold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    HStack(spacing: 9) {
                        Text(app.s.allVariants.uppercased())
                            .font(.system(size: 10.5, weight: .medium)).tracking(2)
                            .foregroundStyle(Palette.faint)
                        Rectangle().fill(Palette.line).frame(height: 1)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(row.variants.enumerated()), id: \.element.id) { idx, v in
                            HStack {
                                Text(v.label(app.lang)).font(Typo.sans(13.5)).foregroundStyle(Palette.soft)
                                if app.lang != .he {
                                    Text(v.he).font(Typo.serif(14)).foregroundStyle(Palette.faint)
                                }
                                Spacer(minLength: 8)
                                Text(app.fmt(v.time))
                                    .font(Typo.sans(14, .medium))
                                    .foregroundStyle(v.time == nil ? Palette.faint : Palette.ink)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .top) {
                                if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
