import Foundation

public struct ProfileLauncher {
    /// Codex is given this long to fail visibly. A profile instance that is
    /// already running exits 0 almost immediately (its existing window is
    /// focused instead), which is success, not failure.
    public static let earlyFailureWindow: TimeInterval = 1.5

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Creates the isolated profile directories with owner-only permissions.
    ///
    /// Existing directories are left untouched: no migration, no reset, no
    /// rewriting of anything already there.
    public func prepareDirectories(_ plan: LaunchPlan) throws {
        for path in plan.directoriesToCreate {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else {
                    throw LauncherError.directoryCreationFailed(
                        path: path,
                        underlying: "A file already exists at this path, so the folder cannot be created."
                    )
                }
                continue
            }
            do {
                try fileManager.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch {
                throw LauncherError.directoryCreationFailed(
                    path: path,
                    underlying: error.localizedDescription
                )
            }
        }
    }

    /// Spawns Codex directly as a child process.
    ///
    /// Deliberately not `open`/LaunchServices: routing the request through
    /// LaunchServices can hand it to an already-running Codex process, which
    /// would ignore this profile entirely. A direct spawn also guarantees the
    /// isolated environment is in place before Electron initialises.
    @discardableResult
    public func launch(_ plan: LaunchPlan) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: plan.executablePath)
        process.arguments = plan.arguments
        process.environment = plan.environment
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            try process.run()
        } catch {
            throw LauncherError.launchFailed(
                executable: plan.executablePath,
                underlying: error.localizedDescription
            )
        }
        return process
    }

    /// Waits briefly so an immediate crash can be reported instead of leaving
    /// the user with a launcher that silently did nothing.
    public func checkForEarlyFailure(
        _ process: Process,
        executablePath: String,
        window: TimeInterval = ProfileLauncher.earlyFailureWindow,
        now: () -> Date = Date.init,
        sleep: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) throws {
        let deadline = now().addingTimeInterval(window)
        while now() < deadline {
            if !process.isRunning {
                let status = process.terminationStatus
                guard status == 0 else {
                    throw LauncherError.codexExitedImmediately(
                        executable: executablePath,
                        status: status
                    )
                }
                return
            }
            sleep(0.05)
        }
    }
}
