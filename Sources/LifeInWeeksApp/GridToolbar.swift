import LifeInWeeksCore
import SwiftUI

/// The 50px toolbar: row layout, zoom, and search (README §2).
struct GridToolbar: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            SegmentedControl(
                options: [(RowMode.life, "Life Year"), (RowMode.calendar, "Calendar Year")],
                selection: $model.rowMode
            )

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1, height: 22)

            HStack(spacing: 8) {
                Text("Zoom")
                    .font(Typography.ui(11))
                    .foregroundColor(palette.tertiary)
                SegmentedControl(
                    options: ZoomLevel.allCases.map { ($0, $0.rawValue) },
                    selection: $model.zoom,
                    fixedSegmentWidth: 26
                )
            }

            // The nudge the whole app is for (PRD §1), centered in the gap
            // between the controls and search. It truncates rather than
            // squeezing them at a narrow window width.
            Spacer(minLength: 8)
            if let line = model.weeksRemainingLine {
                Text(line)
                    .font(Typography.ui(11.5))
                    .foregroundColor(palette.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
                Spacer(minLength: 8)
            }

            // Typing here searches every note; matches land in the inspector
            // column (PRD §6.2).
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(palette.placeholder)
                TextField("", text: $model.searchText,
                          prompt: Text("Search notes").foregroundColor(palette.placeholder))
                    .textFieldStyle(.plain)
                    .font(Typography.ui(12))
                    .foregroundColor(palette.primary)
                    .onSubmit { model.returnToSearchResults() }
                if model.isSearching {
                    Button { model.clearSearch() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(palette.placeholder)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 210, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.fieldFill))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.fieldHairline, lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(palette.chrome)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
