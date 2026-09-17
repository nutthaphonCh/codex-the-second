import Foundation

/// A validated Codex application bundle.
public struct CodexApp: Equatable, Sendable {
    public let bundlePath: String
    public let executablePath: String
    public let bundleIdentifier: String?
    public let shortVersion: String?

    public init(bundlePath: String, executablePath: String, bundleIdentifier: String?, shortVersion: String?) {
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
        self.shortVersion = shortVersion
    }
}

/// Why a candidate path is not a usable Codex installation, phrased for the
/// user rather than for a log.
public struct BundleInspectionFailure: Error, Equatable, Sendable {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }
}

/// Reads an application bundle's `Info.plist` and resolves its executable.
public protocol BundleInspecting {
    func inspect(bundlePath: String) -> Result<CodexApp, BundleInspectionFailure>
}

public struct FileSystemBundleInspector: BundleInspecting {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func inspect(bundlePath: String) -> Result<CodexApp, BundleInspectionFailure> {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: bundlePath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failure(BundleInspectionFailure("No application bundle exists at this path."))
        }

        let plistPath = bundlePath + "/Contents/Info.plist"
        guard let plistData = fileManager.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else {
            return .failure(BundleInspectionFailure("The bundle has no readable Contents/Info.plist, so it is not a macOS application."))
        }

        guard let executableName = plist["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            return .failure(BundleInspectionFailure("The bundle's Info.plist does not name an executable (CFBundleExecutable)."))
        }

        // The executable name is read from Info.plist rather than assumed: the
        // shipping Codex Desktop bundle does not necessarily use "Codex".
        let executablePath = bundlePath + "/Contents/MacOS/" + executableName
        guard fileManager.fileExists(atPath: executablePath) else {
            return .failure(BundleInspectionFailure("The bundle's executable is missing:\n \(executablePath)"))
        }
        guard fileManager.isExecutableFile(atPath: executablePath) else {
            return .failure(BundleInspectionFailure("The bundle's executable is not runnable:\n \(executablePath)"))
        }

        return .success(
            CodexApp(
                bundlePath: PathResolver.normalize(bundlePath),
                executablePath: executablePath,
                bundleIdentifier: plist["CFBundleIdentifier"] as? String,
                shortVersion: plist["CFBundleShortVersionString"] as? String
            )
        )
    }
}

/// One place to look for Codex, and what must be true for that location to be
/// accepted.
public struct CodexAppCandidate: Equatable, Sendable {
    public let path: String
    /// When non-empty, the bundle must declare one of these identifiers. This
    /// guards paths that are ambiguous — `ChatGPT.app` may be the Codex Desktop
    /// bundle on one machine and the plain ChatGPT app on another.
    public let requiredBundleIdentifiers: [String]
    /// Explicit locations (user override, pinned profile path) fail loudly
    /// instead of falling through to the next candidate.
    public let isExplicit: Bool

    public init(path: String, requiredBundleIdentifiers: [String] = [], isExplicit: Bool = false) {
        self.path = path
        self.requiredBundleIdentifiers = requiredBundleIdentifiers
        self.isExplicit = isExplicit
    }
}

public struct CodexAppLocator {
    /// Bundle identifiers known to belong to Codex Desktop.
    public static let knownBundleIdentifiers = ["com.openai.codex"]

    /// Environment variable that pins the Codex bundle for one launch.
    public static let overrideEnvironmentKey = "CODEX_THE_SECOND_CODEX_APP"

    /// Persistent user override, relative to the home directory.
    public static let overrideFileRelativePath =
        "Library/Application Support/CodexTheSecond/codex-app-path"

    private let inspector: BundleInspecting
    private let readOverrideFile: (String) -> String?
    /// Ask LaunchServices *where* Codex is. This is a lookup, never a launch —
    /// the app itself is always started as a direct child process.
    private let launchServicesLookup: ([String]) -> String?

    public init(
        inspector: BundleInspecting = FileSystemBundleInspector(),
        readOverrideFile: @escaping (String) -> String? = CodexAppLocator.defaultReadOverrideFile,
        launchServicesLookup: @escaping ([String]) -> String? = { _ in nil }
    ) {
        self.inspector = inspector
        self.readOverrideFile = readOverrideFile
        self.launchServicesLookup = launchServicesLookup
    }

    public static func defaultReadOverrideFile(_ path: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let first = contents.split(separator: "\n", omittingEmptySubsequences: true).first
        let trimmed = first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The ordered search path, most specific first.
    public func candidates(
        profile: Profile,
        environment: [String: String],
        homeDirectory: String
    ) -> [CodexAppCandidate] {
        var result: [CodexAppCandidate] = []

        func explicit(_ raw: String?) {
            guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            result.append(
                CodexAppCandidate(
                    path: PathResolver.expand(raw, homeDirectory: homeDirectory),
                    isExplicit: true
                )
            )
        }

        explicit(environment[Self.overrideEnvironmentKey])
        explicit(profile.codexAppPath)
        explicit(readOverrideFile(homeDirectory + "/" + Self.overrideFileRelativePath))

        // Unambiguous names: accept whatever is installed there.
        for directory in ["/Applications", homeDirectory + "/Applications"] {
            result.append(CodexAppCandidate(path: directory + "/Codex.app"))
            result.append(CodexAppCandidate(path: directory + "/Codex Desktop.app"))
        }

        // Codex Desktop currently ships as ChatGPT.app with the com.openai.codex
        // identifier, so this path is only accepted after the identifier matches.
        for directory in ["/Applications", homeDirectory + "/Applications"] {
            result.append(
                CodexAppCandidate(
                    path: directory + "/ChatGPT.app",
                    requiredBundleIdentifiers: Self.knownBundleIdentifiers
                )
            )
        }

        if let discovered = launchServicesLookup(Self.knownBundleIdentifiers) {
            result.append(
                CodexAppCandidate(
                    path: PathResolver.normalize(discovered),
                    requiredBundleIdentifiers: Self.knownBundleIdentifiers
                )
            )
        }

        return result
    }

    public func locate(
        profile: Profile,
        environment: [String: String],
        homeDirectory: String
    ) throws -> CodexApp {
        var searched: [String] = []

        for candidate in candidates(profile: profile, environment: environment, homeDirectory: homeDirectory) {
            if !searched.contains(candidate.path) {
                searched.append(candidate.path)
            }

            switch inspector.inspect(bundlePath: candidate.path) {
            case let .success(app):
                if !candidate.requiredBundleIdentifiers.isEmpty {
                    guard let identifier = app.bundleIdentifier,
                          candidate.requiredBundleIdentifiers.contains(identifier)
                    else {
                        if candidate.isExplicit {
                            throw LauncherError.codexPathInvalid(
                                path: candidate.path,
                                reason: "This application is not Codex Desktop."
                            )
                        }
                        continue
                    }
                }
                return app

            case let .failure(failure):
                if candidate.isExplicit {
                    throw LauncherError.codexPathInvalid(path: candidate.path, reason: failure.reason)
                }
                continue
            }
        }

        throw LauncherError.codexNotFound(searched: searched)
    }
}
