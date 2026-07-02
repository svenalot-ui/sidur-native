import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Geo helpers (Kotel bearing / distance)
enum Geo {
    static let kotel = GeoLoc(lat: 31.7780, lng: 35.2354, name: "Jerusalem")

    static func bearing(from a: GeoLoc, to b: GeoLoc) -> Double {
        let d = Double.pi / 180
        let dL = (b.lng - a.lng) * d
        let y = sin(dL) * cos(b.lat * d)
        let x = cos(a.lat * d) * sin(b.lat * d) - sin(a.lat * d) * cos(b.lat * d) * cos(dL)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distanceKm(from a: GeoLoc, to b: GeoLoc) -> Double {
        let d = Double.pi / 180, r = 6371.0
        let dLa = (b.lat - a.lat) * d, dLo = (b.lng - a.lng) * d
        let h = pow(sin(dLa / 2), 2) + cos(a.lat * d) * cos(b.lat * d) * pow(sin(dLo / 2), 2)
        return r * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}

// MARK: - Mizrah compass
struct MizrahView: View {
    @EnvironmentObject var app: AppState

    private var bearing: Double { Geo.bearing(from: app.loc, to: Geo.kotel) }
    private var distance: Double { Geo.distanceKm(from: app.loc, to: Geo.kotel) }
    private var arrowAngle: Double { bearing - (app.heading ?? 0) }
    private var aligned: Bool {
        guard app.heading != nil else { return false }
        let diff = abs((arrowAngle + 540).truncatingRemainder(dividingBy: 360) - 180)
        return diff > 175   // arrow within ±5° of "up"
    }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Space.md) {
                    Text("מִזְרָח")
                        .font(Typo.serif(19))
                        .foregroundStyle(Palette.gold)

                    compass
                        .frame(width: 270, height: 270)
                        .padding(.top, Space.xs)

                    Text("\(Int(distance.rounded()).formatted()) \(app.s.km)")
                        .font(Typo.display(30)).foregroundStyle(Palette.ink).monospacedDigit()
                    Text("\(Int(bearing.rounded()))° · \(app.s.toJerusalem)")
                        .font(Typo.sans(13)).foregroundStyle(Palette.gold).tracking(1)

                    if aligned {
                        Label(app.s.facing, systemImage: "checkmark.circle")
                            .font(Typo.sans(14, .medium)).foregroundStyle(Palette.gold)
                            .padding(.top, 2)
                    }

                    Text("\(app.s.rotateHint)\n\(app.s.calibHint)")
                        .font(Typo.sans(12.5)).foregroundStyle(Palette.soft)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.sm)
                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationTitle(app.s.mizrahTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.startCompass() }
        .onDisappear { app.stopCompass() }
    }

    private var compass: some View {
        let rose = -(app.heading ?? 0)
        return ZStack {
            Circle().fill(Palette.card)
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            Circle().strokeBorder(Palette.cream, lineWidth: 1).padding(8)

            // rotating rose: ticks + cardinal letters
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 9 == 0
                    Rectangle()
                        .fill(major ? Palette.goldL : Palette.line)
                        .frame(width: major ? 2 : 1, height: major ? 14 : 7)
                        .offset(y: -122)
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach(Array(cardinals.enumerated()), id: \.offset) { i, c in
                    Text(c)
                        .font(Typo.sans(14, i == 0 ? .semibold : .regular))
                        .foregroundStyle(i == 0 ? Palette.gold : Palette.faint)
                        .rotationEffect(.degrees(-Double(i) * 90 - rose))   // keep glyphs upright
                        .offset(y: -96)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .rotationEffect(.degrees(rose))
            .animation(.linear(duration: 0.15), value: rose)

            // arrow to Jerusalem with Magen David tip
            ZStack {
                ArrowShape()
                    .fill(Palette.gold)
                    .frame(width: 26, height: 200)
                MagenDavid()
                    .stroke(Palette.gold, lineWidth: 1.6)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Palette.card).frame(width: 34, height: 34))
                    .offset(y: -100)
            }
            .rotationEffect(.degrees(arrowAngle))
            .animation(.linear(duration: 0.15), value: arrowAngle)

            Circle().fill(Palette.ink).frame(width: 14, height: 14)
            Circle().fill(Palette.goldL).frame(width: 6, height: 6)
        }
    }

    private var cardinals: [String] {
        app.lang == .he ? ["צ", "מז", "ד", "מע"] : ["С", "В", "Ю", "З"]
    }
}

// Slim north-pointing arrow (kite shape).
struct ArrowShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX, cy = r.midY
        p.move(to: CGPoint(x: cx, y: r.minY + 24))
        p.addLine(to: CGPoint(x: cx + 8, y: cy))
        p.addLine(to: CGPoint(x: cx, y: cy + 9))
        p.addLine(to: CGPoint(x: cx - 8, y: cy))
        p.closeSubpath()
        return p
    }
}

// Star of David from two overlapping triangles.
struct MagenDavid: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        func triangle(up: Bool) {
            let h = r.height, w = r.width
            let top = up ? r.minY : r.maxY
            let base = up ? r.minY + h * 0.78 : r.maxY - h * 0.78
            p.move(to: CGPoint(x: r.midX, y: top))
            p.addLine(to: CGPoint(x: r.minX + w * 0.07, y: base))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.07, y: base))
            p.closeSubpath()
        }
        triangle(up: true)
        triangle(up: false)
        return p
    }
}

// MARK: - Tzedaka
struct TzedakaView: View {
    @EnvironmentObject var app: AppState
    @State private var copiedField: String? = nil

    private static let acc = "40703810190140000030"
    private static let cor = "30101810900000000790"
    private static let bik = "044030790"
    private static let name = "Еврейская религиозная община (СПб)"
    private static let bank = "ПАО «Банк «Санкт-Петербург»»"
    private static let gost = "ST00012|Name=Еврейская религиозная община|PersonalAcc=\(acc)|BankName=Банк Санкт-Петербург|BIC=\(bik)|CorrespAcc=\(cor)|Purpose=Цдака"

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack(spacing: 9) {
                        Image(systemName: "heart.circle").font(.system(size: 20)).foregroundStyle(Palette.gold)
                        Text(app.s.tzedakaSub).font(Typo.display(20)).foregroundStyle(Palette.ink)
                    }
                    Text(app.s.tzedakaText)
                        .font(Typo.sans(13)).foregroundStyle(Palette.soft).lineSpacing(4)

                    if let img = Self.qrImage {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 190, height: 190)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.xs)
                    }

                    SectionLabel(text: app.s.requisites)
                    GroupCard {
                        reqRow(app.s.rqName, Self.name, copy: false, first: true)
                        reqRow(app.s.rqAcc, Self.acc, copy: true, first: false)
                        reqRow(app.s.rqBank, Self.bank, copy: false, first: false)
                        reqRow(app.s.rqBik, Self.bik, copy: true, first: false)
                        reqRow(app.s.rqCor, Self.cor, copy: true, first: false)
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationTitle(app.s.tzedakaTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reqRow(_ label: String, _ value: String, copy: Bool, first: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(Typo.sans(13)).foregroundStyle(Palette.soft)
            Spacer(minLength: 8)
            Text(value)
                .font(Typo.sans(13.5, .medium)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
            if copy {
                Button {
                    UIPasteboard.general.string = value
                    withAnimation { copiedField = label }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation { copiedField = nil } }
                } label: {
                    Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.gold)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Palette.line).frame(height: 1) } }
    }

    private static var qrImage: UIImage? = {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(gost.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }()
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    SectionLabel(text: app.s.setLang)
                    HStack(spacing: 8) {
                        segButton("Русский", active: app.lang == .ru) { app.lang = .ru }
                        segButton("עברית", active: app.lang == .he) { app.lang = .he }
                    }

                    SectionLabel(text: app.s.setTheme)
                    HStack(spacing: 8) {
                        segButton(app.s.themeAuto, active: app.theme == "auto") { app.theme = "auto" }
                        segButton(app.s.themeLight, active: app.theme == "light") { app.theme = "light" }
                        segButton(app.s.themeDark, active: app.theme == "dark") { app.theme = "dark" }
                    }

                    SectionLabel(text: app.s.setNusach)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Nusach.allCases, id: \.rawValue) { n in
                            segButton(n.name(app.lang), active: app.nusach == n.rawValue) { app.nusach = n.rawValue }
                        }
                    }

                    SectionLabel(text: app.s.setLoc)
                    GroupCard {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Palette.cream).frame(width: 36, height: 36)
                                Image(systemName: "mappin.and.ellipse").font(.system(size: 15)).foregroundStyle(Palette.gold)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.loc.name ?? app.s.locating)
                                    .font(Typo.sans(14, .medium)).foregroundStyle(Palette.ink)
                                Text(String(format: "%.3f, %.3f", app.loc.lat, app.loc.lng))
                                    .font(Typo.sans(11)).foregroundStyle(Palette.faint).monospacedDigit()
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Button {
                            Haptics.tap()
                            app.startLocation()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "location").font(.system(size: 13)).foregroundStyle(Palette.gold)
                                Text(app.s.setLocRefresh).font(Typo.sans(13.5, .medium)).foregroundStyle(Palette.gold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 16) }
                    }

                    GroupCard {
                        Link(destination: URL(string: "mailto:svenalot@gmail.com?subject=%D0%A1%D0%B8%D0%B4%D1%83%D1%80%20%C2%B7%20%D0%9E%D1%82%D0%B7%D1%8B%D0%B2")!) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Palette.cream).frame(width: 36, height: 36)
                                    Image(systemName: "envelope").font(.system(size: 15)).foregroundStyle(Palette.gold)
                                }
                                Text(app.s.feedback).font(Typo.sans(14, .medium)).foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.faint)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)

                    Text("Сидур · שֶׁבֶת אַחִים גַּם יָחַד")
                        .font(Typo.sans(11.5)).foregroundStyle(Palette.faint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Space.xl)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
        .navigationTitle(app.s.settings)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func segButton(_ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(label)
                .font(Typo.sans(13.5, active ? .semibold : .regular))
                .foregroundStyle(active ? Palette.paper : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(active ? Palette.ink : Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: active ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }
}
