import Foundation

/// A fully resolved description of the child process to spawn.
///
/// Building this is pure: no filesystem writes, no process spawning. That keeps
/// the interesting logic — isolation of the profile — under unit test.
public struct LaunchPlan: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]
    /// The complete child environment, including inherited variables.
    public let environment: [String: String]
    /// Created (mode 0700) before the child starts, so the isolated profile
    /// exists before Electron initialises.
    public let directoriesToCreate: [String]
    public let codexHome: String
    public let electronUserDataPath: String

    /// Environment keys this launcher is responsible for. Only these are ever
    /// shown to the user or written to logs; the inherited environment is not.
    public static let managedEnvironmentKeys = ["CODEX_HOME", "CODEX_ELECTRON_USER_DATA_PATH"]

    /// A redacted view safe to print. The inherited environment may contain
    /// credentials, so it is never included.
    public var describedForDiagnostics: [String: Any] {
        [
            "executable": executablePath,
            "arguments": arguments,
            "environment": Dictionary(
                uniqueKeysWithValues: Self.managedEnvironmentKeys.compactMap { key in
                    environment[key].map { (key, $0) }
                }
            ),
            "directoriesToCreate": directoriesToCreate,
        ]
    }
}

public enum LaunchPlanBuilder {
    /// Variables belonging to this launcher, stripped so they never leak into
    /// Codex's own environment.
    static let launcherOwnedEnvironmentKeys = [
        CodexAppLocator.overrideEnvironmentKey,
        "CODEX_THE_SECOND_PROFILE_FILE",
        "CODEX_THE_SECOND_NO_ALERTS",
    ]

    public static func validate(profile: Profile, homeDirectory: String) throws {
        func requireNonEmpty(_ value: String, _ field: String) throws {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LauncherError.profileInvalid(reason: "The profile field \"\(field)\" is empty.")
            }
        }

        try requireNonEmpty(profile.name, "name")
        try requireNonEmpty(profile.slug, "slug")
        try requireNonEmpty(profile.appName, "appName")
        try requireNonEmpty(profile.bundleIdentifier, "bundleIdentifier")
        try requireNonEmpty(profile.codexHome, "codexHome")
        try requireNonEmpty(profile.electronUserDataPath, "electronUserDataPath")

        let allowedSlug = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard profile.slug.unicodeScalars.allSatisfy({ allowedSlug.contains($0) }) else {
            throw LauncherError.profileInvalid(
                reason: "The profile slug \"\(profile.slug)\" must contain only lowercase letters, digits and dashes."
            )
        }

        // The identifier must be derived from the slug, so two profiles can
        // never collide and a generated bundle's identity is predictable from
        // its configuration alone. The namespace itself is left to the owner,
        // so a fork does not have to keep ours.
        guard profile.bundleIdentifier.hasSuffix("." + profile.slug) else {
            throw LauncherError.profileInvalid(
                reason: """
                The bundle identifier \"\(profile.bundleIdentifier)\" must end \
                with \".\(profile.slug)\", so each profile has its own identity.
                """
            )
        }
        guard !profile.bundleIdentifier.lowercased().hasPrefix("com.openai") else {
            throw LauncherError.profileInvalid(
                reason: """
                The bundle identifier must not start with \"com.openai\". This \
                launcher must never claim to be Codex itself.
                """
            )
        }
        let allowedIdentifier = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard profile.bundleIdentifier.unicodeScalars.allSatisfy({ allowedIdentifier.contains($0) }),
              !profile.bundleIdentifier.hasPrefix("."),
              !profile.bundleIdentifier.hasSuffix("."),
              profile.bundleIdentifier.contains(".")
        else {
            throw LauncherError.profileInvalid(
                reason: """
                The bundle identifier \"\(profile.bundleIdentifier)\" must be a \
                reverse-DNS name in lowercase, for example \
                \"io.github.<owner>.codex-the-second.\(profile.slug)\".
                """
            )
        }

        let codexHome = PathResolver.expand(profile.codexHome, homeDirectory: homeDirectory)
        let electronData = PathResolver.expand(profile.electronUserDataPath, homeDirectory: homeDirectory)

        for (path, field) in [(codexHome, "codexHome"), (electronData, "electronUserDataPath")] {
            guard PathResolver.isAbsolute(path) else {
                throw LauncherError.profileInvalid(
                    reason: "The profile field \"\(field)\" must be an absolute path or start with \"~/\". Got: \(path)"
                )
            }
        }

        // Hard safety rail: a profile must never take over the stock Codex
        // installation's home directory.
        let defaultHome = PathResolver.expand(
            "~/" + Profile.defaultCodexHomeSuffix,
            homeDirectory: homeDirectory
        )
        if PathResolver.isSameOrInside(codexHome, parent: defaultHome) {
            throw LauncherError.profileInvalid(
                reason: """
                This profile would use the default Codex folder:

                 \(defaultHome)

                That folder belongs to your normal Codex installation and must \
                not be shared with a profile launcher. Choose a different \
                "codexHome", for example ~/.codex-\(profile.slug).
                """
            )
        }
        if PathResolver.isSameOrInside(electronData, parent: defaultHome) {
            throw LauncherError.profileInvalid(
                reason: """
                This profile would store Electron data inside the default Codex \
                folder:

                 \(defaultHome)

                Choose a different "electronUserDataPath".
                """
            )
        }
        if PathResolver.normalize(homeDirectory) == codexHome {
            throw LauncherError.profileInvalid(
                reason: "The profile field \"codexHome\" must not be your home folder itself."
            )
        }
    }

    public static func make(
        profile: Profile,
        codexApp: CodexApp,
        baseEnvironment: [String: String],
        homeDirectory: String
    ) throws -> LaunchPlan {
        try validate(profile: profile, homeDirectory: homeDirectory)

        let codexHome = PathResolver.expand(profile.codexHome, homeDirectory: homeDirectory)
        let electronData = PathResolver.expand(profile.electronUserDataPath, homeDirectory: homeDirectory)

        var environment = baseEnvironment
        for key in launcherOwnedEnvironmentKeys {
            environment.removeValue(forKey: key)
        }

        // Both variables are required, not redundant. Codex Desktop loads the
        // user's login-shell environment during startup, which would otherwise
        // overwrite CODEX_HOME; it only re-applies the launch-time value when
        // CODEX_ELECTRON_USER_DATA_PATH is also set. The same variable is what
        // makes Codex take a per-user-data-directory single-instance lock, which
        // is what allows a profile instance to coexist with normal Codex.
        environment["CODEX_HOME"] = codexHome
        environment["CODEX_ELECTRON_USER_DATA_PATH"] = electronData

        return LaunchPlan(
            executablePath: codexApp.executablePath,
            arguments: ["--user-data-dir=" + electronData],
            environment: environment,
            directoriesToCreate: [codexHome, electronData],
            codexHome: codexHome,
            electronUserDataPath: electronData
        )
    }
}
