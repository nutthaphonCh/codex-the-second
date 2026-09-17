import Foundation

/// The last check before Codex is started: does this profile *actually* resolve
/// somewhere other than the stock installation?
///
/// `LaunchPlanBuilder.validate` already rejects the obvious cases, but it works
/// on strings alone so that it stays pure and testable. Strings are not enough
/// on a real filesystem:
///
/// - a profile directory can be a **symbolic link** back to `~/.codex`
/// - macOS volumes are **case-insensitive by default**, so `~/.CODEX` and
///   `~/.codex` are one directory with two spellings
///
/// Either would pass a textual comparison and then hand the secondary launcher
/// the user's primary profile. This guard consults the filesystem and fails
/// closed: when it cannot prove the paths are distinct, it refuses to launch.
public struct IsolationGuard {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func assertIsolated(_ plan: LaunchPlan, homeDirectory: String) throws {
        let defaultHome = PathResolver.expand(
            "~/" + Profile.defaultCodexHomeSuffix,
            homeDirectory: homeDirectory
        )
        let canonicalDefault = canonicalize(defaultHome)

        for path in [plan.codexHome, plan.electronUserDataPath] {
            let canonical = canonicalize(path)

            // Same directory reached by a different spelling, or nested inside it.
            if isSameOrInsideIgnoringCase(canonical, parent: canonicalDefault) {
                throw LauncherError.profileResolvesToDefault(
                    configured: path,
                    resolved: canonical,
                    defaultHome: canonicalDefault,
                    reason: canonical.caseInsensitiveCompare(path) == .orderedSame
                        ? "It is the same folder as your main Codex profile."
                        : "It leads to your main Codex profile, through a link or an alternative spelling."
                )
            }

            // Belt: hard links, firmlinks and anything else that reaches the same
            // directory without matching by path.
            if let a = identity(of: canonical), let b = identity(of: canonicalDefault), a == b {
                throw LauncherError.profileResolvesToDefault(
                    configured: path,
                    resolved: canonical,
                    defaultHome: canonicalDefault,
                    reason: "It is the same folder on disk as your main Codex profile."
                )
            }
        }
    }

    /// Resolves the deepest ancestor that exists — which also settles symlinks
    /// and the volume's letter casing — then re-appends the components that do
    /// not exist yet.
    ///
    /// Resolving the whole path in one step is not enough: Foundation leaves a
    /// path untouched when its tail does not exist, so a symlinked profile
    /// directory with a not-yet-created `electron-user-data` inside it would
    /// come back unresolved.
    public func canonicalize(_ path: String) -> String {
        guard PathResolver.isAbsolute(path) else { return PathResolver.normalize(path) }

        var missing: [String] = []
        var current = URL(fileURLWithPath: PathResolver.normalize(path)).standardizedFileURL

        while !fileManager.fileExists(atPath: current.path), current.path != "/" {
            missing.append(current.lastPathComponent)
            current = current.deletingLastPathComponent()
        }

        var resolved = current.resolvingSymlinksInPath()
        for component in missing.reversed() {
            resolved.appendPathComponent(component)
        }
        return PathResolver.normalize(resolved.path)
    }

    /// Case-insensitive because that is how macOS volumes are formatted by
    /// default. On a case-sensitive volume this is stricter than necessary,
    /// which is the safe direction: it can only refuse a profile, never share
    /// one by mistake.
    func isSameOrInsideIgnoringCase(_ child: String, parent: String) -> Bool {
        if child.caseInsensitiveCompare(parent) == .orderedSame { return true }
        return child.lowercased().hasPrefix(parent.lowercased() + "/")
    }

    /// Volume and inode, so two names for one directory compare equal.
    func identity(of path: String) -> String? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return "\(info.st_dev):\(info.st_ino)"
    }
}
