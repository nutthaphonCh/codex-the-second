import Foundation
import Testing
@testable import CodexTheSecondCore

@Suite("Launch plan construction")
struct LaunchPlanTests {
    let home = "/Users/test"

    let codexApp = CodexApp(
        bundlePath: "/Applications/ChatGPT.app",
        executablePath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT",
        bundleIdentifier: "com.openai.codex",
        shortVersion: "26.908.40834"
    )

    func makeProfile(
        slug: String = "personal",
        codexHome: String = "~/.codex-personal",
        electronUserDataPath: String = "~/.codex-personal/electron-user-data"
    ) -> Profile {
        Profile(
            name: "Personal",
            slug: slug,
            appName: "Codex Personal",
            bundleIdentifier: "com.local.codex-the-second.personal",
            codexHome: codexHome,
            electronUserDataPath: electronUserDataPath
        )
    }

    func makePlan(_ profile: Profile, environment: [String: String] = [:]) throws -> LaunchPlan {
        try LaunchPlanBuilder.make(
            profile: profile,
            codexApp: codexApp,
            baseEnvironment: environment,
            homeDirectory: home
        )
    }

    @Test func setsBothIsolationVariables() throws {
        let plan = try makePlan(makeProfile())
        #expect(plan.environment["CODEX_HOME"] == "/Users/test/.codex-personal")
        #expect(plan.environment["CODEX_ELECTRON_USER_DATA_PATH"] == "/Users/test/.codex-personal/electron-user-data")
    }

    @Test func passesIsolatedUserDataDirArgument() throws {
        let plan = try makePlan(makeProfile())
        #expect(plan.arguments == ["--user-data-dir=/Users/test/.codex-personal/electron-user-data"])
    }

    @Test func usesExecutableFromInspectedBundle() throws {
        let plan = try makePlan(makeProfile())
        #expect(plan.executablePath == "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT")
    }

    @Test func createsBothProfileDirectories() throws {
        let plan = try makePlan(makeProfile())
        #expect(plan.directoriesToCreate == [
            "/Users/test/.codex-personal",
            "/Users/test/.codex-personal/electron-user-data",
        ])
    }

    @Test func inheritsUnrelatedEnvironment() throws {
        let plan = try makePlan(makeProfile(), environment: ["PATH": "/usr/bin", "LANG": "en_US.UTF-8"])
        #expect(plan.environment["PATH"] == "/usr/bin")
        #expect(plan.environment["LANG"] == "en_US.UTF-8")
    }

    /// A CODEX_HOME exported in the user's shell must not win.
    @Test func overridesInheritedCodexHome() throws {
        let plan = try makePlan(makeProfile(), environment: ["CODEX_HOME": "/Users/test/.codex"])
        #expect(plan.environment["CODEX_HOME"] == "/Users/test/.codex-personal")
    }

    @Test func stripsLauncherOwnedVariables() throws {
        let plan = try makePlan(makeProfile(), environment: [
            CodexAppLocator.overrideEnvironmentKey: "/Applications/Codex.app",
            "CODEX_THE_SECOND_PROFILE_FILE": "/tmp/p.json",
        ])
        #expect(plan.environment[CodexAppLocator.overrideEnvironmentKey] == nil)
        #expect(plan.environment["CODEX_THE_SECOND_PROFILE_FILE"] == nil)
    }

    @Test func diagnosticsNeverIncludeInheritedEnvironment() throws {
        let plan = try makePlan(makeProfile(), environment: ["OPENAI_API_KEY": "sk-secret", "PATH": "/usr/bin"])
        let described = plan.describedForDiagnostics
        let environment = try #require(described["environment"] as? [String: String])
        #expect(Set(environment.keys) == Set(["CODEX_HOME", "CODEX_ELECTRON_USER_DATA_PATH"]))

        let rendered = String(describing: described)
        #expect(!rendered.contains("sk-secret"))
        #expect(!rendered.contains("OPENAI_API_KEY"))
    }

    // MARK: - Safety rails around the stock installation

    @Test func rejectsDefaultCodexHome() {
        #expect(throws: LauncherError.self) { try makePlan(makeProfile(codexHome: "~/.codex")) }
    }

    @Test func rejectsPathNestedInsideDefaultCodexHome() {
        #expect(throws: LauncherError.self) { try makePlan(makeProfile(codexHome: "~/.codex/personal")) }
    }

    @Test func rejectsElectronDataInsideDefaultCodexHome() {
        #expect(throws: LauncherError.self) {
            try makePlan(makeProfile(electronUserDataPath: "~/.codex/electron-user-data"))
        }
    }

    @Test func rejectsHomeDirectoryAsCodexHome() {
        #expect(throws: LauncherError.self) { try makePlan(makeProfile(codexHome: "~")) }
    }

    @Test func rejectsRelativeCodexHome() {
        #expect(throws: LauncherError.self) { try makePlan(makeProfile(codexHome: "relative/path")) }
    }

    @Test func rejectsInvalidSlug() {
        #expect(throws: LauncherError.self) { try makePlan(makeProfile(slug: "Personal Profile")) }
    }

    @Test func acceptsProfileOutsideDefaultHome() throws {
        _ = try makePlan(makeProfile(slug: "work", codexHome: "~/.codex-work"))
    }
}
