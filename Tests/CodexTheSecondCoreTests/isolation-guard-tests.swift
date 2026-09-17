import Foundation
import Testing
@testable import CodexTheSecondCore

/// These run against a real temporary directory: the whole point of the guard
/// is the filesystem, so stubbing it out would test nothing.
@Suite("Isolation guard")
struct IsolationGuardTests {
    let guardUnderTest = IsolationGuard()

    /// A sandbox shaped like a home directory, with a `.codex` inside it.
    func withTemporaryHome(_ body: (String) throws -> Void) throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-guard-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex"),
            withIntermediateDirectories: true
        )
        // Resolved, because macOS maps /var and /tmp through symlinks.
        try body(URL(fileURLWithPath: home.path).resolvingSymlinksInPath().path)
    }

    func plan(codexHome: String, electron: String? = nil) -> LaunchPlan {
        let electronPath = electron ?? codexHome + "/electron-user-data"
        return LaunchPlan(
            executablePath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT",
            arguments: ["--user-data-dir=" + electronPath],
            environment: [:],
            directoriesToCreate: [codexHome, electronPath],
            codexHome: codexHome,
            electronUserDataPath: electronPath
        )
    }

    @Test func acceptsAGenuinelySeparateDirectory() throws {
        try withTemporaryHome { home in
            let subject = plan(codexHome: home + "/.codex-personal")
            try guardUnderTest.assertIsolated(subject, homeDirectory: home)
        }
    }

    @Test func acceptsADirectoryThatDoesNotExistYet() throws {
        // First launch: nothing has been created, and that must still pass.
        try withTemporaryHome { home in
            let subject = plan(codexHome: home + "/.codex-brand-new/nested")
            try guardUnderTest.assertIsolated(subject, homeDirectory: home)
        }
    }

    @Test func rejectsASymlinkPointingAtTheDefaultProfile() throws {
        try withTemporaryHome { home in
            let link = home + "/.codex-personal"
            try FileManager.default.createSymbolicLink(
                atPath: link,
                withDestinationPath: home + "/.codex"
            )
            #expect(throws: LauncherError.self) {
                try guardUnderTest.assertIsolated(plan(codexHome: link), homeDirectory: home)
            }
        }
    }

    /// Foundation leaves a path alone when its tail does not exist, so the
    /// Electron directory inside a symlinked profile is the case that a
    /// single resolvingSymlinksInPath call would miss.
    @Test func rejectsAnElectronPathInsideASymlinkedProfile() throws {
        try withTemporaryHome { home in
            let link = home + "/.codex-personal"
            try FileManager.default.createSymbolicLink(
                atPath: link,
                withDestinationPath: home + "/.codex"
            )
            #expect(throws: LauncherError.self) {
                try guardUnderTest.assertIsolated(
                    plan(codexHome: home + "/.codex-elsewhere", electron: link + "/electron-user-data"),
                    homeDirectory: home
                )
            }
        }
    }

    @Test func rejectsADifferentSpellingOfTheDefaultProfile() throws {
        try withTemporaryHome { home in
            #expect(throws: LauncherError.self) {
                try guardUnderTest.assertIsolated(plan(codexHome: home + "/.CODEX"), homeDirectory: home)
            }
        }
    }

    @Test func rejectsANestedDirectoryReachedThroughASymlink() throws {
        try withTemporaryHome { home in
            let link = home + "/.codex-link"
            try FileManager.default.createSymbolicLink(
                atPath: link,
                withDestinationPath: home + "/.codex"
            )
            #expect(throws: LauncherError.self) {
                try guardUnderTest.assertIsolated(
                    plan(codexHome: link + "/sessions"),
                    homeDirectory: home
                )
            }
        }
    }

    @Test func canonicalizeResolvesALinkWithAMissingTail() throws {
        try withTemporaryHome { home in
            let link = home + "/.codex-personal"
            try FileManager.default.createSymbolicLink(
                atPath: link,
                withDestinationPath: home + "/.codex"
            )
            let resolved = guardUnderTest.canonicalize(link + "/not/created/yet")
            #expect(resolved == home + "/.codex/not/created/yet")
        }
    }

    @Test func identityMatchesForTwoNamesOfOneDirectory() throws {
        try withTemporaryHome { home in
            let link = home + "/.codex-link"
            try FileManager.default.createSymbolicLink(
                atPath: link,
                withDestinationPath: home + "/.codex"
            )
            let viaLink = try #require(guardUnderTest.identity(of: link))
            let direct = try #require(guardUnderTest.identity(of: home + "/.codex"))
            #expect(viaLink == direct)
        }
    }
}
