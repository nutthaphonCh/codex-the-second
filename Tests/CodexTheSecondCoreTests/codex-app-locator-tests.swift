import Foundation
import Testing
@testable import CodexTheSecondCore

/// Stands in for a set of installed application bundles.
private struct StubInspector: BundleInspecting {
    var bundles: [String: CodexApp] = [:]
    var failures: [String: String] = [:]

    func inspect(bundlePath: String) -> Result<CodexApp, BundleInspectionFailure> {
        if let app = bundles[bundlePath] { return .success(app) }
        if let reason = failures[bundlePath] { return .failure(BundleInspectionFailure(reason)) }
        return .failure(BundleInspectionFailure("No application bundle exists at this path."))
    }
}

private func app(_ path: String, identifier: String?) -> CodexApp {
    CodexApp(
        bundlePath: path,
        executablePath: path + "/Contents/MacOS/Stub",
        bundleIdentifier: identifier,
        shortVersion: "1.0"
    )
}

@Suite("Codex discovery")
struct CodexAppLocatorTests {
    let home = "/Users/test"

    let profile = Profile(
        name: "Personal",
        slug: "personal",
        appName: "Codex Personal",
        bundleIdentifier: "io.github.nutthaphonch.codex-the-second.personal",
        codexHome: "~/.codex-personal",
        electronUserDataPath: "~/.codex-personal/electron-user-data"
    )

    private func locate(
        inspector: StubInspector,
        profile overrideProfile: Profile? = nil,
        environment: [String: String] = [:],
        overrideFile: String? = nil,
        launchServices: String? = nil
    ) throws -> CodexApp {
        let locator = CodexAppLocator(
            inspector: inspector,
            readOverrideFile: { _ in overrideFile },
            launchServicesLookup: { _ in launchServices }
        )
        return try locator.locate(
            profile: overrideProfile ?? profile,
            environment: environment,
            homeDirectory: home
        )
    }

    @Test func findsCodexAppInApplications() throws {
        let inspector = StubInspector(bundles: [
            "/Applications/Codex.app": app("/Applications/Codex.app", identifier: "com.openai.codex"),
        ])
        #expect(try locate(inspector: inspector).bundlePath == "/Applications/Codex.app")
    }

    /// Codex Desktop currently ships as ChatGPT.app carrying the Codex identifier.
    @Test func fallsBackToChatGPTBundleWhenItIsCodexDesktop() throws {
        let inspector = StubInspector(bundles: [
            "/Applications/ChatGPT.app": app("/Applications/ChatGPT.app", identifier: "com.openai.codex"),
        ])
        let found = try locate(inspector: inspector)
        #expect(found.bundlePath == "/Applications/ChatGPT.app")
        #expect(found.executablePath == "/Applications/ChatGPT.app/Contents/MacOS/Stub")
    }

    /// A ChatGPT.app that is not Codex Desktop must never be launched.
    @Test func ignoresPlainChatGPTApp() {
        let inspector = StubInspector(bundles: [
            "/Applications/ChatGPT.app": app("/Applications/ChatGPT.app", identifier: "com.openai.chat"),
        ])
        let error = #expect(throws: LauncherError.self) { try locate(inspector: inspector) }
        guard case .codexNotFound = error else {
            Issue.record("expected codexNotFound, got \(String(describing: error))")
            return
        }
    }

    @Test func prefersCodexAppOverChatGPTApp() throws {
        let inspector = StubInspector(bundles: [
            "/Applications/Codex.app": app("/Applications/Codex.app", identifier: "com.openai.codex"),
            "/Applications/ChatGPT.app": app("/Applications/ChatGPT.app", identifier: "com.openai.codex"),
        ])
        #expect(try locate(inspector: inspector).bundlePath == "/Applications/Codex.app")
    }

    @Test func environmentOverrideWins() throws {
        let inspector = StubInspector(bundles: [
            "/Applications/Codex.app": app("/Applications/Codex.app", identifier: "com.openai.codex"),
            "/Users/test/Builds/Codex.app": app("/Users/test/Builds/Codex.app", identifier: "com.openai.codex"),
        ])
        let found = try locate(
            inspector: inspector,
            environment: [CodexAppLocator.overrideEnvironmentKey: "~/Builds/Codex.app"]
        )
        #expect(found.bundlePath == "/Users/test/Builds/Codex.app")
    }

    @Test func explicitOverrideFailsLoudlyInsteadOfFallingThrough() {
        let inspector = StubInspector(bundles: [
            "/Applications/Codex.app": app("/Applications/Codex.app", identifier: "com.openai.codex"),
        ])
        let error = #expect(throws: LauncherError.self) {
            try locate(
                inspector: inspector,
                environment: [CodexAppLocator.overrideEnvironmentKey: "/nope/Codex.app"]
            )
        }
        guard case let .codexPathInvalid(path, _) = error else {
            Issue.record("expected codexPathInvalid, got \(String(describing: error))")
            return
        }
        #expect(path == "/nope/Codex.app")
    }

    @Test func profilePinnedPathIsUsed() throws {
        var pinned = profile
        pinned.codexAppPath = "/Volumes/Apps/Codex.app"
        let inspector = StubInspector(bundles: [
            "/Volumes/Apps/Codex.app": app("/Volumes/Apps/Codex.app", identifier: "com.openai.codex"),
        ])
        #expect(try locate(inspector: inspector, profile: pinned).bundlePath == "/Volumes/Apps/Codex.app")
    }

    @Test func userOverrideFileIsUsed() throws {
        let inspector = StubInspector(bundles: [
            "/Volumes/Apps/Codex.app": app("/Volumes/Apps/Codex.app", identifier: "com.openai.codex"),
        ])
        #expect(try locate(inspector: inspector, overrideFile: "/Volumes/Apps/Codex.app").bundlePath
            == "/Volumes/Apps/Codex.app")
    }

    @Test func launchServicesLookupIsLastResort() throws {
        let inspector = StubInspector(bundles: [
            "/Volumes/Elsewhere/Codex.app": app("/Volumes/Elsewhere/Codex.app", identifier: "com.openai.codex"),
        ])
        #expect(try locate(inspector: inspector, launchServices: "/Volumes/Elsewhere/Codex.app").bundlePath
            == "/Volumes/Elsewhere/Codex.app")
    }

    @Test func skipsBundleWithMissingExecutable() throws {
        let inspector = StubInspector(
            bundles: [
                "/Applications/ChatGPT.app": app("/Applications/ChatGPT.app", identifier: "com.openai.codex"),
            ],
            failures: ["/Applications/Codex.app": "The bundle's executable is missing."]
        )
        #expect(try locate(inspector: inspector).bundlePath == "/Applications/ChatGPT.app")
    }

    @Test func errorListsEverywhereItLooked() {
        let error = #expect(throws: LauncherError.self) { try locate(inspector: StubInspector()) }
        guard case let .codexNotFound(searched) = error else {
            Issue.record("expected codexNotFound, got \(String(describing: error))")
            return
        }
        #expect(searched.contains("/Applications/Codex.app"))
        #expect(searched.contains("/Users/test/Applications/Codex.app"))
        #expect(error?.message.contains("Please install Codex Desktop") == true)
    }
}
