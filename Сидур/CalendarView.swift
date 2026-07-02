import SwiftUI
import Combine

// One Hebcal event.
struct CalEvent: Identifiable {
    let id = UUID()
    let title: String
    let hebrew: String
    let category: String
    var icon: String {
        switch category {
        case "parashat": return "book"
        case "roshchodesh": return "moon"
        case "holiday": return "star"
        case "omer": return "sparkles"
        case "fast": return "flame"
        case "havdalah", "candles": return "flame"
        default: return "calendar"
        }
    }
}

// Month events from Hebcal (free JSON API), cached per month.
@MainActor
final class CalendarModel: ObservableObject {
    @Published var events: [String: [CalEvent]] = [:]   // "yyyy-MM-dd" → events
    @Published var failed = false
    private var loadedMonths: Set<String> = []

    func load(year: Int, month: Int) async {
        let key = "\(year)-\(month)"
        guard !loadedMonths.contains(key) else { return }
        guard let url = URL(string: "https://www.hebcal.com/hebcal?v=1&cfg=json&year=\(year)&month=\(month)&maj=on&min=on&nx=on&mf=on&ss=on&o=on") else { return }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 12
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = j["items"] as? [[String: Any]] else { throw URLError(.badServerResponse) }
            var map = events
            for it in items {
                guard let date = (it["date"] as? String)?.prefix(10) else { continue }
                let ev = CalEvent(
                    title: (it["title"] as? String) ?? "",
                    hebrew: (it["hebrew"] as? String) ?? "",
                    category: (it["category"] as? String) ?? "")
                map[String(date), default: []].append(ev)
            }
            events = map
            loadedMonths.insert(key)
            failed = false
        } catch {
            failed = events.isEmpty
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var model = CalendarModel()
    @State private var monthAnchor = Date()
    @State private var selected = Date()

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2   // Monday
        return c
    }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    selectedCard
                    monthHeader
                    grid
                    SectionLabel(text: app.s.calEvents)
                    eventsList
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationTitle(app.s.calTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: monthKey) {
            let c = cal.dateComponents([.year, .month], from: monthAnchor)
            await model.load(year: c.year ?? 2026, month: c.month ?? 1)
        }
    }

    private var monthKey: String {
        let c = cal.dateComponents([.year, .month], from: monthAnchor)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    private func ymd(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = cal
        return f.string(from: d)
    }

    private var selectedCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HebrewDate.hebrew(app.lang, selected))
                .font(Typo.display(24)).foregroundStyle(Palette.ink)
            Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(app.lang.locale)))
                .font(Typo.sans(12.5)).foregroundStyle(Palette.soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1)))
    }

    private var monthHeader: some View {
        HStack {
            navBtn("chevron.backward") { shiftMonth(-1) }
            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year().locale(app.lang.locale)))
                .font(Typo.display(19)).foregroundStyle(Palette.ink)
            Spacer()
            navBtn("chevron.forward") { shiftMonth(1) }
        }
    }

    private func navBtn(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.soft)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Palette.card).overlay(Circle().strokeBorder(Palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ d: Int) {
        if let m = cal.date(byAdding: .month, value: d, to: monthAnchor) { monthAnchor = m }
    }

    private var grid: some View {
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        let first = cal.date(from: comps) ?? monthAnchor
        let dayCount = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let dows = app.lang == .he ? ["ב", "ג", "ד", "ה", "ו", "ש", "א"] : ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        let today = ymd(Date())

        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(dows, id: \.self) { d in
                    Text(d).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.faint)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 46) }
                ForEach(1...dayCount, id: \.self) { day in
                    if let date = cal.date(byAdding: .day, value: day - 1, to: first) {
                        dayCell(date, day: day, todayKey: today)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date, day: Int, todayKey: String) -> some View {
        let key = ymd(date)
        let isToday = key == todayKey
        let isSel = ymd(selected) == key
        let hasEvents = !(model.events[key] ?? []).isEmpty
        let hebDay = Calendar(identifier: .hebrew).component(.day, from: date)

        return Button { selected = date } label: {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(Typo.sans(13, isToday || isSel ? .semibold : .regular))
                    .foregroundStyle(isSel ? .white : Palette.ink)
                Text("\(hebDay)")
                    .font(Typo.serif(9))
                    .foregroundStyle(isSel ? .white.opacity(0.85) : Palette.gold)
                Circle().fill(hasEvents ? (isSel ? .white : Palette.gold) : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isSel ? Palette.gold : (isToday ? Palette.cream : .clear))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isToday && !isSel ? Palette.gold : .clear, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var eventsList: some View {
        let evs = model.events[ymd(selected)] ?? []
        if model.failed && evs.isEmpty {
            Text(app.s.calError).font(Typo.sans(13)).foregroundStyle(Palette.soft)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        } else if evs.isEmpty {
            Text(app.s.calNoEvents).font(Typo.sans(13)).foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        } else {
            GroupCard {
                ForEach(Array(evs.enumerated()), id: \.element.id) { idx, ev in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Palette.cream).frame(width: 36, height: 36)
                            Image(systemName: ev.icon).font(.system(size: 15)).foregroundStyle(Palette.gold)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.lang == .he && !ev.hebrew.isEmpty ? ev.hebrew : ev.title)
                                .font(Typo.sans(14, .medium)).foregroundStyle(Palette.ink)
                            if app.lang != .he && !ev.hebrew.isEmpty {
                                Text(ev.hebrew).font(Typo.serif(12.5)).foregroundStyle(Palette.faint)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 16) }
                    }
                }
            }
        }
    }
}
