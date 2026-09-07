import CoreGraphics
import LifeInWeeksCore

/// Turns a zoom level and a row layout into coordinates.
///
/// All of it is arithmetic on the row/column grid, which is what lets the canvas
/// draw ~4,700 cells without a view per cell and still know what the cursor is
/// over (PRD §6.2).
struct GridMetrics {
    let zoom: ZoomLevel
    let geometry: ZoomLevel.Geometry
    let rowCount: Int
    let widestRow: Int

    static let padding = (top: 16.0, side: 14.0, bottom: 26.0)

    init(zoom: ZoomLevel, layout: RowLayout) {
        self.zoom = zoom
        self.geometry = zoom.geometry
        self.rowCount = layout.rows.count
        self.widestRow = layout.widestRow
    }

    /// Left edge of column 0.
    var gridOriginX: Double { GridMetrics.padding.side + geometry.gridOriginX }

    var contentWidth: Double {
        gridOriginX + Double(widestRow) * geometry.pitch - geometry.gap + GridMetrics.padding.side
    }

    var contentHeight: Double {
        GridMetrics.padding.top + Double(rowCount) * geometry.pitch - geometry.gap
            + GridMetrics.padding.bottom
    }

    func cellOrigin(row: Int, column: Int) -> CGPoint {
        CGPoint(
            x: gridOriginX + Double(column) * geometry.pitch,
            y: GridMetrics.padding.top + Double(row) * geometry.pitch + geometry.gap / 2
        )
    }

    func cellRect(row: Int, column: Int) -> CGRect {
        CGRect(origin: cellOrigin(row: row, column: column),
               size: CGSize(width: geometry.cell, height: geometry.cell))
    }

    /// A merged rectangle spanning several columns and rows — the chapter
    /// highlight outline is drawn from these rather than per cell (README §5).
    func blockRect(row: Int, column: Int, columns: Int, rows: Int) -> CGRect {
        CGRect(
            x: gridOriginX + Double(column) * geometry.pitch,
            y: GridMetrics.padding.top + Double(row) * geometry.pitch + geometry.gap / 2,
            width: Double(columns) * geometry.pitch - geometry.gap,
            height: Double(rows) * geometry.pitch - geometry.gap
        )
    }

    /// Right edge of the row-label column, for right-aligned label drawing.
    func labelAnchor(row: Int) -> CGPoint {
        CGPoint(
            x: GridMetrics.padding.side + geometry.labelWidth,
            y: GridMetrics.padding.top + Double(row) * geometry.pitch + geometry.pitch / 2
        )
    }

    /// Which week is under a point, or `nil` if it's in a gap, a margin, or past
    /// the end of a short row — releasing there cancels a drag silently.
    func week(at point: CGPoint, layout: RowLayout) -> Int? {
        let y = point.y - GridMetrics.padding.top
        let x = point.x - gridOriginX
        guard y >= 0, x >= 0 else { return nil }

        let row = Int(y / geometry.pitch)
        let column = Int(x / geometry.pitch)
        guard row >= 0, row < layout.rows.count else { return nil }
        let gridRow = layout.rows[row]
        guard column >= 0, column < gridRow.count else { return nil }

        // Reject the gaps between cells so "released outside any cell" is real.
        let rect = cellRect(row: row, column: column)
        guard rect.contains(point) else { return nil }
        return gridRow.firstWeek + column
    }
}
