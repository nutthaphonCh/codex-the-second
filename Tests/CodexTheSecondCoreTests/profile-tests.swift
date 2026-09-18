import Foundation
import Testing
@testable import CodexTheSecondCore

@Suite("Shipped profiles")
struct ProfileTests {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The files in `profiles/` are what `scripts/build.sh` bakes into generated
    /// bundles, so they must stay loadable and valid.
    @Test func shippedProfilesAreValid() throws {
        let profilesDirectory = Self.repositoryRoot.appendingPathComponent("profiles")
        let entries = try FileManager.default.contentsOfDirectory(atPath: profilesDirectory.path)
        let profileFiles = entries.filter { $0.hasSuffix(".json") || $0.hasSuffix(".json.example") }
        #expect(!profileFiles.isEmpty, "expected at least one profile in profiles/")

        for file in profileFiles {
            let profile = try Profile.load(contentsOf: profilesDirectory.appendingPathComponent(file))
            try LaunchPlanBuilder.validate(profile: profile, homeDirectory: "/Users/test")
            #expect(
                !profile.bundleIdentifier.hasPrefix("com.openai"),
                "profile \(file) must not impersonate Codex's own bundle identifier"
            )
        }
    }

    @Test func defaultProfileMatchesDocumentedPaths() throws {
        let profile = try Profile.load(
            contentsOf: Self.repositoryRoot.appendingPathComponent("profiles/2nd.json")
        )
        #expect(profile.appName == "Codex the 2nd")
        #expect(profile.codexHome == "~/.codex-the-second")
        #expect(profile.electronUserDataPath == "~/.codex-the-second/electron-user-data")
        // Anyone upgrading from an earlier release still has the old folder.
        #expect(profile.migrateFrom == "~/.codex-personal")
        // An unusual permission must be visible in configuration, not implied.
        #expect(profile.allowAuthFromDefaultProfile == true)
    }

    @Test func roundTripsThroughJSON() throws {
        let profile = Profile(
            name: "Alt",
            slug: "alt",
            appName: "Codex Alt",
            bundleIdentifier: "io.github.nutthaphonch.codex-the-second.alt",
            codexHome: "~/.codex-alt",
            electronUserDataPath: "~/.codex-alt/electron-user-data",
            icon: IconSpec(label: "CA", tintTop: "#111111", tintBottom: "#222222")
        )
        let data = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: data) == profile)
    }
}
