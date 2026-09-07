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
            Text(meta)
                .font(Typography.mono(10.5))
                .foregroundColor(palette.secondary)
            if let nested {
                Rectangle()
                    .fill(palette.tooltipHairline)
                    .frame(height: 1)
                    .padding(.vertical, 2)
                Text(nested)
                    .font(Typography.ui(10))
                    .foregroundColor(palette.secondary)
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

    /// A chapter title if the week sits in one, else the note, else why not.
    private var headline: String {
        if let chapter = model.resolution?.hoverChapter(week: week) {
            return chapter.title
        }
        if let note = model.note(at: week), let line = note.firstLine {
            return [note.emoji, line].compactMap { $0 }.joined(separator: " ")
        }
        if let note = model.note(at: week), let emoji = note.emoji {
            return emoji
        }
        return model.isFuture(week: week) ? "Not yet lived" : "No note"
    }

    /// `2011-06-13 · age 33 · 2011-W24`
    private var meta: String {
        let monday = timeline.monday(of: week)
        return "\(monday.iso) · age \(timeline.age(atWeek: week)) · \(monday.isoWeekLabel)"
    }

    /// Only shown where two or more chapters cover the week — naming the one
    /// underneath is the point of the reveal.
    private var nested: String? {
        guard let resolution = model.resolution,
              resolution.revealsNestedChapter(week: week),
              let underneath = resolution.backgroundChapter(week: week) else { return nil }
        return "Nested chapter — full extent highlighted. Under it: \(underneath.title)"
    }
}
