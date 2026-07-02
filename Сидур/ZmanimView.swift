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
            if Reminders.get(row.id)?.on == true {
                Image(systemName: "bell.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
            }
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

    @State private var reminder = ZmanReminder(on: false, before: 10, vk: "")
    @State private var denied = false

    private var shownTime: Date? {
        reminder.on ? (app.currentZmanim.t(reminder.vk) ?? row.main) : row.main
    }

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
                        HStack(spacing: 8) {
                            beforeButton(0, app.s.onTime)
                            beforeButton(5, app.s.min5)
                            beforeButton(10, app.s.min10)
                            beforeButton(15, app.s.min15)
                        }
                    }

                    SectionLabel(text: reminder.on ? app.s.remindWhich : app.s.allVariants)

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
            else { reminder.vk = row.variants.first?.key ?? "" }
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

    private func beforeButton(_ min: Int, _ label: String) -> some View {
        Button {
            reminder.before = min
            save()
        } label: {
            Text(label)
                .font(Typo.sans(12.5, reminder.before == min ? .semibold : .regular))
                .foregroundStyle(reminder.before == min ? Palette.paper : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 11)
                    .fill(reminder.before == min ? Palette.ink : Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line, lineWidth: reminder.before == min ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func variantRow(_ v: ZmanVariant, first: Bool) -> some View {
        let selected = reminder.on && reminder.vk == v.key
        HStack(spacing: 11) {
            if reminder.on {
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
            guard reminder.on, v.time != nil else { return }
            reminder.vk = v.key
            save()
        }
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 18) }
        }
    }

    private func save() {
        if reminder.vk.isEmpty { reminder.vk = row.variants.first?.key ?? "" }
        Reminders.set(row.id, reminder)
        NotificationScheduler.reschedule(app: app)
    }
}
