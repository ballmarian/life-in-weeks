import LifeInWeeksCore
import SwiftUI

/// The 300px right column: the selected week, read or edit, plus the legend
/// (README §7).
struct WeekInspector: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.showingSearchResults {
                SearchResultsList(model: model)
            } else if let timeline = model.timeline, let week = model.selectedWeek {
                VStack(spacing: 0) {
                    if model.isSearching { backToResults }
                    content(week: week, timeline: timeline)
                }
            } else {
                Spacer()
            }
            legend
        }
        .frame(width: 300)
        .background(palette.sidebar)
        .overlay(alignment: .leading) { Hairline(axis: .vertical) }
    }

    /// Sits above the note whenever a search is live, so an opened match is
    /// one click from the list it came from.
    private var backToResults: some View {
        VStack(spacing: 0) {
            Button { model.returnToSearchResults() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                    Text(model.searchResults.count == 1
                         ? "Back to 1 result"
                         : "Back to \(model.searchResults.count) results")
                        .font(Typography.ui(11.5))
                    Spacer(minLength: 0)
                }
                .foregroundColor(palette.accent)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverRowButtonStyle())
            Hairline()
        }
    }

    @ViewBuilder
    private func content(week: Int, timeline: Timeline) -> some View {
        let monday = timeline.monday(of: week)
        let note = model.note(at: week)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(kicker(week: week, timeline: timeline))
                        .font(Typography.ui(10))
                        .tracking(0.6)
                        .foregroundColor(palette.tertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(monday.mediumDisplay)
                            .font(Typography.ui(17, .semibold))
                            .foregroundColor(palette.primary)
                        if let emoji = note?.emoji, !emoji.isEmpty {
                            Text(emoji).font(.system(size: 19))
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 8)

                if !model.isEditing {
                    Button("Edit week") {
                        model.beginEditing()
                        noteFocused = true
                    }
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white,
                                                   expands: false))
                    .fixedSize()
                    .padding(.top, 2)
                }
            }

            Text("age \(timeline.age(atWeek: week)) · \(monday.isoWeekLabel) · Mon–Sun")
                .font(Typography.mono(11))
                .foregroundColor(palette.quaternary)
                .padding(.top, 4)

            chapterList(week: week)
                .padding(.top, 10)

            Hairline().padding(.vertical, 12)

            if model.isEditing {
                editor
            } else {
                noteBody(note: note, week: week)
            }

            Spacer(minLength: 16)

            footer(week: week)
        }
        .padding(16)
    }

    /// "This week", "Future week", or the week's ordinal in the whole life.
    private func kicker(week: Int, timeline: Timeline) -> String {
        if week == model.currentWeek { return "THIS WEEK" }
        if week > model.currentWeek { return "FUTURE WEEK" }
        return "WEEK \(week + 1) OF \(timeline.weekCount)"
    }

    /// Every chapter the week belongs to, earliest start first — the same order
    /// the tooltip lists them in, so an overlap reads as the band it sits in
    /// plus whatever nests inside it.
    @ViewBuilder
    private func chapterList(week: Int) -> some View {
        let chapters = model.resolution?.coveringChapters(week: week) ?? []
        if chapters.isEmpty {
            Text("No chapter")
                .font(Typography.ui(11.5))
                .foregroundColor(palette.placeholder)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(chapters) { chapter in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: chapter.color))
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(palette.swatchHairline, lineWidth: 1))
                            .frame(width: 11, height: 11)
                        Text(chapter.title)
                            .font(Typography.ui(11.5))
                            .foregroundColor(palette.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// Click-to-edit: the whole note block is the target, with a hover surface
    /// that extends past the text.
    @ViewBuilder
    private func noteBody(note: WeekNote?, week: Int) -> some View {
        let body = note?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Button {
            model.beginEditing()
            noteFocused = true
        } label: {
            Group {
                if body.isEmpty {
                    Text(model.isFuture(week: week)
                         ? "Nothing here yet — but you can write ahead."
                         : "No note for this week.")
                        .foregroundColor(palette.placeholder)
                } else {
                    Text(body).foregroundColor(palette.primary)
                }
            }
            .font(Typography.ui(12.5))
            .lineSpacing(12.5 * 0.55)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoteBodyButtonStyle())
        .padding(.horizontal, -8)
        .padding(.vertical, -6)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $model.draftNote)
                .focused($noteFocused)
                .font(Typography.ui(12.5))
                .lineSpacing(12.5 * 0.55)
                .foregroundColor(palette.primary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(height: 190)
                .background(RoundedRectangle(cornerRadius: 7).fill(palette.fieldFill))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(palette.fieldHairline, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if model.draftNote.isEmpty {
                        Text("What happened this week?")
                            .font(Typography.ui(12.5))
                            .foregroundColor(palette.placeholder)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                EmojiField(emoji: $model.draftEmoji)
                    .frame(width: 44)
                // The design's caption (README §7), plus the hint that the
                // field opens the system picker.
                Text("Emoji shown in the cell · click to pick")
                    .font(Typography.ui(10.5))
                    .foregroundColor(palette.tertiary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button("Save") { model.saveEdit() }
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white))
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Cancel") { model.cancelEditing() }
                    .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                                   foreground: palette.primary, weight: .regular))
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    @ViewBuilder
    private func footer(week: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Hairline()
            Text(model.relativePath(of: week) ?? "")
                .font(Typography.mono(10.5))
                .foregroundColor(palette.quaternary)
                .padding(.top, 6)
            Button("Reveal in Finder") { model.revealInFinder(week: week) }
                .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                               foreground: palette.primary, weight: .regular))
                .padding(.top, 2)
        }
    }

    private var legend: some View {
        VStack(spacing: 0) {
            Hairline()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                      alignment: .leading, spacing: 8) {
                legendItem("Has a note", fill: palette.cellLived, tick: true)
                legendItem("Lived, empty", fill: palette.cellLived, tick: false)
                legendItem("Not yet lived", fill: .clear, tick: false, hairline: true)
                legendItem("This week", fill: .clear, tick: false, ring: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    private func legendItem(
        _ label: String,
        fill: Color,
        tick: Bool,
        hairline: Bool = false,
        ring: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2).fill(fill)
                if tick {
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: 6, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 6))
                        path.closeSubpath()
                    }
                    .fill(palette.noteTick)
                }
                if hairline {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(palette.cellHairline, lineWidth: 1)
                }
                if ring {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(palette.accent, lineWidth: 2)
                }
            }
            .frame(width: 11, height: 11)
            Text(label)
                .font(Typography.ui(10.5))
                .foregroundColor(palette.tertiary)
                .lineLimit(1)
        }
    }
}

/// The note block's hover surface, which extends past the text itself.
private struct NoteBodyButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? palette.primary.opacity(0.06) : .clear))
            .onHover { hovering = $0 }
    }
}
