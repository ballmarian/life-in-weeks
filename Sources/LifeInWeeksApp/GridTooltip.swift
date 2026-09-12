import LifeInWeeksCore
import SwiftUI

/// The hover tooltip (README §6).
///
/// A drawn view rather than `.help()`, because there are no per-cell views to
/// attach a native tooltip to — the grid is one `Canvas` (PRD §6.6).
struct GridTooltip: View {
    @ObservedObject var model: AppModel
    let week: Int
    let timeline: Timeline
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(headline)
                .font(Typography.ui(11.5, .semibold))
                .foregroundColor(palette.primary)
                .lineLimit(1)
            Text(meta)
                .font(Typography.mono(10.5))
                .foregroundColor(palette.secondary)
            if !chapters.isEmpty {
                Rectangle()
                    .fill(palette.tooltipHairline)
                    .frame(height: 1)
                    .padding(.vertical, 2)
                ForEach(chapters) { chapter in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color(hex: chapter.color))
                            .overlay(RoundedRectangle(cornerRadius: 2.5)
                                .strokeBorder(palette.swatchHairline, lineWidth: 1))
                            .frame(width: 9, height: 9)
                        Text(chapter.title)
                            .font(Typography.ui(10.5))
                            .foregroundColor(palette.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .frame(maxWidth: 240, alignment: .leading)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(palette.tooltipFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(palette.tooltipHairline, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.7), radius: 12, y: 8)
    }

    /// The note, else why the week has none.
    private var headline: String {
        if let note = model.note(at: week), let line = note.firstLine {
            return [note.emoji, Self.elided(line)].compactMap { $0 }.joined(separator: " ")
        }
        if let note = model.note(at: week), let emoji = note.emoji {
            return emoji
        }
        return model.isFuture(week: week) ? "Not yet lived" : "No note"
    }

    /// The first line of a note is a preview, not the note: past 30 characters
    /// it's cut and elided, so the tooltip stays one glanceable line whatever
    /// the week holds. `…` matches how search elides its snippets.
    private static func elided(_ line: String) -> String {
        guard line.count > Self.headlineLimit else { return line }
        let kept = line.prefix(Self.headlineLimit)
            .reversed().drop { $0.isWhitespace }.reversed()
        return String(kept) + "…"
    }

    private static let headlineLimit = 30

    /// `2011-06-13 · age 33 · 2011-W24`
    private var meta: String {
        let monday = timeline.monday(of: week)
        return "\(monday.iso) · age \(timeline.age(atWeek: week)) · \(monday.isoWeekLabel)"
    }

    /// Every chapter covering the week, earliest start first — so an overlap
    /// reads as the band it sits in plus whatever nests inside it.
    private var chapters: [Chapter] {
        model.resolution?.coveringChapters(week: week) ?? []
    }
}
