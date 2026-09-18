import Foundation
import Testing
@testable import CodexTheSecondCore

@Suite("Profile skill")
struct ProfileSkillTests {
    let skill = ProfileSkill()

    func profile(allowAuth: Bool?) -> Profile {
        Profile(
            name: "The Second", slug: "2nd", appName: "Codex the 2nd",
            bundleIdentifier: "io.github.nutthaphonch.codex-the-second.2nd",
            codexHome: "~/.codex-the-second",
            electronUserDataPath: "~/.codex-the-second/electron-user-data",
            allowAuthFromDefaultProfile: allowAuth
        )
    }

    func plan(codexHome: String) -> LaunchPlan {
        LaunchPlan(
            executablePath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT",
            arguments: [], environment: [:], directoriesToCreate: [codexHome],
            codexHome: codexHome,
            electronUserDataPath: codexHome + "/electron-user-data"
        )
    }

    func withHome(_ body: (String) throws -> Void) throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-skill-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex-the-second"), withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home.resolvingSymlinksInPath().path)
    }

    func skillPath(_ home: String) -> String {
        home + "/.codex-the-second/skills/" + ProfileSkill.directoryName + "/SKILL.md"
    }

    @Test func installsWhereCodexLooksForSkills() throws {
        try withHome { home in
            skill.write(plan(codexHome: home + "/.codex-the-second"), profile: profile(allowAuth: true), homeDirectory: home)
            let written = try String(contentsOfFile: skillPath(home), encoding: .utf8)
            #expect(written.hasPrefix("---\nname: codex-the-second-profile\n"))
            #expect(written.contains("description:"))
        }
    }

    /// Off by default: a profile has to opt in.
    @Test func withoutTheFlagTheMainProfileIsOffLimits() throws {
        try withHome { home in
            skill.write(plan(codexHome: home + "/.codex-the-second"), profile: profile(allowAuth: nil), homeDirectory: home)
            let written = try String(contentsOfFile: skillPath(home), encoding: .utf8)
            #expect(written.contains("off limits"))
            #expect(!written.contains("Borrowing authentication"))
        }
    }

    @Test func withTheFlagItSpellsOutTheConsentRules() throws {
        try withHome { home in
            skill.write(plan(codexHome: home + "/.codex-the-second"), profile: profile(allowAuth: true), homeDirectory: home)
            let written = try String(contentsOfFile: skillPath(home), encoding: .utf8)
            #expect(written.contains("Borrowing authentication"))
            #expect(written.contains("every single time"))
            // The consequence of using account credentials must be stated.
            #expect(written.contains("as the other account"))
            // Writing to the main profile is never permitted, flag or not.
            #expect(written.contains("Never **write** anything into"))
            // And the token-handling rule survives.
            #expect(written.contains("Never **print, log or echo a token**"))
        }
    }

    @Test func neverWritesIntoTheDefaultProfile() throws {
        try withHome { home in
            try FileManager.default.createDirectory(atPath: home + "/.codex", withIntermediateDirectories: true)
            skill.write(plan(codexHome: home + "/.codex"), profile: profile(allowAuth: true), homeDirectory: home)
            #expect(!FileManager.default.fileExists(atPath: home + "/.codex/skills"))
        }
    }

    /// Once the user edits out the marker, the file is theirs.
    @Test func leavesAFileTheUserHasTakenOverAlone() throws {
        try withHome { home in
            let path = skillPath(home)
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
            )
            let mine = "---\nname: mine\ndescription: my own\n---\n\nMy rules.\n"
            try Data(mine.utf8).write(to: URL(fileURLWithPath: path))

            skill.write(plan(codexHome: home + "/.codex-the-second"), profile: profile(allowAuth: true), homeDirectory: home)
            #expect(try String(contentsOfFile: path, encoding: .utf8) == mine)
        }
    }

    @Test func rewritingIsIdempotent() throws {
        try withHome { home in
            let subject = plan(codexHome: home + "/.codex-the-second")
            skill.write(subject, profile: profile(allowAuth: true), homeDirectory: home)
            let first = try String(contentsOfFile: skillPath(home), encoding: .utf8)
            skill.write(subject, profile: profile(allowAuth: true), homeDirectory: home)
            #expect(try String(contentsOfFile: skillPath(home), encoding: .utf8) == first)
        }
    }

    /// Turning the flag off must actually withdraw the permission.
    @Test func turningTheFlagOffRewritesTheSkill() throws {
        try withHome { home in
            let subject = plan(codexHome: home + "/.codex-the-second")
            skill.write(subject, profile: profile(allowAuth: true), homeDirectory: home)
            skill.write(subject, profile: profile(allowAuth: false), homeDirectory: home)
            let written = try String(contentsOfFile: skillPath(home), encoding: .utf8)
            #expect(written.contains("off limits"))
            #expect(!written.contains("Borrowing authentication"))
        }
    }
}
