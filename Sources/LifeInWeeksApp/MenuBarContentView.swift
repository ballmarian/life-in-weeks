import LifeInWeeksCore
import SwiftUI

/// The menu bar extra's three actions (PRD §6.4). All of them work with the
/// main window closed — the model is loaded by the app, not by the window.
struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    let openMap: () -> Void
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var quickNote = ""
    @FocusState private var quickNoteFocused: Bool

    var body: some View {
        let palette = Palette.forScheme(colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
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
                }
                Spacer(minLength: 0)
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(IconButtonStyle())
                .help("Settings")
                .accessibilityLabel("Settings")
                .keyboardShortcut(",", modifiers: .command)
                .padding(.top, -2)
            }

            Hairline()

            // Quick note: a few lines, appended to this week's file with a
            // timestamp, creating it if needed. Return breaks a line, so
            // Cmd+Return is what sends it.
            VStack(spacing: 8) {
                TextEditor(text: $quickNote)
                    .focused($quickNoteFocused)
                    .font(Typography.ui(12.5))
                    .lineSpacing(12.5 * 0.55)
                    .foregroundColor(palette.primary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(height: 5 * 12.5 * 1.55 + 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(palette.fieldFill))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.fieldHairline, lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if quickNote.isEmpty {
                            Text("Quick note…")
                                .font(Typography.ui(12.5))
                                .foregroundColor(palette.placeholder)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                    }
                Button("Add", action: submitQuickNote)
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white))
                    .keyboardShortcut(.return, modifiers: .command)
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
