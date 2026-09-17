import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Asks LaunchServices *where* an application is installed.
///
/// A lookup only — it resolves a path and never starts anything. Codex is
/// always started as a direct child process; see the launcher's spawn path.
/// Shared so the app bundle and the `c2nd` command discover Codex identically.
public enum LaunchServicesLookup {
    public static func path(forAnyOf identifiers: [String]) -> String? {
        #if canImport(AppKit)
        for identifier in identifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return url.path
            }
        }
        #endif
        return nil
    }
}
