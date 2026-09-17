import Foundation

/// A generated launcher that is installed on this machine.
public struct InstalledLauncher: Equatable, Sendable {
    public let bundlePath: String
    public let executablePath: String
    public let profile: Profile

    public var appName: String { profile.appName }
}

/// Finds the launchers this project has generated, by looking for the profile
/// each one carries at `Contents/Resources/profile.json`.
///
/// Deliberately the same two directories the Codex search uses, for the same
/// reason: a filesystem-wide sweep is slow and can surface a copy in Downloads
/// or a mounted disk image.
public struct InstalledLauncherLocator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static func searchDirectories(homeDirectory: String) -> [String] {
        ["/Applications", homeDirectory + "/Applications"]
    }

    public func findAll(homeDirectory: String) -> [InstalledLauncher] {
        var found: [InstalledLauncher] = []

        for directory in Self.searchDirectories(homeDirectory: homeDirectory) {
            let entries = (try? fileManager.contentsOfDirectory(atPath: directory)) ?? []
            for entry in entries.sorted() where entry.hasSuffix(".app") {
                let bundlePath = directory + "/" + entry
                guard let launcher = inspect(bundlePath: bundlePath) else { continue }
                // First spelling wins, so /Applications takes precedence.
                if !found.contains(where: { $0.profile.slug == launcher.profile.slug }) {
                    found.append(launcher)
                }
            }
        }
        return found
    }

    public func find(slug: String, homeDirectory: String) -> InstalledLauncher? {
        findAll(homeDirectory: homeDirectory).first { $0.profile.slug == slug }
    }

    /// A bundle is one of ours only if it carries a readable profile.
    func inspect(bundlePath: String) -> InstalledLauncher? {
        let profilePath = bundlePath + "/Contents/Resources/profile.json"
        guard fileManager.fileExists(atPath: profilePath),
              let profile = try? Profile.load(contentsOf: URL(fileURLWithPath: profilePath))
        else { return nil }

        let plistPath = bundlePath + "/Contents/Info.plist"
        guard let data = fileManager.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let executable = plist["CFBundleExecutable"] as? String
        else { return nil }

        let executablePath = bundlePath + "/Contents/MacOS/" + executable
        guard fileManager.isExecutableFile(atPath: executablePath) else { return nil }

        return InstalledLauncher(
            bundlePath: PathResolver.normalize(bundlePath),
            executablePath: executablePath,
            profile: profile
        )
    }
}
