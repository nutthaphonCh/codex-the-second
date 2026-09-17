import Foundation
import Testing
@testable import CodexTheSecondCore

@Suite("Installed launcher discovery")
struct InstalledLauncherLocatorTests {
    let locator = InstalledLauncherLocator()

    /// Builds a throwaway .app that looks like one of ours.
    func makeBundle(
        at directory: URL,
        appName: String,
        slug: String,
        executable: String = "CodexTheSecond",
        withProfile: Bool = true,
        executableIsRunnable: Bool = true
    ) throws -> String {
        let bundle = directory.appendingPathComponent("\(appName).app")
        let macOS = bundle.appendingPathComponent("Contents/MacOS")
        let resources = bundle.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        let plist: [String: Any] = ["CFBundleExecutable": executable]
        try PropertyListSerialization
            .data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: bundle.appendingPathComponent("Contents/Info.plist"))

        let binary = macOS.appendingPathComponent(executable)
        try Data("#!/bin/sh\n".utf8).write(to: binary)
        try FileManager.default.setAttributes(
            [.posixPermissions: executableIsRunnable ? 0o755 : 0o644],
            ofItemAtPath: binary.path
        )

        if withProfile {
            let profile = Profile(
                name: slug.capitalized,
                slug: slug,
                appName: appName,
                bundleIdentifier: "io.github.nutthaphonch.codex-the-second." + slug,
                codexHome: "~/.codex-" + slug,
                electronUserDataPath: "~/.codex-\(slug)/electron-user-data"
            )
            try JSONEncoder().encode(profile)
                .write(to: resources.appendingPathComponent("profile.json"))
        }
        return bundle.path
    }

    func withTemporaryApplications(_ body: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-apps-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    @Test func recognisesOneOfOurBundles() throws {
        try withTemporaryApplications { directory in
            let path = try makeBundle(at: directory, appName: "Codex Personal", slug: "personal")
            let found = try #require(locator.inspect(bundlePath: path))
            #expect(found.profile.slug == "personal")
            #expect(found.appName == "Codex Personal")
            #expect(found.executablePath.hasSuffix("/Contents/MacOS/CodexTheSecond"))
        }
    }

    /// The profile is what makes a bundle ours. Without it, it is someone
    /// else's application and must be ignored.
    @Test func ignoresABundleWithNoProfile() throws {
        try withTemporaryApplications { directory in
            let path = try makeBundle(at: directory, appName: "Something Else", slug: "x", withProfile: false)
            #expect(locator.inspect(bundlePath: path) == nil)
        }
    }

    @Test func ignoresABundleWhoseExecutableIsNotRunnable() throws {
        try withTemporaryApplications { directory in
            let path = try makeBundle(
                at: directory, appName: "Codex Broken", slug: "broken", executableIsRunnable: false
            )
            #expect(locator.inspect(bundlePath: path) == nil)
        }
    }

    @Test func readsTheExecutableNameFromInfoPlist() throws {
        try withTemporaryApplications { directory in
            let path = try makeBundle(
                at: directory, appName: "Codex Renamed", slug: "renamed", executable: "SomethingElse"
            )
            let found = try #require(locator.inspect(bundlePath: path))
            #expect(found.executablePath.hasSuffix("/Contents/MacOS/SomethingElse"))
        }
    }

    @Test func searchesBothApplicationsDirectories() {
        let directories = InstalledLauncherLocator.searchDirectories(homeDirectory: "/Users/test")
        #expect(directories == ["/Applications", "/Users/test/Applications"])
    }
}
