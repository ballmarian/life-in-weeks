import AppKit
import SwiftUI

/// A menu bar utility that also owns a full window: one process, two scenes
/// (PRD §6.4). `LSUIElement` keeps it out of the Dock — see Scripts/build-app.sh,
/// which writes the Info.plist.
@main
struct LifeInWeeksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    static let mapWindowID = "life-in-weeks-map"

    var body: some Scene {
        Window("Life in Weeks", id: LifeInWeeksApp.mapWindowID) {
            MainWindowView(model: model)
        }
        .defaultSize(width: 1400, height: 813)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Go to This Week") { model.selectCurrentWeek() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContentView(model: model, openMap: openMap)
        } label: {
            // A template SF Symbol, so it tracks the menu bar's appearance.
            Image(systemName: "square.grid.3x3.fill")
        }
        .menuBarExtraStyle(.window)
    }

    private func openMap() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: LifeInWeeksApp.mapWindowID)
    }
}


/// With `LSUIElement` the app launches unactivated, which is right for a menu
/// bar utility — except on the very first run, when nothing has been set up yet
/// and the window would otherwise open behind whatever the user was doing.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Preferences.storageRoot == nil else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
