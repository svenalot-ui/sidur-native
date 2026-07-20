import SwiftUI

struct ZmanimView: View {
    @EnvironmentObject var app: AppState

    private var rows: [ZmanRow] { app.currentZmanim.rows() }

    // The time to display for a row — the user's chosen variant, or the default.
    private func displayed(_ row: ZmanRow) -> Date? {
        let vk = ZmanDisplay.get(row.id) ?? row.variants.first?.key
        return vk.flatMap { app.currentZmanim.t($0) } ?? row.main
    }

    // First zman still ahead of us today → highlighted as "next".
    private var nextId: String? {
        let now = Date()
        return rows.first { (displayed($0) ?? .distantPast) > now }?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        ScreenTitle(text: app.s.zmanim)

                        locationPicker

                        Text(app.s.zIntro)
                            .font(Typo.sans(12.5))
                            .foregroundStyle(Palette.soft)

                        disclaimer

                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                NavigationLink {
                                    ZmanDetailView(row: row)
                                } label: {
                                    rowView(row, first: idx == 0, isNext: row.id == nextId)
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
                .refreshable {
                    Haptics.tap()
                    app.refreshZmanim()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                .statusBarMask()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // City dropdown at the top of the times — a curated list plus opt-in GPS.
    private var locationPicker: some View {
        Menu {
            Button { Haptics.tap(); app.startLocation() } label: {
                Label(app.s.setLocRefresh, systemImage: "location.fill")
            }
            Divider()
            ForEach(City.all) { c in
                Button { Haptics.tap(); app.selectCity(c) } label: {
                    if app.loc.name == c.name(app.lang) {
                        Label(c.name(app.lang), systemImage: "checkmark")
                    } else {
                        Text(c.name(app.lang))
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Palette.cream).frame(width: 38, height: 38)
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 16)).foregroundStyle(Palette.gold)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.s.setLoc.uppercased()).font(Typo.label(9)).tracking(1.4).foregroundStyle(Palette.faint)
                    Text(app.loc.name ?? app.s.locating).font(Typo.sans(15.5, .semibold)).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // A quiet справочная note — the times are approximate, not a halachic ruling.
    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .font(.system(size: 12)).foregroundStyle(Palette.gold)
                .padding(.top, 1)
            Text(app.s.zDisclaimer)
                .font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.gold.opacity(0.15), lineWidth: 1)))
    }

    private func rowView(_ row: ZmanRow, first: Bool, isNext: Bool) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(isNext ? Palette.gold.opacity(0.16) : Palette.cream)
                    .frame(width: 38, height: 38)
                Image(systemName: row.icon).font(.system(size: 18)).foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(row.name(app.lang)).font(Typo.sans(15, .medium)).foregroundStyle(Palette.ink)
                    if isNext {
                        Text(app.s.nextZman)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Palette.gold))
                    }
                }
                if app.lang != .he {
                    Text(row.he).font(Typo.serif(12)).foregroundStyle(Palette.faint)
                }
            }
            Spacer(minLength: 0)
            if Reminders.get(row.id)?.on == true {
                Image(systemName: "bell.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
            }
            Text(app.fmt(displayed(row)))
                .font(Typo.sans(16, .semibold))
                .foregroundStyle(displayed(row) == nil ? Palette.faint : Palette.gold)
                .monospacedDigit()
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.faint)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(isNext ? Palette.cream.opacity(0.7) : .clear)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Palette.line).frame(height: 1) }
        }
        .contentShape(Rectangle())
    }
}

struct ZmanDetailView: View {
    @EnvironmentObject var app: AppState
    let row: ZmanRow

    @State private var reminder = ZmanReminder(on: false, before: 10, vk: "")
    @State private var denied = false
    @State private var displayVk = ""       // variant chosen to display (and remind on)

    private var shownTime: Date? {
        app.currentZmanim.t(displayVk) ?? row.main
    }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text(row.name(app.lang))
                        .font(displayFont(26, app.lang))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 6) {
                        Text(app.fmt(shownTime))
                            .font(Typo.digits(46))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                        if app.lang != .he {
                            Text(row.he).font(Typo.serif(18)).foregroundStyle(Palette.gold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    reminderCard

                    if reminder.on {
                        SectionLabel(text: app.s.remindBefore)
                        Segmented(items: [
                            .init(label: app.s.onTime, active: reminder.before == 0) { reminder.before = 0; save() },
                            .init(label: app.s.min5, active: reminder.before == 5) { reminder.before = 5; save() },
                            .init(label: app.s.min10, active: reminder.before == 10) { reminder.before = 10; save() },
                            .init(label: app.s.min15, active: reminder.before == 15) { reminder.before = 15; save() },
                        ])
                    }

                    SectionLabel(text: row.variants.count > 1 ? app.s.chooseTime : app.s.allVariants)

                    VStack(spacing: 0) {
                        ForEach(Array(row.variants.enumerated()), id: \.element.id) { idx, v in
                            variantRow(v, first: idx == 0)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Text(denied ? app.s.notifDenied : app.s.remindHint)
                        .font(Typo.sans(11.5))
                        .foregroundStyle(denied ? Palette.gold : Palette.faint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let r = Reminders.get(row.id) { reminder = r }
            displayVk = ZmanDisplay.get(row.id) ?? row.variants.first?.key ?? ""
            if reminder.vk.isEmpty { reminder.vk = displayVk }
        }
    }

    private var reminderCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Palette.cream).frame(width: 38, height: 38)
                Image(systemName: "bell").font(.system(size: 17)).foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.s.remind).font(Typo.sans(14.5, .medium)).foregroundStyle(Palette.ink)
                Text(reminder.on ? app.s.remindOn : app.s.remindOff)
                    .font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { reminder.on },
                set: { newVal in
                    if newVal {
                        Task {
                            if await NotificationScheduler.requestAuth() {
                                reminder.on = true
                                save()
                                Haptics.success()
                            } else {
                                denied = true
                            }
                        }
                    } else {
                        reminder.on = false
                        save()
                    }
                }
            ))
            .labelsHidden()
            .tint(Palette.gold)
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1)))
    }

    @ViewBuilder
    private func variantRow(_ v: ZmanVariant, first: Bool) -> some View {
        let selected = v.key == displayVk
        let selectable = v.time != nil && row.variants.count > 1
        HStack(spacing: 11) {
            if selectable {
                ZStack {
                    Circle().strokeBorder(selected ? Palette.gold : Palette.line, lineWidth: 2)
                        .frame(width: 19, height: 19)
                    if selected { Circle().fill(Palette.gold).frame(width: 9, height: 9) }
                }
            }
            Text(v.label(app.lang))
                .font(Typo.sans(13.5, selected ? .medium : .regular))
                .foregroundStyle(selected ? Palette.ink : Palette.soft)
            if app.lang != .he {
                Text(v.he).font(Typo.serif(14)).foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 8)
            Text(app.fmt(v.time))
                .font(Typo.sans(14, .medium))
                .foregroundStyle(v.time == nil ? Palette.faint : (selected ? Palette.gold : Palette.ink))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture {
            guard selectable else { return }
            Haptics.tap()
            displayVk = v.key
            ZmanDisplay.set(row.id, v.key)
            if reminder.on { reminder.vk = v.key; save() }
        }
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 18) }
        }
    }

    private func save() {
        if reminder.vk.isEmpty { reminder.vk = displayVk.isEmpty ? (row.variants.first?.key ?? "") : displayVk }
        Reminders.set(row.id, reminder)
        NotificationScheduler.reschedule(app: app)
    }
}
