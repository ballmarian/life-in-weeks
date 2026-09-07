import SwiftUI
import LifeInWeeksCore

/// Every colour in the design, in one place.
///
/// The dark palette is the design as specified (README §Design Tokens). Light
/// is derived from the same structure — the README calls for a light variant
/// following the system appearance but only pins the dark values, so light
/// mirrors each token's *role* rather than inventing new ones.
struct Palette {
    // Surfaces
    let canvas: Color
    let chrome: Color
    let sidebar: Color
    let raised: Color
    let controlFill: Color
    let controlSelected: Color
    let fieldFill: Color
    let secondaryButton: Color
    let cellLived: Color
    let separator: Color
    let cellHairline: Color
    let scrim: Color
    /// Inset hairline inside text fields and the popover.
    let fieldHairline: Color
    let tooltipFill: Color
    let tooltipHairline: Color
    /// Inset hairline around a colour chip or palette swatch.
    let swatchHairline: Color

    // Ink
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let quaternary: Color
    let placeholder: Color
    let decadeLabel: Color
    let noteTick: Color
    let accent: Color
    let sidebarHover: Color
    /// The ring drawn around the cell under the cursor.
    let hoverRing: Color
    /// The single continuous outline around a highlighted chapter's extent.
    let chapterOutline: Color

    /// What chapter colours are mixed toward before they paint a cell. Matches
    /// `canvas`, but kept as raw components for the Oklab mix.
    let canvasMixTarget: SRGBColor

    static let dark = Palette(
        canvas: Color(hex: "#1C1C1E"),
        chrome: Color(hex: "#2B2B2D"),
        sidebar: Color(hex: "#232325"),
        raised: Color(hex: "#2C2C2E"),
        controlFill: Color(white: 1, opacity: 0.08),
        controlSelected: Color(hex: "#5A5A5E"),
        fieldFill: Color(white: 0, opacity: 0.40),
        secondaryButton: Color(white: 1, opacity: 0.12),
        cellLived: Color(hex: "#3A3A3C"),
        separator: Color(white: 1, opacity: 0.08),
        cellHairline: Color(white: 1, opacity: 0.11),
        scrim: Color(white: 0, opacity: 0.34),
        fieldHairline: Color(white: 1, opacity: 0.16),
        tooltipFill: Color(hex: "#3A3A3C"),
        tooltipHairline: Color(white: 1, opacity: 0.14),
        swatchHairline: Color(white: 0, opacity: 0.30),
        primary: Color(hex: "#F2F2F7"),
        secondary: Color(hex: "#C7C7CC"),
        tertiary: Color(hex: "#98989D"),
        quaternary: Color(hex: "#8E8E93"),
        placeholder: Color(hex: "#6C6C70"),
        decadeLabel: Color(hex: "#E5E5EA"),
        noteTick: Color(hex: "#EAEAEF"),
        accent: Color(hex: "#0A84FF"),
        sidebarHover: Color(red: 10 / 255, green: 132 / 255, blue: 1, opacity: 0.28),
        hoverRing: Color(hex: "#F2F2F7"),
        chapterOutline: Color(white: 1, opacity: 0.95),
        canvasMixTarget: SRGBColor(hex: "#1C1C1E") ?? SRGBColor(red: 0, green: 0, blue: 0)
    )

    static let light = Palette(
        canvas: Color(hex: "#FFFFFF"),
        chrome: Color(hex: "#ECECEE"),
        sidebar: Color(hex: "#F5F5F7"),
        raised: Color(hex: "#FCFCFD"),
        controlFill: Color(white: 0, opacity: 0.06),
        controlSelected: Color(hex: "#FFFFFF"),
        fieldFill: Color(white: 1, opacity: 0.90),
        secondaryButton: Color(white: 0, opacity: 0.08),
        cellLived: Color(hex: "#D6D6DA"),
        separator: Color(white: 0, opacity: 0.10),
        cellHairline: Color(white: 0, opacity: 0.13),
        scrim: Color(white: 0, opacity: 0.22),
        fieldHairline: Color(white: 0, opacity: 0.16),
        tooltipFill: Color(hex: "#FFFFFF"),
        tooltipHairline: Color(white: 0, opacity: 0.14),
        swatchHairline: Color(white: 0, opacity: 0.30),
        primary: Color(hex: "#1C1C1E"),
        secondary: Color(hex: "#3A3A3C"),
        tertiary: Color(hex: "#6C6C70"),
        quaternary: Color(hex: "#8E8E93"),
        placeholder: Color(hex: "#AEAEB2"),
        decadeLabel: Color(hex: "#1C1C1E"),
        noteTick: Color(hex: "#3A3A3C"),
        accent: Color(hex: "#007AFF"),
        sidebarHover: Color(red: 0, green: 122 / 255, blue: 1, opacity: 0.20),
        hoverRing: Color(hex: "#1C1C1E"),
        chapterOutline: Color(white: 0, opacity: 0.72),
        canvasMixTarget: SRGBColor(hex: "#FFFFFF") ?? SRGBColor(red: 1, green: 1, blue: 1)
    )

    static func forScheme(_ scheme: ColorScheme) -> Palette {
        scheme == .light ? .light : .dark
    }

    /// A chapter's colour as it paints a grid cell: mixed toward the canvas by
    /// the per-zoom amount so dense rows stay legible (README §4, state 3).
    func chapterFill(_ hex: String, zoom: ZoomLevel) -> Color {
        guard let base = SRGBColor(hex: hex) else { return cellLived }
        let mixed = ColorMix.oklab(base, toward: canvasMixTarget,
                                   amount: ChapterPalette.gridMix(for: zoom))
        return Color(rgb: mixed)
    }

    /// The darker underline drawn along the bottom of a chapter cell at L zoom.
    func chapterUnderline(_ hex: String) -> Color {
        guard let base = SRGBColor(hex: hex) else { return cellLived }
        return Color(rgb: ColorMix.oklab(base, toward: canvasMixTarget, amount: 0.08))
    }
}

extension Color {
    /// Hex string → `Color`. Falls back to clear rather than trapping, so a bad
    /// value in `blocks.yaml` can never crash the grid.
    init(hex: String) {
        guard let rgb = SRGBColor(hex: hex) else {
            self = .clear
            return
        }
        self.init(rgb: rgb)
    }

    init(rgb: SRGBColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

// MARK: - Type

/// System UI type for chrome and content, monospaced for dates, paths, counts
/// and row labels (README §Design Tokens).
enum Typography {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
