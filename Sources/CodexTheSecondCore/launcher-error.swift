import Foundation

/// Every failure the launcher can surface. Each case carries an alert title and
/// a body written for someone who will never open Terminal.
public enum LauncherError: Error, Equatable {
    case profileMissing
    case profileUnreadable(path: String, underlying: String)
    case profileMalformed(path: String, underlying: String)
    case profileInvalid(reason: String)
    case profileResolvesToDefault(configured: String, resolved: String, defaultHome: String, reason: String)
    case codexNotFound(searched: [String])
    case codexPathInvalid(path: String, reason: String)
    case directoryCreationFailed(path: String, underlying: String)
    case migrationFailed(from: String, to: String, underlying: String)
    case launchFailed(executable: String, underlying: String)
    case codexExitedImmediately(executable: String, status: Int32)

    public var title: String {
        switch self {
        case .profileMissing, .profileUnreadable, .profileMalformed, .profileInvalid:
            return "This launcher is not configured correctly."
        case .profileResolvesToDefault:
            return "This profile would share your main Codex account."
        case .codexNotFound, .codexPathInvalid:
            return "Codex could not be found."
        case .directoryCreationFailed:
            return "The profile folder could not be created."
        case .migrationFailed:
            return "The profile folder could not be moved."
        case .launchFailed, .codexExitedImmediately:
            return "Codex could not be started."
        }
    }

    public var message: String {
        switch self {
        case .profileMissing:
            return """
            No profile configuration was found inside this application bundle.

            Expected:
             Contents/Resources/profile.json

            Rebuild the launcher from source, or reinstall it from the release \
            DMG.
            """
        case let .profileUnreadable(path, underlying):
            return """
            The profile configuration could not be read.

            Path:
             \(path)

            Details: \(underlying)
            """
        case let .profileMalformed(path, underlying):
            return """
            The profile configuration is not valid JSON, or is missing required \
            fields.

            Path:
             \(path)

            Details: \(underlying)
            """
        case let .profileInvalid(reason):
            return """
            The profile configuration was rejected.

            \(reason)
            """
        case let .profileResolvesToDefault(configured, resolved, defaultHome, reason):
            return """
            This profile was set up to use its own folder, but on disk that \
            folder leads to the one your normal Codex uses.

            Profile folder:
             \(configured)

            Which actually leads to:
             \(resolved)

            Your normal Codex uses:
             \(defaultHome)

            \(reason)

            Nothing was started and nothing was changed. Point this profile at \
            a different folder before trying again.
            """
        case let .codexNotFound(searched):
            let list = searched.map { " \($0)" }.joined(separator: "\n")
            return """
            Codex could not be found.

            Searched:
            \(list)

            Please install Codex Desktop, or pin its location by creating a file \
            containing the full path to the Codex application bundle at:

             ~/Library/Application Support/CodexTheSecond/codex-app-path
            """
        case let .codexPathInvalid(path, reason):
            return """
            The configured Codex location is not usable.

            Path:
             \(path)

            \(reason)
            """
        case let .directoryCreationFailed(path, underlying):
            return """
            The isolated profile folder could not be created.

            Path:
             \(path)

            Details: \(underlying)

            Check that the disk is not full and that you have permission to \
            write to your home folder.
            """
        case let .migrationFailed(from, to, underlying):
            return """
            Your existing profile could not be moved to its new location.

            From:
             \(from)

            To:
             \(to)

            Details: \(underlying)

            Nothing was deleted. The profile is still where it was, and you can \
            try again.
            """
        case let .launchFailed(executable, underlying):
            return """
            Codex was found but could not be started.

            Executable:
             \(executable)

            Details: \(underlying)
            """
        case let .codexExitedImmediately(executable, status):
            return """
            Codex started and then stopped immediately (exit code \(status)).

            Executable:
             \(executable)

            This usually means the installed Codex version changed how it \
            accepts launch options. Check for an update to this launcher.
            """
        }
    }
}
