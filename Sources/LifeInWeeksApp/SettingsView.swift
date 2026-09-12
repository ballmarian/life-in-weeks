import AppKit
import LifeInWeeksCore
import SwiftUI

/// The settings window, opened by the gear in the menu bar popover.
///
/// Everything here is a fact the grid is drawn from, so all of it is the
/// archive's own state rather than app chrome: the three `config.yaml` values
/// (PRD §5.3) plus the storage-root pointer that says which archive to read
/// (PRD §4.2). Row mode and zoom stay in the toolbar, where they're live.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var birthDateText = ""
    @State private var endAge = ""
    @State private var problem: String?
    @State private var saved = false
    /// A folder picked but not yet committed. Nothing about the archive moves
    /// until Save, so this is only a display value until then.
    @State private var pendingRoot: URL?

    var body: some View {
        let palette = Palette.forScheme(colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(Typography.ui(17, .semibold))
                .foregroundColor(palette.primary)
            Text("These are the archive's own facts — the grid is drawn from them.")
                .font(Typography.ui(11.5))
                .foregroundColor(palette.tertiary)
                .padding(.top, 3)

            Hairline().padding(.vertical, 16)

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
                    Button("Reveal", action: revealFolder)
                        .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                                       foreground: palette.primary,
                                                       weight: .regular))
                        .frame(width: 66)
                }
            }
            Text("Switching folders opens that archive as it stands. "
                 + "Nothing is moved or copied out of this one.")
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

            Text("Changing either redraws the whole grid. Week files are named by "
                 + "date, so no note moves or is lost.")
                .font(Typography.ui(10.5))
                .foregroundColor(palette.tertiary)
                .padding(.top, 5)

            if let problem {
                Text(problem)
                    .font(Typography.ui(11))
                    .foregroundColor(Color(hex: "#FF6961"))
                    .padding(.top, 10)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                if saved, !isDirty, problem == nil {
                    Text("Saved")
                        .font(Typography.ui(11))
                        .foregroundColor(palette.tertiary)
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(FilledButtonStyle(fill: palette.secondaryButton,
                                                   foreground: palette.primary, weight: .regular))
                    .frame(width: 80)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(FilledButtonStyle(fill: palette.accent, foreground: .white))
                    .frame(width: 96)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!model.hasStorageRoot || !isDirty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 430)
        .background(palette.canvas)
        .environment(\.palette, palette)
        .onAppear {
            saved = false
            loadFromConfig()
        }
        // The window outlives any one archive; re-seed when the root changes.
        .onChange(of: model.config) { _ in loadFromConfig() }
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(Typography.ui(10, .semibold))
                .tracking(0.6)
                .foregroundColor(Palette.forScheme(colorScheme).tertiary)
            content()
        }
    }

    private var displayPath: String {
        guard let root = pendingRoot ?? model.archive?.paths.root else { return "No archive yet" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return root.path.hasPrefix(home) ? "~" + root.path.dropFirst(home.count) : root.path
    }

    /// Whether anything on screen differs from what's on disk. Save is the
    /// only thing that closes that gap, so it's also what enables the button.
    private var isDirty: Bool {
        if let pendingRoot, pendingRoot != model.archive?.paths.root { return true }
        guard let config = model.config else { return false }
        return name.trimmingCharacters(in: .whitespaces) != config.name
            || birthDateText.trimmingCharacters(in: .whitespaces) != config.birthDate.iso
            || endAge.trimmingCharacters(in: .whitespaces) != String(config.endAge)
    }

    private func loadFromConfig() {
        guard let config = model.config else { return }
        name = config.name
        birthDateText = config.birthDate.iso
        endAge = String(config.endAge)
        pendingRoot = nil
        problem = nil
    }

    /// Drops any unsaved edits and closes the window. The scene can hand the
    /// same view back on the next open, so the fields are re-seeded on the way
    /// out rather than trusting `onAppear` to do it again.
    private func cancel() {
        loadFromConfig()
        dismiss()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = pendingRoot ?? model.archive?.paths.root
        if panel.runModal() == .OK, let url = panel.url {
            pendingRoot = url == model.archive?.paths.root ? nil : url
            problem = nil
        }
    }

    private func revealFolder() {
        guard let root = pendingRoot ?? model.archive?.paths.root else { return }
        NSWorkspace.shared.activateFileViewerSelecting([root])
    }

    private func save() {
        guard let birthDate = CalendarDate(iso: birthDateText.trimmingCharacters(in: .whitespaces)) else {
            problem = "Birth date needs to be a real date in YYYY-MM-DD form."
            return
        }
        guard let age = Int(endAge.trimmingCharacters(in: .whitespaces)), age > 0, age <= 130 else {
            problem = "Through age needs to be a whole number between 1 and 130."
            return
        }
        problem = nil
        // Config edits land on the archive they were made against; only then
        // does the root switch, which opens the other archive as it stands and
        // re-seeds the fields from its own config.yaml.
        if let config = model.config,
           config.name != name.trimmingCharacters(in: .whitespaces)
            || config.birthDate != birthDate
            || config.endAge != age {
            model.updateConfig(name: name.trimmingCharacters(in: .whitespaces),
                               birthDate: birthDate,
                               endAge: age)
        }
        if let pendingRoot {
            self.pendingRoot = nil
            model.changeStorageRoot(to: pendingRoot)
        }
        saved = true
    }
}
