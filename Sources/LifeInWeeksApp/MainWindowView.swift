import LifeInWeeksCore
import SwiftUI

/// The main window: toolbar, three body columns, status bar (README §1).
struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette.forScheme(colorScheme)
        Group {
            if model.hasStorageRoot {
                map(palette: palette)
            } else {
                SetupView(model: model)
            }
        }
        .environment(\.palette, palette)
    }

    private func map(palette: Palette) -> some View {
        VStack(spacing: 0) {
            GridToolbar(model: model)

            HStack(spacing: 0) {
                ChaptersSidebar(model: model)
                ZStack {
                    GridCanvasView(model: model)
                    if let error = model.loadError {
                        errorBanner(error, palette: palette)
                    }
                    if model.popoverOpen {
                        NewChapterSheet(model: model)
                    }
                }
                WeekInspector(model: model)
            }
            .frame(maxHeight: .infinity)

            statusBar(palette: palette)
        }
        .background(palette.canvas)
        .frame(minWidth: 900, minHeight: 560)
    }

    private func statusBar(palette: Palette) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack {
                Text(model.statusLeft)
                Spacer()
                Text(model.statusRight)
            }
            .font(Typography.mono(10.5))
            .foregroundColor(palette.quaternary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 25)
            .background(palette.chrome)
        }
    }

    private func errorBanner(_ message: String, palette: Palette) -> some View {
        VStack {
            Text(message)
                .font(Typography.ui(11.5))
                .foregroundColor(palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 7).fill(palette.tooltipFill))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(palette.tooltipHairline, lineWidth: 1))
                .padding(.top, 14)
            Spacer()
        }
    }
}
