import Foundation

/// Original artwork parameters for a generated launcher icon.
///
/// Deliberately simple: a two-stop gradient and a short monogram. No Codex or
/// OpenAI artwork is copied or redistributed by this project.
public struct IconSpec: Codable, Equatable, Sendable {
    public var label: String
    public var tintTop: String
    public var tintBottom: String

    public init(label: String, tintTop: String, tintBottom: String) {
        self.label = label
        self.tintTop = tintTop
        self.tintBottom = tintBottom
    }
}

/// Everything that distinguishes one generated launcher from another.
///
/// This is the single place profile-specific values live. `scripts/build.sh`
/// reads a `profiles/<slug>.json`, copies it into the generated bundle at
/// `Contents/Resources/profile.json`, and the launcher reads it back at runtime.
public struct Profile: Codable, Equatable, Sendable {
    /// Human-readable profile name, e.g. `Personal`.
    public var name: String
    /// Filename-safe identifier, e.g. `personal`.
    public var slug: String
    /// Name of the generated app bundle, e.g. `Codex Personal`.
    public var appName: String
    /// Bundle identifier of the generated launcher (never Codex's own).
    public var bundleIdentifier: String
    /// Isolated `CODEX_HOME`, e.g. `~/.codex-personal`.
    public var codexHome: String
    /// Isolated Electron user-data directory.
    public var electronUserDataPath: String
    /// Optional pinned path to the Codex application bundle. When omitted the
    /// launcher discovers Codex itself.
    public var codexAppPath: String?
    public var icon: IconSpec?

    public init(
        name: String,
        slug: String,
        appName: String,
        bundleIdentifier: String,
        codexHome: String,
        electronUserDataPath: String,
        codexAppPath: String? = nil,
        icon: IconSpec? = nil
    ) {
        self.name = name
        self.slug = slug
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.codexHome = codexHome
        self.electronUserDataPath = electronUserDataPath
        self.codexAppPath = codexAppPath
        self.icon = icon
    }

    public static func load(contentsOf url: URL) throws -> Profile {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LauncherError.profileUnreadable(path: url.path, underlying: error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(Profile.self, from: data)
        } catch {
            throw LauncherError.profileMalformed(path: url.path, underlying: String(describing: error))
        }
    }

    /// The default `CODEX_HOME` that the stock Codex installation uses. A
    /// profile is never allowed to point at it.
    public static let defaultCodexHomeSuffix = ".codex"
}
