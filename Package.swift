// swift-tools-version: 5.9
import Foundation
import PackageDescription

/// XCTest doesn't ship with the Command Line Tools, so the test suite is
/// written against swift-testing — but on a CLT-only machine its framework
/// sits outside the default search path. Add it so `swift test` works with no
/// Xcode install (PRD §0, §9). Skipped entirely once Xcode.app is present.
let testingFrameworkPath: String? = {
    let path = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
    let fm = FileManager.default
    guard fm.fileExists(atPath: path + "/Testing.framework"),
          !fm.fileExists(atPath: "/Applications/Xcode.app")
    else { return nil }
    return path
}()

let testSwiftSettings: [SwiftSetting] = testingFrameworkPath
    .map { [.unsafeFlags(["-F", $0])] } ?? []

// -F for linking, plus rpaths so the test bundle can find Testing.framework and
// its interop dylib at run time — neither is on dyld's default search path.
let testLinkerSettings: [LinkerSetting] = testingFrameworkPath.map { path in
    let interopLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
    return [.unsafeFlags([
        "-F", path,
        "-Xlinker", "-rpath", "-Xlinker", path,
        "-Xlinker", "-rpath", "-Xlinker", interopLibraries,
    ])]
} ?? []

let package = Package(
    name: "LifeInWeeks",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LifeInWeeksCore", targets: ["LifeInWeeksCore"]),
        .executable(name: "LifeInWeeksApp", targets: ["LifeInWeeksApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // Pure logic. No SwiftUI / AppKit imports — see PRD §6.1.
        .target(
            name: "LifeInWeeksCore",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "LifeInWeeksCoreTests",
            dependencies: ["LifeInWeeksCore"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
        // SwiftUI app. Built into a .app bundle by Scripts/build-app.sh.
        .executableTarget(
            name: "LifeInWeeksApp",
            dependencies: ["LifeInWeeksCore"]
        ),
    ]
)
