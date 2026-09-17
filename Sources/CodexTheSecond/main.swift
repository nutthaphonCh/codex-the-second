import AppKit
import CodexTheSecondCore
import Foundation

/// Read from the generated bundle so there is one source of truth for the
/// version: the VERSION file, via scripts/build.sh.
let launcherVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    ?? "0.0.0-unbundled"

/// Shows a native alert. Errors must be understandable without a Terminal.
func presentAlert(title: String, message: String, style: NSAlert.Style = .critical) {
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

/// Suppresses the GUI alert. Set by CI and useful over SSH, where a modal
/// alert would block forever with nobody to dismiss it.
let alertsDisabledEnvironmentKey = "CODEX_THE_SECOND_NO_ALERTS"

func alertsAreAvailable() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    if let disabled = environment[alertsDisabledEnvironmentKey], !disabled.isEmpty {
        return false
    }
    // Run from a terminal, the message on stderr is the better channel.
    return isatty(STDERR_FILENO) == 0
}

func fail(_ error: LauncherError) -> Never {
    FileHandle.standardError.write(Data("\(error.title)\n\(error.message)\n".utf8))
    if alertsAreAvailable() {
        presentAlert(title: error.title, message: error.message)
    }
    exit(1)
}

/// Resolves the profile for this launcher.
///
/// `CODEX_THE_SECOND_PROFILE_FILE` exists so the binary can be exercised
/// straight out of `swift build`, without an app bundle, during verification.
func loadProfile() throws -> Profile {
    let environment = ProcessInfo.processInfo.environment
    if let override = environment["CODEX_THE_SECOND_PROFILE_FILE"],
       !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let path = PathResolver.expand(override, homeDirectory: NSHomeDirectory())
        return try Profile.load(contentsOf: URL(fileURLWithPath: path))
    }

    guard let bundled = Bundle.main.url(forResource: "profile", withExtension: "json") else {
        throw LauncherError.profileMissing
    }
    return try Profile.load(contentsOf: bundled)
}

func run() {
    let arguments = Array(CommandLine.arguments.dropFirst())

    if arguments.contains("--version") {
        print("CodexTheSecond \(launcherVersion)")
        exit(0)
    }
    if arguments.contains("--help") || arguments.contains("-h") {
        print("""
        CodexTheSecond \(launcherVersion)

        Launches your existing Codex Desktop installation with an isolated
        profile. Normally there is nothing to run by hand — open the generated
        application instead.

          --print-plan   Resolve everything and print what would be launched,
                         then exit without starting Codex.
          --version      Print the launcher version.
          --help         Show this message.
        """)
        exit(0)
    }

    let environment = ProcessInfo.processInfo.environment
    let home = NSHomeDirectory()

    let profile: Profile
    do {
        profile = try loadProfile()
    } catch let error as LauncherError {
        fail(error)
    } catch {
        fail(.profileInvalid(reason: error.localizedDescription))
    }

    let locator = CodexAppLocator(
        launchServicesLookup: LaunchServicesLookup.path(forAnyOf:)
    )

    do {
        try LaunchPlanBuilder.validate(profile: profile, homeDirectory: home)
        let codexApp = try locator.locate(profile: profile, environment: environment, homeDirectory: home)
        let plan = try LaunchPlanBuilder.make(
            profile: profile,
            codexApp: codexApp,
            baseEnvironment: environment,
            homeDirectory: home
        )

        // Consult the filesystem before anything else acts on the plan, so a
        // profile that only looks isolated cannot reach Codex - and so
        // --print-plan reports what would really happen, not the intent.
        try IsolationGuard().assertIsolated(plan, homeDirectory: home)

        if arguments.contains("--print-plan") {
            var described = plan.describedForDiagnostics
            described["profile"] = profile.name
            described["codexBundle"] = codexApp.bundlePath
            described["codexBundleIdentifier"] = codexApp.bundleIdentifier ?? "(none)"
            described["codexVersion"] = codexApp.shortVersion ?? "(unknown)"
            let data = try JSONSerialization.data(
                withJSONObject: described,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(decoding: data, as: UTF8.self))
            exit(0)
        }

        let launcher = ProfileLauncher()
        try launcher.prepareDirectories(plan)
        let process = try launcher.launch(plan)
        try launcher.checkForEarlyFailure(process, executablePath: plan.executablePath)
    } catch let error as LauncherError {
        fail(error)
    } catch {
        fail(.launchFailed(executable: "Codex", underlying: error.localizedDescription))
    }

    // Codex is running as an independent process; this shim has no further work.
    exit(0)
}

run()
