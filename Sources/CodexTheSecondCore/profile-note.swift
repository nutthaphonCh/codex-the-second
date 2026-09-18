import Foundation

/// Leaves a note inside the isolated profile telling Codex where it is.
///
/// Codex reads `AGENTS.md` from `CODEX_HOME` as standing instructions. Without
/// this, an agent working in a profile launcher assumes the usual `~/.codex`
/// and will read, edit or reason about the wrong folder — including telling you
/// your settings are missing when they are simply somewhere else.
///
/// Only ever written inside the isolated profile, never `~/.codex`, and only
/// between the markers below: anything else already in the file is preserved
/// byte for byte.
public struct ProfileNote {
    public static let beginMarker = "<!-- codex-the-second:begin — managed, edits between these markers are overwritten -->"
    public static let endMarker = "<!-- codex-the-second:end -->"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func body(for plan: LaunchPlan, profileName: String, defaultCodexHome: String) -> String {
        """
        \(Self.beginMarker)
        ## You are running in a secondary Codex profile

        This Codex was started by **Codex the 2nd**, a launcher that points Codex
        at a profile of its own. It is a separate account and separate state from
        the Codex the user normally opens.

        | | |
        | --- | --- |
        | Profile | \(profileName) |
        | `CODEX_HOME` | `\(plan.codexHome)` |
        | Electron user data | `\(plan.electronUserDataPath)` |
        | The *other* profile, not yours | `\(defaultCodexHome)` |

        So:

        - Your settings, sessions, logs and credentials are under
          `\(plan.codexHome)` — **not** `\(defaultCodexHome)`. Read and write
          there, and say that path when you refer to "the Codex folder".
        - `\(defaultCodexHome)` belongs to the user's other account. Whether you
          may read anything there, and on what terms, is set out in the
          `codex-the-second-profile` skill in this profile. Writing there is
          never allowed.
        - Settings will look emptier here than in the other profile. That is
          expected — this profile starts fresh and is filled in as it is used.
          It is not a fault to repair by copying the other profile over.
        - Both profiles may be running at once. Assume the other one is open.
        \(Self.endMarker)
        """
    }

    /// Idempotent: rewrites the managed block, or appends one, leaving the rest
    /// of the file untouched.
    public func write(_ plan: LaunchPlan, profileName: String, homeDirectory: String) throws {
        let defaultCodexHome = PathResolver.expand(
            "~/" + Profile.defaultCodexHomeSuffix,
            homeDirectory: homeDirectory
        )

        // Refuse outright if the destination is not the isolated profile.
        guard !PathResolver.isSameOrInside(plan.codexHome, parent: defaultCodexHome) else { return }

        let path = plan.codexHome + "/AGENTS.md"
        let block = body(for: plan, profileName: profileName, defaultCodexHome: defaultCodexHome)
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let updated = Self.merge(block: block, into: existing)
        guard updated != existing else { return }

        do {
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            // A note is a convenience. Failing to write one must never stop
            // Codex from starting.
            return
        }
    }

    static func merge(block: String, into existing: String) -> String {
        guard let start = existing.range(of: beginMarker),
              let end = existing.range(of: endMarker, range: start.upperBound..<existing.endIndex)
        else {
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? block + "\n" : trimmed + "\n\n" + block + "\n"
        }
        return existing.replacingCharacters(in: start.lowerBound..<end.upperBound, with: block)
    }
}
