import SwiftUI

// Lightweight inline-formatting for prayer text. Fields stay plain strings, but
// may carry a small, clean HTML subset produced by the editor:
//   <b> <i> <u> <mark> <span style="color:#RRGGBB"> <br>
// Plain text (no "<") passes straight through, so existing content is untouched.
// Formatting layers on top of the reader's base font/size/colour — never replaces it.
enum RichText {
    private struct Sty {
        var bold = false, italic = false, underline = false, highlight = false
        var color: Color? = nil
    }

    private static var cache: [String: AttributedString] = [:]
    private static let cacheLimit = 4000

    static func has(_ s: String) -> Bool { s.contains("<") }

    /// Build an AttributedString: `base` font/`color` are the reader defaults,
    /// `highlight` is the gold wash used by <mark>.
    static func attributed(_ s: String, base: Font, color: Color, highlight: Color) -> AttributedString {
        if !has(s) {
            var a = AttributedString(s); a.font = base; a.foregroundColor = color; return a
        }
        let key = "\(color.hashValue)|\(s)"
        if let c = cache[key] { return c }

        var out = AttributedString()
        var stack: [Sty] = [Sty()]
        func emit(_ raw: String) {
            guard !raw.isEmpty else { return }
            var run = AttributedString(decode(raw))
            let st = stack.last!
            var f = base
            if st.bold { f = f.bold() }
            if st.italic { f = f.italic() }
            run.font = f
            run.foregroundColor = st.color ?? color
            if st.underline { run.underlineStyle = .single }
            if st.highlight { run.backgroundColor = highlight }
            out.append(run)
        }

        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "<" {
                guard let close = chars[i...].firstIndex(of: ">") else { break }
                let tag = String(chars[(i + 1)..<close]).trimmingCharacters(in: .whitespaces)
                apply(tag, &stack, &out)
                i = close + 1
            } else {
                var j = i
                while j < chars.count && chars[j] != "<" { j += 1 }
                emit(String(chars[i..<j]))
                i = j
            }
        }
        if cache.count > cacheLimit { cache.removeAll() }
        cache[key] = out
        return out
    }

    private static func apply(_ tag: String, _ stack: inout [Sty], _ out: inout AttributedString) {
        let lower = tag.lowercased()
        if lower == "br" || lower == "br/" || lower == "br /" {
            out.append(AttributedString("\n")); return
        }
        if lower.hasPrefix("/") {
            if stack.count > 1 { stack.removeLast() }
            return
        }
        var st = stack.last!
        let name = lower.split(whereSeparator: { $0 == " " }).first.map(String.init) ?? lower
        switch name {
        case "b", "strong": st.bold = true
        case "i", "em": st.italic = true
        case "u": st.underline = true
        case "mark": st.highlight = true
        case "span", "font":
            if let c = hexColor(in: tag) { st.color = c }
        default: break
        }
        stack.append(st)
    }

    private static func hexColor(in tag: String) -> Color? {
        // matches color:#rrggbb  OR  color="#rrggbb"
        guard let r = tag.range(of: "#") else { return nil }
        let after = tag[r.upperBound...]
        let hexStr = after.prefix(while: { $0.isHexDigit })
        guard hexStr.count == 6, let v = UInt(hexStr, radix: 16) else { return nil }
        return Color(hex: UInt(v))
    }

    private static func decode(_ s: String) -> String {
        guard s.contains("&") else { return s }
        return s.replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
