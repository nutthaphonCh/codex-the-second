import Foundation

/// Moves a profile folder that an earlier version of this launcher created.
///
/// Renaming the default profile folder is the launcher's doing, so cleaning up
/// after it is the launcher's job. It is still never done silently: this type
/// only ever *reports* what it found, and the move happens when the caller has
/// been told yes by the user.
public struct ProfileMigration {
    public enum Finding: Equatable {
        /// Nothing to migrate, or the profile is already in place.
        case nothingToDo
        /// An old folder exists and the new one does not.
        case available(from: String, to: String, byteCount: Int64?)
        /// Both exist, or the move cannot be made safely.
        case blocked(from: String, to: String, reason: String)
    }

    private let fileManager: FileManager
    private let isInUse: (String) -> Bool

    public init(
        fileManager: FileManager = .default,
        isInUse: @escaping (String) -> Bool = ProfileMigration.defaultIsInUse
    ) {
        self.fileManager = fileManager
        self.isInUse = isInUse
    }

    /// True when a Codex process is running out of this profile folder.
    ///
    /// Moving a folder from under a running Electron app corrupts it: open
    /// SQLite handles and the singleton lock keep pointing at the old inode.
    /// Refusing is the only safe answer.
    public static func defaultIsInUse(_ path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        // Leading dashes would be parsed as options, so match on the path.
        process.arguments = ["-f", "user-data-dir=" + path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return !data.isEmpty
    }

    public func inspect(profile: Profile, homeDirectory: String) -> Finding {
        guard let legacy = profile.migrateFrom?.trimmingCharacters(in: .whitespacesAndNewlines),
              !legacy.isEmpty
        else { return .nothingToDo }

        let from = PathResolver.expand(legacy, homeDirectory: homeDirectory)
        let to = PathResolver.expand(profile.codexHome, homeDirectory: homeDirectory)

        guard isDirectory(from) else { return .nothingToDo }

        if isInUse(from) {
            return .blocked(
                from: from, to: to,
                reason: "Codex is still running from that folder. Quit it, then try again."
            )
        }

        // Refuse to touch the stock installation, whatever the profile claims.
        let defaultHome = PathResolver.expand(
            "~/" + Profile.defaultCodexHomeSuffix,
            homeDirectory: homeDirectory
        )
        if PathResolver.isSameOrInside(from, parent: defaultHome) {
            return .blocked(from: from, to: to, reason: "That folder belongs to your normal Codex installation.")
        }
        if from == to { return .nothingToDo }

        if isDirectory(to) {
            // An empty directory is what a previous launch may have created
            // before the user chose to migrate; anything else is real data.
            let contents = (try? fileManager.contentsOfDirectory(atPath: to)) ?? []
            let meaningful = contents.filter { $0 != ".DS_Store" }
            guard meaningful.isEmpty else {
                return .blocked(
                    from: from, to: to,
                    reason: "Both folders already exist, so moving one over the other could lose data."
                )
            }
        }

        return .available(from: from, to: to, byteCount: size(of: from))
    }

    /// Moves the folder. On one volume this is a rename: instant, and it keeps
    /// every byte and permission exactly as they were. Copying would duplicate
    /// the profile, which for a signed-in Codex profile is gigabytes.
    public func perform(from: String, to: String) throws {
        let destination = URL(fileURLWithPath: to)
        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Clear the empty placeholder a previous launch may have left.
            if isDirectory(to), ((try? fileManager.contentsOfDirectory(atPath: to)) ?? []).isEmpty {
                try fileManager.removeItem(atPath: to)
            }
            try fileManager.moveItem(atPath: from, toPath: to)
        } catch {
            throw LauncherError.migrationFailed(
                from: from, to: to, underlying: error.localizedDescription
            )
        }
    }

    func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func size(of path: String) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize ?? 0)
        }
        return total
    }

    public static func describe(byteCount: Int64?) -> String {
        guard let byteCount else { return "an unknown amount of data" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }
}
