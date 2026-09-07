import LifeInWeeksCore
import SwiftUI

/// The menu bar extra's three actions (PRD §6.4). All of them work with the
/// main window closed — the model is loaded by the app, not by the window.
struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    let openMap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var quickNote = ""
    @FocusState private var quickNoteFocused: Bool

    var body: some View {
        let palette = Palette.forScheme(colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            if let timeline = model.timeline {
                Text(timeline.monday(of: model.currentWeek).mediumDisplay)
                    .font(Typography.ui(13, .semibold))
                    .foregroundColor(palette.primary)
                Text("This week · age \(timeline.age(atWeek: model.currentWeek)) · "
                     + timeline.monday(of: model.currentWeek).isoWeekLabel)
                    .font(Typography.mono(10.5))
                    .foregroundColor(palette.quaternary)
            } else {
                Text("Life in Weeks")
                    .font(Typography.ui(13, .semibold))
                    .foregroundColor(palette.primary)
                Text("No archive set up yet.")
                    .font(Typography.ui(11))
                    .foregroundColor(palette.tertiary)
            }

            Hairline()

            // Quick note: one line, appended to this week's file with a
            // timestamp, creating it if needed.
            HStack(spacing: 8) {
                StyledField(placeholder: "Quick note…", text: $quickNote)
                    .focused($quickNoteFocused)
                    .onSubmit(submitQuickNote)
                Button("Add", action: submitQuickNote)
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white))
                    .frame(width: 52)
                    .disabled(!model.hasStorageRoot)
            }

            Button("Edit this week") {
                model.selectCurrentWeek()
                model.beginEditing()
                openMap()
            }
            .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                           foreground: palette.primary, weight: .regular))
            .disabled(!model.hasStorageRoot)

            Button("View Life in Weeks", action: openMap)
                .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                               foreground: palette.primary, weight: .regular))

            Hairline()

            Button("Quit Life in Weeks") { NSApplication.shared.terminate(nil) }
                .buttonStyle(FilledButtonStyle(fill: .clear, foreground: palette.tertiary,
                                               height: 20, weight: .regular))
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 268)
        .background(palette.sidebar)
        .environment(\.palette, palette)
    }

    private func submitQuickNote() {
        model.appendQuickNote(quickNote)
        quickNote = ""
    }
}
