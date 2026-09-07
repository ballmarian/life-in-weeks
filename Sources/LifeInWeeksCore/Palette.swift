import Foundation

/// The fixed chapter palette: ten hues at three depths (README §Design Tokens,
/// superseding the single pastel row in PRD §6.6 — same intent, more range).
///
/// A preset palette rather than an open picker so every colour stays legible as
/// a background behind the note tick and emoji.
public enum ChapterPalette {
    public static let pastel = [
        "#EFC9CD", "#F0D5BE", "#EFE3BC", "#DDEABE", "#C6E8C6",
        "#C2E7DD", "#C4E3EF", "#C8D6EF", "#D0CBEE", "#E4C9EE",
    ]

    public static let mid = [
        "#D99AA2", "#DFAE84", "#DCC97F", "#BCD189", "#94CE99",
        "#86C9BA", "#8FC5DB", "#98AEDC", "#A79FD8", "#C99BDA",
    ]

    public static let deep = [
        "#A96068", "#B0764A", "#A98F3F", "#86994F", "#5C9663",
        "#4E9384", "#578FA6", "#5F76A6", "#6F67A2", "#9061A3",
    ]

    /// Popover order: three rows of ten (README §8).
    public static let rows = [pastel, mid, deep]
    public static let all = pastel + mid + deep

    public static let defaultColor = mid[7]

    /// How far a chapter colour is mixed toward the canvas before it paints a
    /// cell — bands read darker when zoomed out so dense rows stay legible
    /// (README §4, cell state 3).
    public static func gridMix(for zoom: ZoomLevel) -> Double {
        switch zoom {
        case .small: return 0.40
        case .medium: return 0.26
        case .large: return 0.20
        }
    }
}
