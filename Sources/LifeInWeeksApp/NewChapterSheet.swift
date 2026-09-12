import LifeInWeeksCore
import SwiftUI

/// The sheet that opens when a drag is released, and again when a sidebar row
/// is edited (README §8). A fixed 30-swatch palette rather than a free picker,
/// so every colour stays legible behind a note tick or emoji (PRD §6.6).
struct NewChapterSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .top) {
            palette.scrim
                .ignoresSafeArea()
                .onTapGesture { model.cancelChapterDraft() }

            sheet
                .padding(.top, 70)
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.editingChapterID == nil ? "New chapter" : "Edit chapter")
                .font(Typography.ui(12.5, .semibold))
                .foregroundColor(palette.primary)

            Text(rangeLine)
                .font(Typography.mono(10.5))
                .foregroundColor(palette.tertiary)

            StyledField(placeholder: "Title", text: $model.draftTitle)

            palettePicker

            if let error = model.chapterDraftError {
                Text(error)
                    .font(Typography.ui(10.5))
                    .foregroundColor(Color(hex: "#FF6961"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { model.cancelChapterDraft() }
                    .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                                   foreground: palette.primary,
                                                   height: 24, weight: .regular))
                    .frame(width: 74)
                    .keyboardShortcut(.cancelAction)
                Button(model.editingChapterID == nil ? "Create" : "Save") {
                    model.commitChapterDraft()
                }
                .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white, height: 24))
                .frame(width: 74)
                .keyboardShortcut(.defaultAction)
                .disabled(model.chapterDraftError != nil)
                .opacity(model.chapterDraftError == nil ? 1 : 0.4)
            }
        }
        .padding(14)
        .frame(width: 334)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.raised))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(palette.fieldHairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.7), radius: 22, y: 20)
    }

    private var palettePicker: some View {
        VStack(spacing: 5) {
            ForEach(Array(ChapterPalette.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { swatch in
                        Button {
                            model.draftColor = swatch
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: swatch))
                                .frame(height: 20)
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(palette.swatchHairline, lineWidth: 1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(palette.accent,
                                                      lineWidth: model.draftColor == swatch ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// `2011-06-13 → 2014-05-05  ·  152 weeks`
    private var rangeLine: String {
        guard let range = model.selection, let timeline = model.timeline else { return "" }
        let start = timeline.monday(of: range.lowerBound)
        let end = timeline.monday(of: range.upperBound)
        let count = range.count
        return "\(start.iso) → \(end.iso)  ·  \(count) \(count == 1 ? "week" : "weeks")"
    }
}
