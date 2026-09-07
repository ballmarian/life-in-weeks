import LifeInWeeksCore
import SwiftUI

/// The 50px toolbar: row layout, zoom, the zoom hint, and search (README §2).
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

            Text(model.zoom.hint)
                .font(Typography.mono(10.5))
                .foregroundColor(palette.tertiary)
                .lineLimit(1)

            Spacer(minLength: 8)

            // Search is scoped to v1.1 (PRD §6.2); the field is present and
            // takes text, but nothing filters on it yet.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(palette.placeholder)
                TextField("", text: $model.searchText,
                          prompt: Text("Search notes").foregroundColor(palette.placeholder))
                    .textFieldStyle(.plain)
                    .font(Typography.ui(12))
                    .foregroundColor(palette.primary)
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
