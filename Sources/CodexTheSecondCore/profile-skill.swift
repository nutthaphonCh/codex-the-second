import Foundation

/// Installs a Codex skill into the isolated profile.
///
/// Codex reads `<CODEX_HOME>/skills/<name>/SKILL.md` and offers the skill when
/// its description matches what the user is doing. This is how a profile tells
/// an agent something it could not otherwise know — here, that the other
/// profile exists and under what terms it may be touched.
///
/// The file is written only while this launcher still owns it. If the user
/// edits it and removes the ownership marker, it is left alone for good.
public struct ProfileSkill {
    public static let directoryName = "codex-the-second-profile"
    public static let ownershipMarker = "<!-- written by Codex the 2nd; delete this line to take ownership -->"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func contents(
        profileName: String,
        codexHome: String,
        defaultCodexHome: String,
        allowAuthFromDefaultProfile: Bool
    ) -> String {
        let sharedHeader = """
        ---
        name: codex-the-second-profile
        description: How this secondary Codex profile relates to the user's main profile. Use when sign-in, credentials, connectors, plugins, MCP servers or settings look missing, broken or unexpectedly empty, or when anything refers to the Codex folder.
        ---

        \(Self.ownershipMarker)

        # This is a secondary Codex profile

        You are in **\(profileName)**, started by Codex the 2nd. It is a separate
        Codex account with its own folder.

        | | |
        | --- | --- |
        | Your folder (`CODEX_HOME`) | `\(codexHome)` |
        | The user's main profile | `\(defaultCodexHome)` |

        Read and write your own folder freely. When you say "the Codex folder",
        mean `\(codexHome)`.

        ## Things here will look emptier than you expect

        Trusted folders, connectors, plugins, MCP servers and preferences are
        per-profile. A fresh profile genuinely has fewer of them. **That is not a
        fault to repair**, and it is never a reason to copy the main profile over
        this one on your own initiative.

        """

        guard allowAuthFromDefaultProfile else {
            return sharedHeader + "\n" + """
            ## The main profile is off limits

            Do not read from, write to, or copy anything out of
            `\(defaultCodexHome)`. It belongs to the user's other account.

            If the user needs something that lives there, say so and let them
            decide. Do not fetch it yourself.
            """
        }

        return sharedHeader + "\n" + """
        ## Borrowing authentication from the main profile

        The user has allowed you to use authentication from
        `\(defaultCodexHome)` — **but only after asking, every single time.**

        This permission is switched on in this profile's configuration
        (`allowAuthFromDefaultProfile`). It is not a standing instruction from
        the user in this conversation, and it is not permission to browse the
        other profile.

        ### Ask first, every time

        Before reading anything under `\(defaultCodexHome)`, ask in plain words
        and wait for a clear yes. Name three things:

        1. **The exact path** you want to read.
        2. **Why** — what is broken that this fixes.
        3. **What you will do with it** — read it in place, or copy what into
           where.

        One yes covers one access. A yes earlier in the conversation is not a yes
        now. If the user is not there to answer, stop and leave a note; never
        assume consent from silence.

        ### Say this when it is account credentials

        `\(defaultCodexHome)/auth.json` is the **account sign-in** for the other
        profile. Using it does not merely unblock a feature — it makes this
        instance act **as the other account**. Requests, usage and history go
        there instead.

        If you are about to touch it, say that consequence out loud before you
        ask, and prefer signing this profile in on its own.

        ### Prefer the repair that leaves nothing borrowed

        Borrowing is the fallback, not the first move. Try these first:

        - **Sign in to this profile directly.**
        - **Connector or plugin sign-in bouncing to the wrong window?** macOS
          delivers `codex://` callbacks by bundle identifier, and both instances
          share one, so the callback can land in the main window. Quit the main
          Codex, leave this one running, and authenticate again — the callback
          then has nowhere else to go. Do not quit the main app yourself; ask.
        - **Only settings missing?** Re-entering a setting is cheaper and safer
          than copying credentials.

        ### Never

        - Never **write** anything into `\(defaultCodexHome)`. It is read-only to
          you, always, consent or not.
        - Never **print, log or echo a token**, not even partially, not even to
          confirm you found it.
        - Never copy a whole file or folder when one value would do.
        - Never borrow to save the user a question. The question is the point.
        """
    }

    /// Writes the skill. Never touches the default profile, never overwrites a
    /// file the user has taken ownership of, and never blocks a launch on
    /// failure — a skill is a convenience.
    public func write(
        _ plan: LaunchPlan,
        profile: Profile,
        homeDirectory: String
    ) {
        let defaultCodexHome = PathResolver.expand(
            "~/" + Profile.defaultCodexHomeSuffix,
            homeDirectory: homeDirectory
        )
        guard !PathResolver.isSameOrInside(plan.codexHome, parent: defaultCodexHome) else { return }

        let directory = plan.codexHome + "/skills/" + Self.directoryName
        let path = directory + "/SKILL.md"

        if let existing = try? String(contentsOfFile: path, encoding: .utf8),
           !existing.contains(Self.ownershipMarker) {
            return
        }

        let body = contents(
            profileName: profile.name,
            codexHome: plan.codexHome,
            defaultCodexHome: defaultCodexHome,
            allowAuthFromDefaultProfile: profile.allowAuthFromDefaultProfile ?? false
        )
        if let existing = try? String(contentsOfFile: path, encoding: .utf8), existing == body {
            return
        }

        try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
