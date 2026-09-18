import Foundation
import Testing
@testable import CodexTheSecondCore

@Suite("Profile migration")
struct ProfileMigrationTests {
    let migration = ProfileMigration()

    func profile(codexHome: String = "~/.codex-the-second", migrateFrom: String? = "~/.codex-personal") -> Profile {
        Profile(
            name: "The Second", slug: "2nd", appName: "Codex the 2nd",
            bundleIdentifier: "io.github.nutthaphonch.codex-the-second.2nd",
            codexHome: codexHome,
            electronUserDataPath: codexHome + "/electron-user-data",
            migrateFrom: migrateFrom
        )
    }

    func withHome(_ body: (String) throws -> Void) throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-mig-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home.resolvingSymlinksInPath().path)
    }

    func makeProfileFolder(_ path: String, marker: String = "old") throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: URL(fileURLWithPath: path + "/auth.json"))
    }

    @Test func offersToMoveAnOldProfile() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex-personal")
            guard case let .available(from, to, _) = migration.inspect(profile: profile(), homeDirectory: home) else {
                Issue.record("expected a migration to be offered"); return
            }
            #expect(from == home + "/.codex-personal")
            #expect(to == home + "/.codex-the-second")
        }
    }

    @Test func movingKeepsTheContents() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex-personal", marker: "signed-in")
            try migration.perform(from: home + "/.codex-personal", to: home + "/.codex-the-second")

            let moved = try String(contentsOfFile: home + "/.codex-the-second/auth.json", encoding: .utf8)
            #expect(moved == "signed-in")
            #expect(!FileManager.default.fileExists(atPath: home + "/.codex-personal"))
            #expect(migration.inspect(profile: profile(), homeDirectory: home) == .nothingToDo)
        }
    }

    @Test func doesNothingWhenThereIsNoOldProfile() throws {
        try withHome { home in
            #expect(migration.inspect(profile: profile(), homeDirectory: home) == .nothingToDo)
        }
    }

    @Test func doesNothingWhenTheProfileDeclaresNoOldFolder() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex-personal")
            #expect(migration.inspect(profile: profile(migrateFrom: nil), homeDirectory: home) == .nothingToDo)
        }
    }

    /// Two real profiles must never be merged; the user has to decide.
    @Test func refusesWhenBothFoldersHoldData() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex-personal")
            try makeProfileFolder(home + "/.codex-the-second", marker: "new")
            guard case .blocked = migration.inspect(profile: profile(), homeDirectory: home) else {
                Issue.record("expected the migration to be blocked"); return
            }
        }
    }

    /// An empty folder is what a previous launch left behind, not data.
    @Test func movesOverAnEmptyDestination() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex-personal", marker: "signed-in")
            try FileManager.default.createDirectory(
                atPath: home + "/.codex-the-second", withIntermediateDirectories: true
            )
            guard case let .available(from, to, _) = migration.inspect(profile: profile(), homeDirectory: home) else {
                Issue.record("expected a migration to be offered"); return
            }
            try migration.perform(from: from, to: to)
            let moved = try String(contentsOfFile: home + "/.codex-the-second/auth.json", encoding: .utf8)
            #expect(moved == "signed-in")
        }
    }

    /// The stock installation is never a migration source, whatever a profile says.
    @Test func refusesToMoveTheDefaultCodexFolder() throws {
        try withHome { home in
            try makeProfileFolder(home + "/.codex")
            guard case .blocked = migration.inspect(
                profile: profile(migrateFrom: "~/.codex"), homeDirectory: home
            ) else {
                Issue.record("expected moving ~/.codex to be blocked"); return
            }
        }
    }
}

@Suite("Profile note")
struct ProfileNoteTests {
    let note = ProfileNote()

    func plan(codexHome: String) -> LaunchPlan {
        LaunchPlan(
            executablePath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT",
            arguments: [],
            environment: [:],
            directoriesToCreate: [codexHome],
            codexHome: codexHome,
            electronUserDataPath: codexHome + "/electron-user-data"
        )
    }

    func withHome(_ body: (String) throws -> Void) throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-note-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex-the-second"), withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home.resolvingSymlinksInPath().path)
    }

    @Test func statesTheProfileHomeAndWarnsOffTheOther() throws {
        try withHome { home in
            try note.write(plan(codexHome: home + "/.codex-the-second"), profileName: "The Second", homeDirectory: home)
            let written = try String(contentsOfFile: home + "/.codex-the-second/AGENTS.md", encoding: .utf8)
            #expect(written.contains(home + "/.codex-the-second"))
            #expect(written.contains(home + "/.codex"))
            #expect(written.contains("secondary Codex profile"))
        }
    }

    @Test func keepsWhatTheUserAlreadyWrote() throws {
        try withHome { home in
            let path = home + "/.codex-the-second/AGENTS.md"
            try Data("# My own instructions\n\nAlways use tabs.\n".utf8).write(to: URL(fileURLWithPath: path))
            try note.write(plan(codexHome: home + "/.codex-the-second"), profileName: "The Second", homeDirectory: home)

            let written = try String(contentsOfFile: path, encoding: .utf8)
            #expect(written.contains("Always use tabs."))
            #expect(written.contains(ProfileNote.beginMarker))
        }
    }

    @Test func rewritingReplacesTheBlockRatherThanStacking() throws {
        try withHome { home in
            let subject = plan(codexHome: home + "/.codex-the-second")
            try note.write(subject, profileName: "The Second", homeDirectory: home)
            try note.write(subject, profileName: "The Second", homeDirectory: home)

            let written = try String(contentsOfFile: home + "/.codex-the-second/AGENTS.md", encoding: .utf8)
            let occurrences = written.components(separatedBy: ProfileNote.beginMarker).count - 1
            #expect(occurrences == 1)
        }
    }

    /// The stock profile must never receive this note.
    @Test func refusesToWriteIntoTheDefaultProfile() throws {
        try withHome { home in
            try FileManager.default.createDirectory(
                atPath: home + "/.codex", withIntermediateDirectories: true
            )
            try note.write(plan(codexHome: home + "/.codex"), profileName: "Default", homeDirectory: home)
            #expect(!FileManager.default.fileExists(atPath: home + "/.codex/AGENTS.md"))
        }
    }
}

@Suite("Migration refuses to move a profile in use")
struct ProfileMigrationInUseTests {
    @Test func blocksWhileCodexIsStillRunningFromTheFolder() throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cts-inuse-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex-personal"), withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: home) }
        let homePath = home.resolvingSymlinksInPath().path

        let migration = ProfileMigration(isInUse: { _ in true })
        let profile = Profile(
            name: "The Second", slug: "2nd", appName: "Codex the 2nd",
            bundleIdentifier: "io.github.nutthaphonch.codex-the-second.2nd",
            codexHome: "~/.codex-the-second",
            electronUserDataPath: "~/.codex-the-second/electron-user-data",
            migrateFrom: "~/.codex-personal"
        )
        guard case let .blocked(_, _, reason) = migration.inspect(profile: profile, homeDirectory: homePath) else {
            Issue.record("expected the migration to be blocked while in use"); return
        }
        #expect(reason.contains("still running"))
    }
}
