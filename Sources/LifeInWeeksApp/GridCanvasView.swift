import LifeInWeeksCore
import SwiftUI

/// The week grid.
///
/// Drawn with `Canvas` in immediate mode — at ~4,700 cells a view per cell
/// visibly lags on scroll and zoom (PRD §6.2). Two things keep it cheap: cells
/// are batched into one `Path` per fill colour, so a full redraw is a couple of
/// dozen fills rather than thousands; and hit-testing, hover, and drag-selection
/// all run off the row/column arithmetic in `GridMetrics` instead of per-cell
/// gesture targets.
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
        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let resolution = model.resolution
            let highlightSpan = model.highlightedChapterID.flatMap { resolution?.span(of: $0) }
            let radius = metrics.geometry.radius

            // One path per distinct fill, so the whole grid is a handful of
            // draw calls however many cells it holds.
            var unlived = Path()
            var lived = Path()
            var ticks = Path()
            var chapterFills: [Int: Path] = [:]
            var chapterUnderlines: [Int: Path] = [:]
            var highlighted = Path()
            var emoji: [(String, CGPoint)] = []
            // Every cell, used once as a clip so corner ticks can't overhang a
            // rounded corner. One clip beats intersecting 4,700 paths.
            var allCells = Path()

            for gridRow in layout.rows {
                for column in 0 ..< gridRow.count {
                    let week = gridRow.firstWeek + column
                    let rect = metrics.cellRect(row: gridRow.index, column: column)
                    let shape = Path(roundedRect: rect, cornerRadius: radius)
                    allCells.addPath(shape)

                    if highlightSpan?.contains(week) == true {
                        highlighted.addPath(shape)
                    } else if let index = resolution?.backgroundChapterIndex(week: week) {
                        chapterFills[index, default: Path()].addPath(shape)
                        // A chapter can run past today; the cell still reads as
                        // unlived, so it keeps its hairline over the band.
                        if model.isFuture(week: week) {
                            unlived.addPath(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                                 cornerRadius: max(0, radius - 0.5)))
                        } else if model.zoom == .large {
                            chapterUnderlines[index, default: Path()].addPath(Path(CGRect(
                                x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3)))
                        }
                    } else if model.isFuture(week: week) {
                        // Inset by half a line width so the hairline lands
                        // inside the cell rather than straddling its edge.
                        unlived.addPath(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                             cornerRadius: max(0, radius - 0.5)))
                    } else {
                        lived.addPath(shape)
                    }

                    guard let note = model.note(at: week) else { continue }
                    if metrics.geometry.showsEmoji, let glyph = note.emoji, !glyph.isEmpty {
                        emoji.append((glyph, CGPoint(x: rect.midX, y: rect.midY)))
                    } else {
                        ticks.addPath(cornerTick(in: rect, metrics: metrics))
                    }
                }
            }

            // Cell states 1–3 and 11, in the order README §4 lays them out.
            context.fill(lived, with: .color(palette.cellLived))
            if let resolution {
                for (index, path) in chapterFills {
                    context.fill(path, with: .color(
                        palette.chapterFill(resolution.chapters[index].color, zoom: model.zoom)))
                }
                for (index, path) in chapterUnderlines {
                    context.fill(path, with: .color(
                        palette.chapterUnderline(resolution.chapters[index].color)))
                }
                if let id = model.highlightedChapterID, let chapter = resolution.chapter(id: id) {
                    // Highlighted cells show the chapter's raw colour, unmixed.
                    context.fill(highlighted, with: .color(Color(hex: chapter.color)))
                }
            }
            context.stroke(unlived, with: .color(palette.cellHairline), lineWidth: 1)

            // States 4 and 5: the corner tick, or the emoji that replaces it.
            context.drawLayer { layer in
                layer.clip(to: allCells)
                layer.fill(ticks, with: .color(palette.noteTick))
            }
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

    /// The top-left corner triangle marking a week that has a note. Drawn
    /// unclipped here; the caller clips the whole batch to the cell shapes.
    private func cornerTick(in rect: CGRect, metrics: GridMetrics) -> Path {
        let size = rect.width * metrics.geometry.tickFraction * 2
        var triangle = Path()
        triangle.move(to: CGPoint(x: rect.minX, y: rect.minY))
        triangle.addLine(to: CGPoint(x: rect.minX + size, y: rect.minY))
        triangle.addLine(to: CGPoint(x: rect.minX, y: rect.minY + size))
        triangle.closeSubpath()
        return triangle
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
    @ViewBuilder
    private func tooltip(timeline: Timeline, metrics: GridMetrics) -> some View {
        if let week = model.hoveredWeek, let point = model.tooltipPoint, !model.isDragging {
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
            let week = metrics.week(at: point, layout: layout)
            if model.hoveredWeek != week { model.hoveredWeek = week }
            model.tooltipPoint = week == nil ? nil : point

            // A cell covered by more than one chapter reveals the newest of
            // them across its whole extent; a single covering chapter has
            // nothing hidden to show (PRD §6.6).
            guard !model.isDragging else { return }
            if let week, let resolution = model.resolution,
               resolution.revealsNestedChapter(week: week),
               let chapter = resolution.hoverChapter(week: week) {
                model.highlightedChapterID = chapter.id
            } else if model.highlightedChapterID != nil {
                model.highlightedChapterID = nil
            }
        case .ended:
            clearHover()
        }
    }

    /// Leaving the canvas clears hover, tooltip, highlight, and any drag in
    /// progress (README §Interactions).
    private func clearHover() {
        model.hoveredWeek = nil
        model.tooltipPoint = nil
        model.highlightedChapterID = nil
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
                if let current = metrics.week(at: value.location, layout: layout) {
                    // A contiguous chronological range, never a rectangle: a
                    // drag down three rows takes every week in between.
                    model.selection = min(anchor, current) ... max(anchor, current)
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

