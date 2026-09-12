import LifeInWeeksCore
import SwiftUI

/// The week grid.
///
/// Drawn with `Canvas` in immediate mode — at ~4,700 cells a view per cell
/// visibly lags on scroll and zoom (PRD §6.2). Hit-testing, hover, and
/// drag-selection all run off the row/column arithmetic in `GridMetrics`
/// rather than per-cell gesture targets, which is what keeps that affordable.
///
/// Filled cells are drawn one `fill` call each. Batching them into one `Path`
/// per colour is the obvious optimisation and it renders incorrectly: a fill
/// of more than one rounded-rect subpath comes back with cells displaced by a
/// device pixel across a band of scanlines, in a pattern that drifts over the
/// grid. Two subpaths in a path is enough to trigger it; square subpaths are
/// unaffected, so it is the corner curves. Measured against per-cell fills the
/// batching saved ~0.1 ms on a full-grid redraw, so there is nothing to weigh
/// against correctness here. The `unlived` hairline is *stroked*, which does
/// not suffer from this, and stays batched as one path.
struct GridCanvasView: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette
    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        if let layout = model.layout, let timeline = model.timeline {
            let metrics = GridMetrics(zoom: model.zoom, layout: layout)
            ScrollView([.horizontal, .vertical]) {
                canvas(layout: layout, metrics: metrics)
                    .frame(width: metrics.contentWidth, height: metrics.contentHeight)
                    .overlay(alignment: .topLeading) {
                        tooltip(timeline: timeline, metrics: metrics)
                    }
                    .contentShape(Rectangle())
                    .gesture(dragGesture(layout: layout, metrics: metrics))
                    .onContinuousHover { handleHover($0, layout: layout, metrics: metrics) }
            }
            .background(palette.canvas)
            .onDisappear(perform: clearHover)
        } else {
            Color.clear
        }
    }

    // MARK: - Drawing

    private func canvas(layout: RowLayout, metrics: GridMetrics) -> some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            // The canvas paints its own ground rather than letting the scroll
            // view's background show through. An opaque canvas covers every
            // pixel of a partial redraw, so a scroll or resize that repaints
            // only part of the grid can't blend over what was already there.
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.canvas))

            let resolution = model.resolution
            let highlightSpan = model.highlightedChapterID.flatMap { resolution?.span(of: $0) }
            let radius = metrics.geometry.radius

            // One path per distinct fill, so the whole grid is a handful of
            // draw calls however many cells it holds.
            var unlived = Path()
            var lived: [CGRect] = []
            var ticks: [Path] = []
            var chapterFills: [Int: [CGRect]] = [:]
            var chapterUnderlines: [Int: [CGRect]] = [:]
            var splits: [(rect: CGRect, chapters: [Chapter])] = []
            var highlighted: [CGRect] = []
            var emoji: [(String, CGPoint)] = []

            for gridRow in layout.rows {
                for column in 0 ..< gridRow.count {
                    let week = gridRow.firstWeek + column
                    let rect = metrics.cellRect(row: gridRow.index, column: column)

                    if highlightSpan?.contains(week) == true {
                        highlighted.append(rect)
                    } else if let resolution, resolution.coveringCount(week: week) > 1 {
                        // Split between its chapters rather than painted by the
                        // oldest of them. The L-zoom underline is dropped here:
                        // the split already runs the full height of the cell.
                        splits.append((rect, Array(resolution.coveringChapters(week: week)
                            .prefix(ChapterResolution.maxOverlap))))
                        if model.isFuture(week: week) {
                            unlived.addPath(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                                 cornerRadius: max(0, radius - 0.5)))
                        }
                    } else if let index = resolution?.backgroundChapterIndex(week: week) {
                        // A chapter can run past today; the cell still reads as
                        // unlived, so it keeps its hairline over the band.
                        if model.isFuture(week: week) {
                            chapterFills[index, default: []].append(rect)
                            unlived.addPath(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                                 cornerRadius: max(0, radius - 0.5)))
                        } else if model.zoom == .large {
                            // Drawn by the underline pass, which lays the fill
                            // back over the band.
                            chapterUnderlines[index, default: []].append(rect)
                        } else {
                            chapterFills[index, default: []].append(rect)
                        }
                    } else if model.isFuture(week: week) {
                        // Inset by half a line width so the hairline lands
                        // inside the cell rather than straddling its edge.
                        unlived.addPath(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                             cornerRadius: max(0, radius - 0.5)))
                    } else {
                        lived.append(rect)
                    }

                    guard let note = model.note(at: week) else { continue }
                    if metrics.geometry.showsEmoji, let glyph = note.emoji, !glyph.isEmpty {
                        emoji.append((glyph, CGPoint(x: rect.midX, y: rect.midY)))
                    } else {
                        ticks.append(cornerTick(in: rect, metrics: metrics))
                    }
                }
            }

            // Cell states 1–3 and 11, in the order README §4 lays them out.
            func fillCells(_ rects: [CGRect], _ color: Color) {
                let shading = GraphicsContext.Shading.color(color)
                for rect in rects {
                    context.fill(Path(roundedRect: rect, cornerRadius: radius), with: shading)
                }
            }
            fillCells(lived, palette.cellLived)
            if let resolution {
                for (index, rects) in chapterFills {
                    fillCells(rects, palette.chapterFill(resolution.chapters[index].color,
                                                         zoom: model.zoom))
                }
                for (index, rects) in chapterUnderlines {
                    let chapter = resolution.chapters[index]
                    let band = GraphicsContext.Shading.color(palette.chapterUnderline(chapter.color))
                    let fill = GraphicsContext.Shading.color(
                        palette.chapterFill(chapter.color, zoom: model.zoom))
                    for rect in rects {
                        // The whole cell in the band colour, then the fill laid
                        // back over everything above the band. Stamping a square
                        // band over the bottom 3pt instead squares off the cell's
                        // rounded bottom corners, which is what it looked like.
                        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: band)
                        context.fill(cellTop(rect, radius: radius, inset: 3), with: fill)
                    }
                }
                drawSplitCells(context: context, splits: splits, radius: radius)
                if let id = model.highlightedChapterID, let chapter = resolution.chapter(id: id) {
                    // Highlighted cells show the chapter's raw colour, unmixed.
                    fillCells(highlighted, Color(hex: chapter.color))
                }
            }
            context.stroke(unlived, with: .color(palette.cellHairline), lineWidth: 1)

            // States 4 and 5: the corner tick, or the emoji that replaces it.
            let tickShading = GraphicsContext.Shading.color(palette.noteTick)
            for tick in ticks { context.fill(tick, with: tickShading) }
            let emojiFont = Font.system(size: metrics.geometry.cell * 0.7)
            for (glyph, point) in emoji {
                context.draw(Text(verbatim: glyph).font(emojiFont), at: point, anchor: .center)
            }

            drawRowLabels(context: context, layout: layout, metrics: metrics)
            drawRings(context: context, layout: layout, metrics: metrics)
            if let span = highlightSpan {
                drawChapterOutline(context: context, span: span, layout: layout, metrics: metrics)
            }
        }
    }

    /// The top-left corner triangle marking a week that has a note.
    ///
    /// Its right angle is replaced by the cell's own corner arc, so the tick
    /// lands inside the cell by construction and needs no clip. Clipping the
    /// batch to all ~4,700 cell shapes instead put a transparency layer over
    /// the whole grid, and compositing that back resampled the grid whenever
    /// scrolling or resizing left the canvas on a fractional pixel — the cells
    /// came back with their edges eroded.
    private func cornerTick(in rect: CGRect, metrics: GridMetrics) -> Path {
        let size = rect.width * metrics.geometry.tickFraction * 2
        let radius = min(metrics.geometry.radius, size)
        var tick = Path()
        tick.move(to: CGPoint(x: rect.minX + size, y: rect.minY))
        tick.addLine(to: CGPoint(x: rect.minX, y: rect.minY + size))
        tick.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        if radius > 0 {
            // The standard quarter-circle Bezier, so the tick's corner is the
            // same curve `Path(roundedRect:)` gives the cell under it.
            let k = radius * 0.5523
            tick.addCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control1: CGPoint(x: rect.minX, y: rect.minY + radius - k),
                          control2: CGPoint(x: rect.minX + radius - k, y: rect.minY))
        } else {
            tick.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        tick.closeSubpath()
        return tick
    }

    /// Cells covered by more than one chapter (README §4).
    ///
    /// Two chapters split the cell corner to corner, the later one taking the
    /// upper-left half so the newer chapter reads first. Three or four split it
    /// into equal vertical bars, earliest on the left. In both cases the whole
    /// cell is painted in the earliest chapter's colour first and the rest laid
    /// over it, which keeps every piece inside the cell's rounded shape without
    /// a clip — see this type's note on clipping.
    private func drawSplitCells(
        context: GraphicsContext,
        splits: [(rect: CGRect, chapters: [Chapter])],
        radius: Double
    ) {
        for (rect, chapters) in splits {
            let colors = chapters.map { palette.chapterFill($0.color, zoom: model.zoom) }
            guard let earliest = colors.first else { continue }
            context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(earliest))

            if colors.count == 2 {
                context.fill(cellUpperLeft(rect, radius: radius), with: .color(colors[1]))
                continue
            }
            let width = rect.width / Double(colors.count)
            for (position, color) in colors.enumerated().dropFirst() {
                let x = rect.minX + width * Double(position)
                let bar = position == colors.count - 1
                    ? cellRight(rect, radius: radius, from: x)
                    // Interior bars never reach a corner arc: the narrowest bar
                    // the cap allows is still wider than the radius.
                    : Path(CGRect(x: x, y: rect.minY, width: width, height: rect.height))
                context.fill(bar, with: .color(color))
            }
        }
    }

    /// The half of a corner's quarter-arc nearer its start, as (control points,
    /// endpoint). The standard control offset is chosen so the curve's t = 0.5
    /// point sits exactly on the circle at 45° — which is where a corner-to-
    /// corner diagonal crosses the arc — so de Casteljau at 0.5 splits it there.
    private func halfArc(
        from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint
    ) -> (control1: CGPoint, control2: CGPoint, midpoint: CGPoint) {
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        let p01 = mid(start, control1)
        let p12 = mid(control1, control2)
        let p012 = mid(p01, p12)
        let midpoint = mid(p012, mid(p12, mid(control2, end)))
        return (p01, p012, midpoint)
    }

    /// The cell above the diagonal from its bottom-left corner to its top-right
    /// one, keeping the cell's own corner arcs.
    private func cellUpperLeft(_ rect: CGRect, radius: Double) -> Path {
        var path = Path()
        guard radius > 0 else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
        let k = radius * 0.5523
        let topEdge = CGPoint(x: rect.maxX - radius, y: rect.minY)
        let topRight = halfArc(
            from: topEdge,
            control1: CGPoint(x: topEdge.x + k, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + radius - k),
            to: CGPoint(x: rect.maxX, y: rect.minY + radius))
        let leftEdge = CGPoint(x: rect.minX, y: rect.maxY - radius)
        let bottomLeft = halfArc(
            from: leftEdge,
            control1: CGPoint(x: rect.minX, y: leftEdge.y + k),
            control2: CGPoint(x: rect.minX + radius - k, y: rect.maxY),
            to: CGPoint(x: rect.minX + radius, y: rect.maxY))

        path.move(to: topRight.midpoint)
        // Back down the same half-arc, so its controls come in reversed.
        path.addCurve(to: topEdge, control1: topRight.control2, control2: topRight.control1)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + radius),
                      control1: CGPoint(x: rect.minX + radius - k, y: rect.minY),
                      control2: CGPoint(x: rect.minX, y: rect.minY + radius - k))
        path.addLine(to: leftEdge)
        path.addCurve(to: bottomLeft.midpoint,
                      control1: bottomLeft.control1, control2: bottomLeft.control2)
        // Closing draws the diagonal, both ends of it on a corner arc.
        path.closeSubpath()
        return path
    }

    /// The cell from `x` rightwards: square on the left, the cell's own arcs on
    /// the right. The last bar of a vertical split.
    private func cellRight(_ rect: CGRect, radius: Double, from x: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.minY))
        if radius > 0 {
            let k = radius * 0.5523
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                          control1: CGPoint(x: rect.maxX - radius + k, y: rect.minY),
                          control2: CGPoint(x: rect.maxX, y: rect.minY + radius - k))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control1: CGPoint(x: rect.maxX, y: rect.maxY - radius + k),
                          control2: CGPoint(x: rect.maxX - radius + k, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: x, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    /// A cell with its bottom `inset` points cut off square: rounded top
    /// corners, flat bottom. Laid over the underline band so the band shows
    /// only where the cell's own rounded shape allows (README §4, L zoom).
    private func cellTop(_ rect: CGRect, radius: Double, inset: Double) -> Path {
        let bottom = rect.maxY - inset
        let k = radius * 0.5523
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                      control1: CGPoint(x: rect.minX, y: rect.minY + radius - k),
                      control2: CGPoint(x: rect.minX + radius - k, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                      control1: CGPoint(x: rect.maxX - radius + k, y: rect.minY),
                      control2: CGPoint(x: rect.maxX, y: rect.minY + radius - k))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        path.closeSubpath()
        return path
    }

    private func drawRowLabels(context: GraphicsContext, layout: RowLayout, metrics: GridMetrics) {
        let size = metrics.geometry.labelFontSize
        let compact = metrics.geometry.cell < 13
        for gridRow in layout.rows {
            var text = context.resolve(Text(verbatim: layout.label(for: gridRow, compact: compact))
                .font(Typography.mono(size, gridRow.isDecade ? .semibold : .regular)))
            text.shading = .color(gridRow.isDecade ? palette.decadeLabel : palette.tertiary)
            context.draw(text, at: metrics.labelAnchor(row: gridRow.index), anchor: .trailing)
        }
    }

    /// States 8–10: the drag selection, the current week, and the hovered cell.
    private func drawRings(context: GraphicsContext, layout: RowLayout, metrics: GridMetrics) {
        let radius = metrics.geometry.radius

        if let range = model.selection, model.isDragging || model.popoverOpen {
            var path = Path()
            for week in range {
                guard let position = layout.position(of: week) else { continue }
                let rect = metrics.cellRect(row: position.row, column: position.column)
                path.addPath(Path(roundedRect: rect.insetBy(dx: 1, dy: 1),
                                  cornerRadius: max(0, radius - 1)))
            }
            context.stroke(path, with: .color(palette.accent), lineWidth: 2)
        }

        if let position = layout.position(of: model.currentWeek) {
            let rect = metrics.cellRect(row: position.row, column: position.column)
            context.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: radius + 1),
                           with: .color(palette.accent), lineWidth: 2)
        }

        if let hovered = model.hoveredWeek, let position = layout.position(of: hovered) {
            let rect = metrics.cellRect(row: position.row, column: position.column)
            context.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: radius + 1),
                           with: .color(palette.hoverRing), lineWidth: 2)
        }
    }

    /// One continuous outline around the chapter's whole extent: the partial
    /// first row, runs of equal-width complete rows merged into single tall
    /// rectangles, then the partial last row (README §5). A 15-year chapter
    /// draws as three or four rectangles, not ~780 cell outlines.
    private func drawChapterOutline(
        context: GraphicsContext,
        span: ClosedRange<Int>,
        layout: RowLayout,
        metrics: GridMetrics
    ) {
        guard let first = layout.position(of: span.lowerBound),
              let last = layout.position(of: span.upperBound) else { return }

        var rects: [CGRect] = []
        if first.row == last.row {
            rects.append(metrics.blockRect(row: first.row, column: first.column,
                                           columns: last.column - first.column + 1, rows: 1))
        } else {
            rects.append(metrics.blockRect(
                row: first.row, column: first.column,
                columns: layout.rows[first.row].count - first.column, rows: 1))

            // Merge runs of equal-width rows; Calendar Year mode mixes 52- and
            // 53-cell rows, which can't share one rectangle.
            var row = first.row + 1
            while row < last.row {
                let width = layout.rows[row].count
                var run = 1
                while row + run < last.row, layout.rows[row + run].count == width { run += 1 }
                rects.append(metrics.blockRect(row: row, column: 0, columns: width, rows: run))
                row += run
            }

            rects.append(metrics.blockRect(row: last.row, column: 0,
                                           columns: last.column + 1, rows: 1))
        }

        var outline = Path()
        for rect in rects {
            outline.addPath(Path(roundedRect: rect, cornerRadius: metrics.geometry.radius + 2))
        }
        context.stroke(outline, with: .color(palette.chapterOutline), lineWidth: 1.5)
    }

    // MARK: - Tooltip

    /// Lives inside the scrolled content so its coordinates match the hover
    /// point directly, and is clamped to the content so it never hangs off.
    ///
    /// Shown during a drag too, on the cell under the pointer — the moving end
    /// of the range, so the week the block will stop at is named before the
    /// mouse comes up.
    @ViewBuilder
    private func tooltip(timeline: Timeline, metrics: GridMetrics) -> some View {
        if let week = model.hoveredWeek, let point = model.tooltipPoint {
            GridTooltip(model: model, week: week, timeline: timeline)
                .background(SizeReader { tooltipSize = $0 })
                .offset(
                    x: min(point.x + 14, max(0, metrics.contentWidth - tooltipSize.width - 4)),
                    y: min(point.y + 18, max(0, metrics.contentHeight - tooltipSize.height - 4))
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Input

    private func handleHover(_ phase: HoverPhase, layout: RowLayout, metrics: GridMetrics) {
        switch phase {
        case .active(let point):
            // A drag owns the tooltip while it runs; hover events that arrive
            // mid-drag would fight it for the same two properties.
            guard !model.isDragging else { return }
            let week = metrics.week(at: point, layout: layout)
            if model.hoveredWeek != week { model.hoveredWeek = week }
            model.tooltipPoint = week == nil ? nil : point
        case .ended:
            clearHover()
        }
    }

    /// Leaving the canvas clears hover, tooltip, and any drag in progress
    /// (README §Interactions). The chapter highlight belongs to the sidebar,
    /// which sets and clears it on its own hover.
    private func clearHover() {
        model.hoveredWeek = nil
        model.tooltipPoint = nil
        if model.isDragging {
            model.isDragging = false
            model.dragAnchor = nil
            model.selection = nil
        }
    }

    private func dragGesture(layout: RowLayout, metrics: GridMetrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let anchor = model.dragAnchor
                        ?? metrics.week(at: value.startLocation, layout: layout) else { return }
                model.dragAnchor = anchor
                model.isDragging = true
                // The tooltip trails the pointer for the whole drag. Only a
                // real cell moves it to another week, so crossing the gaps
                // between cells doesn't make it blink in and out.
                model.tooltipPoint = value.location
                if let current = metrics.week(at: value.location, layout: layout) {
                    // A contiguous chronological range, never a rectangle: a
                    // drag down three rows takes every week in between.
                    model.selection = min(anchor, current) ... max(anchor, current)
                    model.hoveredWeek = current
                }
            }
            .onEnded { value in
                let anchor = model.dragAnchor
                model.isDragging = false
                model.dragAnchor = nil

                guard let anchor,
                      let released = metrics.week(at: value.location, layout: layout) else {
                    model.selection = nil // released outside any cell: cancel silently
                    return
                }
                if released == anchor {
                    model.selection = nil
                    model.select(week: anchor)
                } else {
                    model.beginNewChapter(over: min(anchor, released) ... max(anchor, released))
                }
            }
    }
}

/// Reports its own size, for positioning something relative to it.
struct SizeReader: View {
    let onChange: (CGSize) -> Void

    init(_ onChange: @escaping (CGSize) -> Void) {
        self.onChange = onChange
    }

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { onChange(proxy.size) }
                .onChange(of: proxy.size) { onChange($0) }
        }
    }
}

