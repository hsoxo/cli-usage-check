import SwiftUI
import AppKit

// MARK: - Brand colors

extension Color {
    /// Anthropic / Claude warm coral.
    static let claudeOrange = Color(red: 0.85, green: 0.46, blue: 0.32)
    /// OpenAI / Codex green.
    static let openAIGreen  = Color(red: 0.06, green: 0.64, blue: 0.50)
}

// MARK: - Claude mark (sunburst)

/// Official Anthropic / Claude sunburst mark. Decoded from the embedded SVG via
/// NSImage so the path geometry is exact (the previous Canvas approximation was
/// only four capsules). Loaded as a template so callers can tint via
/// `foregroundStyle` and the menubar bitmap adapts to light/dark.
struct ClaudeLogo: View {
    var size: CGFloat = 14
    var color: Color = .claudeOrange

    /// The sunburst has thin rays separated by negative space, so it reads
    /// smaller than a solid mark (like Codex's knot) at the same point size.
    /// Multiplying by ~1.3 makes it visually balance at parity sizes.
    private static let visualBalance: CGFloat = 1.3

    var body: some View {
        Image(nsImage: Self.templateImage)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size * Self.visualBalance,
                   height: size * Self.visualBalance)
            .foregroundStyle(color)
            .accessibilityLabel("Claude")
    }

    private static let templateImage: NSImage = {
        guard let data = Self.svg.data(using: .utf8) else { return NSImage() }
        if let img = NSImage(data: data) {
            img.isTemplate = true
            return img
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-check-claude.svg")
        try? data.write(to: url, options: .atomic)
        let img = NSImage(contentsOf: url) ?? NSImage()
        img.isTemplate = true
        return img
    }()

    private static let svg: String = #"""
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 24 25" fill="#000000"><path fill="#000000" d="m5.929 16.218l3.931-2.206l.066-.192l-.066-.106h-.192l-.658-.04l-2.246-.061l-1.948-.082l-1.887-.1l-.476-.102l-.445-.587l.045-.293l.4-.268l.572.05l1.265.086l1.897.132l1.376.08l2.039.213h.324l.045-.131l-.11-.081l-.087-.081l-1.963-1.33l-2.125-1.407l-1.113-.81l-.602-.41l-.304-.384l-.131-.84l.546-.602l.734.05l.187.051l.744.572l1.588 1.23l2.075 1.527l.303.253l.122-.086l.015-.06l-.137-.228l-1.128-2.04l-1.204-2.074l-.536-.86l-.142-.516a2.5 2.5 0 0 1-.086-.607l.622-.845l.344-.111l.83.111l.35.304l.515 1.179l.835 1.856l1.295 2.525l.38.749l.202.693l.076.213h.131v-.122l.107-1.422l.197-1.745l.192-2.247l.066-.632l.314-.759l.622-.41l.486.233l.4.572l-.056.37l-.238 1.542l-.465 2.419l-.304 1.619h.177l.203-.203l.82-1.087l1.375-1.72l.608-.684l.708-.754l.455-.359h.86l.633.941l-.284.972l-.885 1.123l-.734.951l-1.052 1.417l-.658 1.133l.06.091l.158-.015l2.378-.506l1.285-.233l1.533-.263l.693.324l.076.329l-.273.673l-1.64.405l-1.922.384l-2.864.678l-.035.025l.04.05l1.29.122l.552.03h1.35l2.515.188l.658.435l.395.531l-.066.405l-1.012.516l-1.366-.324l-3.187-.759l-1.093-.273h-.152v.091l.91.89l1.67 1.508l2.09 1.943l.106.48l-.268.38l-.284-.04l-1.836-1.381l-.708-.623l-1.604-1.35h-.107v.141l.37.541l1.953 2.935l.101.9l-.142.294l-.506.177l-.556-.101l-1.144-1.604l-1.179-1.806l-.95-1.62l-.117.066l-.562 6.047l-.263.308l-.607.233l-.506-.385l-.268-.622l.268-1.23l.324-1.603l.263-1.275l.238-1.584l.142-.526l-.01-.035l-.117.015l-1.194 1.639l-1.816 2.454l-1.437 1.538l-.344.137l-.597-.31l.055-.55l.334-.491l1.989-2.53l1.199-1.569l.774-.905l-.005-.132h-.046l-5.282 3.43l-.94.122l-.406-.38l.051-.622l.192-.202l1.589-1.093z"/></svg>
    """#
}

// MARK: - Claude Code (pixel mark used in the tray)

/// Pixel-art "Claude Code" mark — outline of a stubby monitor with two
/// rectangular eye-holes carved out via even-odd fill. Path is converted
/// straight from the Claude Code SVG. The original SVG uses a 24x24
/// viewBox but the actual mark only occupies y=5..20, so we tighten the
/// shape to the content bounds (24×15) so callers get the real mark size.
struct ClaudeCodeMark: View {
    /// Height of the rendered mark. Width scales with the natural aspect (24:15).
    var size: CGFloat = 14
    var color: Color = .claudeOrange

    var body: some View {
        let aspect: CGFloat = 24.0 / 15.0
        ClaudeCodeShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: size * aspect, height: size)
            .accessibilityLabel("Claude")
    }
}

private struct ClaudeCodeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // SVG content bounds: x ∈ [0, 24], y ∈ [5, 20]
        let sx = rect.width  / 24.0
        let sy = rect.height / 15.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + (y - 5) * sy)
        }

        // Outer outline (clockwise around the monitor + legs).
        p.move(to: pt(20.998, 10.949))
        p.addLine(to: pt(24,     10.949))
        p.addLine(to: pt(24,     14.051))
        p.addLine(to: pt(21,     14.051))
        p.addLine(to: pt(21,     17.079))
        p.addLine(to: pt(19.513, 17.079))
        p.addLine(to: pt(19.513, 20))
        p.addLine(to: pt(18,     20))
        p.addLine(to: pt(18,     17.079))
        p.addLine(to: pt(16.513, 17.079))
        p.addLine(to: pt(16.513, 20))
        p.addLine(to: pt(15,     20))
        p.addLine(to: pt(15,     17.079))
        p.addLine(to: pt(9,      17.079))
        p.addLine(to: pt(9,      20))
        p.addLine(to: pt(7.488,  20))
        p.addLine(to: pt(7.488,  17.079))
        p.addLine(to: pt(6,      17.079))
        p.addLine(to: pt(6,      20))
        p.addLine(to: pt(4.487,  20))
        p.addLine(to: pt(4.487,  17.079))
        p.addLine(to: pt(3,      17.079))
        p.addLine(to: pt(3,      14.05))
        p.addLine(to: pt(0,      14.05))
        p.addLine(to: pt(0,      10.95))
        p.addLine(to: pt(3,      10.95))
        p.addLine(to: pt(3,       5))
        p.addLine(to: pt(20.998,  5))
        p.closeSubpath()

        // Left eye (cut out via even-odd fill).
        p.move(to: pt(6,     10.949))
        p.addLine(to: pt(7.488, 10.949))
        p.addLine(to: pt(7.488, 8.102))
        p.addLine(to: pt(6,     8.102))
        p.closeSubpath()

        // Right eye.
        p.move(to: pt(16.51, 10.949))
        p.addLine(to: pt(18,    10.949))
        p.addLine(to: pt(18,    8.102))
        p.addLine(to: pt(16.51, 8.102))
        p.closeSubpath()

        return p
    }
}

// MARK: - Codex / OpenAI mark (knot)

/// OpenAI / Codex knot. Backed by the official SVG, loaded as a template
/// NSImage so it can be tinted by `foregroundStyle` (template tinting also
/// lets macOS adapt the menubar bitmap to light/dark menubars).
struct CodexLogo: View {
    var size: CGFloat = 14
    var color: Color = .openAIGreen

    var body: some View {
        Image(nsImage: Self.templateImage)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityLabel("Codex")
    }

    private static let templateImage: NSImage = {
        guard let data = Self.svg.data(using: .utf8) else { return NSImage() }
        // macOS 14+ NSImage(data:) accepts SVG. If decoding fails we fall back
        // to writing the SVG to a temp file and loading via URL.
        if let img = NSImage(data: data) {
            img.isTemplate = true
            return img
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-check-codex.svg")
        try? data.write(to: url, options: .atomic)
        let img = NSImage(contentsOf: url) ?? NSImage()
        img.isTemplate = true
        return img
    }()

    private static let svg: String = #"""
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 256 260" fill="#000000"><path d="M239.184 106.203a64.716 64.716 0 0 0-5.576-53.103C219.452 28.459 191 15.784 163.213 21.74A65.586 65.586 0 0 0 52.096 45.22a64.716 64.716 0 0 0-43.23 31.36c-14.31 24.602-11.061 55.634 8.033 76.74a64.665 64.665 0 0 0 5.525 53.102c14.174 24.65 42.644 37.324 70.446 31.36a64.72 64.72 0 0 0 48.754 21.744c28.481.025 53.714-18.361 62.414-45.481a64.767 64.767 0 0 0 43.229-31.36c14.137-24.558 10.875-55.423-8.083-76.483Zm-97.56 136.338a48.397 48.397 0 0 1-31.105-11.255l1.535-.87l51.67-29.825a8.595 8.595 0 0 0 4.247-7.367v-72.85l21.845 12.636c.218.111.37.32.409.563v60.367c-.056 26.818-21.783 48.545-48.601 48.601Zm-104.466-44.61a48.345 48.345 0 0 1-5.781-32.589l1.534.921l51.722 29.826a8.339 8.339 0 0 0 8.441 0l63.181-36.425v25.221a.87.87 0 0 1-.358.665l-52.335 30.184c-23.257 13.398-52.97 5.431-66.404-17.803ZM23.549 85.38a48.499 48.499 0 0 1 25.58-21.333v61.39a8.288 8.288 0 0 0 4.195 7.316l62.874 36.272l-21.845 12.636a.819.819 0 0 1-.767 0L41.353 151.53c-23.211-13.454-31.171-43.144-17.804-66.405v.256Zm179.466 41.695l-63.08-36.63L161.73 77.86a.819.819 0 0 1 .768 0l52.233 30.184a48.6 48.6 0 0 1-7.316 87.635v-61.391a8.544 8.544 0 0 0-4.4-7.213Zm21.742-32.69l-1.535-.922l-51.619-30.081a8.39 8.39 0 0 0-8.492 0L99.98 99.808V74.587a.716.716 0 0 1 .307-.665l52.233-30.133a48.652 48.652 0 0 1 72.236 50.391v.205ZM88.061 139.097l-21.845-12.585a.87.87 0 0 1-.41-.614V65.685a48.652 48.652 0 0 1 79.757-37.346l-1.535.87l-51.67 29.825a8.595 8.595 0 0 0-4.246 7.367l-.051 72.697Zm11.868-25.58L128.067 97.3l28.188 16.218v32.434l-28.086 16.218l-28.188-16.218l-.052-32.434Z"/></svg>
    """#
}

// MARK: - Provider helpers

extension Provider {
    @ViewBuilder
    func logoView(size: CGFloat = 14) -> some View {
        switch self {
        case .claude: ClaudeLogo(size: size)
        case .codex:  CodexLogo(size: size)
        }
    }

    var brandColor: Color {
        switch self {
        case .claude: return .claudeOrange
        case .codex:  return .openAIGreen
        }
    }
}
