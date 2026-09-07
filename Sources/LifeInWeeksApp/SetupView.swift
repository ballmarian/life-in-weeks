import AppKit
import LifeInWeeksCore
import SwiftUI

/// First launch: pick where the archive lives, and record the two facts the
/// grid can't be drawn without.
///
/// Neither the PRD nor the design handoff specifies this screen, but PRD §5.3
/// needs a storage-root preference and a `config.yaml` before anything can
/// render, and the repo README is meant to explain "how to point it at a
/// storage folder on first launch" (PRD §12).
struct SetupView: View {
    @ObservedObject var model: AppModel
    @Environment(\.palette) private var palette

    @State private var root: URL = Preferences.suggestedStorageRoot
    @State private var name = NSFullUserName()
    @State private var birthDateText = ""
    @State private var endAge = String(LifeConfig.defaultEndAge)
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Life in Weeks")
                .font(Typography.ui(19, .semibold))
                .foregroundColor(palette.primary)
            Text("Your whole life as a grid of weeks, stored as plain files you own.")
                .font(Typography.ui(12))
                .foregroundColor(palette.tertiary)
                .padding(.top, 4)

            Hairline().padding(.vertical, 18)

            field("Storage folder") {
                HStack(spacing: 8) {
                    Text(displayPath)
                        .font(Typography.mono(11))
                        .foregroundColor(palette.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(palette.fieldFill))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(palette.fieldHairline, lineWidth: 1))
                    Button("Choose…", action: chooseFolder)
                        .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                                       foreground: palette.primary,
                                                       weight: .regular))
                        .frame(width: 84)
                }
            }
            Text("A folder of its own, or one inside an Obsidian vault. "
                 + "config.yaml, blocks.yaml and weeks/ are created here.")
                .font(Typography.ui(10.5))
                .foregroundColor(palette.tertiary)
                .padding(.top, 5)

            field("Name") { StyledField(placeholder: "Your name", text: $name) }
                .padding(.top, 16)

            HStack(alignment: .bottom, spacing: 12) {
                field("Birth date") {
                    StyledField(placeholder: "YYYY-MM-DD", text: $birthDateText,
                                font: Typography.mono(12))
                }
                field("Through age") {
                    StyledField(placeholder: "90", text: $endAge, font: Typography.mono(12))
                        .frame(width: 74)
                }
                .fixedSize()
            }
            .padding(.top, 16)

            if let problem {
                Text(problem)
                    .font(Typography.ui(11))
                    .foregroundColor(Color(hex: "#FF6961"))
                    .padding(.top, 10)
            }

            Spacer(minLength: 20)

            HStack {
                Spacer()
                Button("Create archive", action: create)
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white))
                    .frame(width: 140)
            }
        }
        .padding(28)
        .frame(width: 520, height: 420)
        .background(palette.canvas)
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(Typography.ui(10, .semibold))
                .tracking(0.6)
                .foregroundColor(palette.tertiary)
            content()
        }
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = root.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = root.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            root = url
        }
    }

    private func create() {
        guard let birthDate = CalendarDate(iso: birthDateText.trimmingCharacters(in: .whitespaces)) else {
            problem = "Birth date needs to be a real date in YYYY-MM-DD form."
            return
        }
        guard let age = Int(endAge.trimmingCharacters(in: .whitespaces)), age > 0, age <= 130 else {
            problem = "Through age needs to be a whole number between 1 and 130."
            return
        }
        problem = nil
        model.adopt(root: root, seeding: LifeConfig(
            name: name.trimmingCharacters(in: .whitespaces),
            birthDate: birthDate,
            endAge: age
        ))
    }
}
