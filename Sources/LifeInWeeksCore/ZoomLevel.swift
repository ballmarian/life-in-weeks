import Foundation

/// Grid density (README §4). Geometry lives here rather than in the view so the
/// numbers are one table, testable and shared by drawing and hit-testing.
public enum ZoomLevel: String, Codable, Sendable, CaseIterable {
    case small = "S"
    case medium = "M"
    case large = "L"

    public struct Geometry: Sendable {
        public let cell: Double
        public let gap: Double
        public let radius: Double
        public let labelWidth: Double
        public let labelGap: Double
        /// Corner note tick, as a fraction of the cell.
        public let tickFraction: Double
        public let showsEmoji: Bool
        /// Row-label type size.
        public let labelFontSize: Double

        /// Row pitch: a cell plus one gap.
        public var pitch: Double { cell + gap }
        /// Left edge of column 0.
        public var gridOriginX: Double { labelWidth + labelGap }
    }

    public var geometry: Geometry {
        switch self {
        case .small:
            return Geometry(cell: 9, gap: 1, radius: 0, labelWidth: 40, labelGap: 6,
                            tickFraction: 0.42, showsEmoji: false, labelFontSize: 9)
        case .medium:
            return Geometry(cell: 13, gap: 2, radius: 2, labelWidth: 50, labelGap: 8,
                            tickFraction: 0.30, showsEmoji: true, labelFontSize: 9)
        case .large:
            return Geometry(cell: 22, gap: 2, radius: 5, labelWidth: 58, labelGap: 8,
                            tickFraction: 0.24, showsEmoji: true, labelFontSize: 10)
        }
    }
}
