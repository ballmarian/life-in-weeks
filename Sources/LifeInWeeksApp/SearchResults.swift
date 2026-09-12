import LifeInWeeksCore
import SwiftUI

/// The inspector column while a search is live: every note whose text matches,
/// newest week first. Picking one opens that week in the same column, with the
/// back bar returning here — the query is never cleared along the way.
struct SearchResultsList: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()
            if model.searchResults.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.searchResults) { result in
                            row(result)
                            Hairline().opacity(0.6)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SEARCH NOTES")
                .font(Typography.ui(10))
                .tracking(0.6)
                .foregroundColor(palette.tertiary)
            Text(countLine)
                .font(Typography.ui(13, .semibold))
                .foregroundColor(palette.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var countLine: String {
        let count = model.searchResults.count
        let noun = count == 1 ? "note" : "notes"
        return "\(count) \(noun) matching “\(model.searchText.trimmingCharacters(in: .whitespacesAndNewlines))”"
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing here.")
                .font(Typography.ui(12.5))
                .foregroundColor(palette.placeholder)
            Text("Search looks at the text of every week's note.")
                .font(Typography.ui(11))
                .foregroundColor(palette.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func row(_ result: NoteSearchResult) -> some View {
        let isOpen = result.week == model.selectedWeek
        return Button {
            model.openSearchResult(week: result.week)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.monday(of: result.week)?.iso ?? "")
                        .font(Typography.mono(10.5))
                        .foregroundColor(palette.quaternary)
                    if let emoji = result.emoji, !emoji.isEmpty {
                        Text(emoji).font(.system(size: 11))
                    }
                    Spacer(minLength: 0)
                }
                snippet(result)
                    .font(Typography.ui(12))
                    .lineSpacing(12 * 0.4)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isOpen ? palette.accent.opacity(0.16) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowButtonStyle())
    }

    /// The snippet with the matched run picked out. Built by concatenating
    /// `Text` runs rather than an `AttributedString`, which keeps the styling
    /// on macOS 13's SwiftUI (PRD §8).
    private func snippet(_ result: NoteSearchResult) -> Text {
        let characters = Array(result.snippet)
        let start = min(max(0, result.matchRange.lowerBound), characters.count)
        let end = min(max(start, result.matchRange.upperBound), characters.count)
        return Text(String(characters[..<start])).foregroundColor(palette.secondary)
            + Text(String(characters[start ..< end]))
                .foregroundColor(palette.primary)
                .fontWeight(.semibold)
            + Text(String(characters[end...])).foregroundColor(palette.secondary)
    }
}
