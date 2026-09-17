import Foundation

/// Tilde expansion and normalisation that does not depend on process state, so
/// it can be unit tested against a synthetic home directory.
public enum PathResolver {
    public static func expand(_ path: String, homeDirectory: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = normalize(homeDirectory)

        let expanded: String
        if trimmed == "~" {
            expanded = home
        } else if trimmed.hasPrefix("~/") {
            expanded = home + "/" + String(trimmed.dropFirst(2))
        } else {
            expanded = trimmed
        }
        return normalize(expanded)
    }

    /// Collapses `..`, duplicate separators and trailing slashes without
    /// touching the filesystem.
    ///
    /// Relative paths are returned unchanged: resolving them would silently
    /// anchor them to the current working directory and make an invalid profile
    /// look valid. Callers reject them instead.
    public static func normalize(_ path: String) -> String {
        guard !path.isEmpty, path.hasPrefix("/") else { return path }
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized.count > 1 && standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized
    }

    public static func isAbsolute(_ path: String) -> Bool {
        path.hasPrefix("/")
    }

    /// True when `child` is `parent` itself or nested underneath it.
    public static func isSameOrInside(_ child: String, parent: String) -> Bool {
        let c = normalize(child)
        let p = normalize(parent)
        return c == p || c.hasPrefix(p + "/")
    }
}
