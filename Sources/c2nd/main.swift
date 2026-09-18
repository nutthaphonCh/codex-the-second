import CodexTheSecondCore
import Foundation

let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0-unbundled"
let home = NSHomeDirectory()
let environment = ProcessInfo.processInfo.environment

func out(_ line: String = "", terminator: String = "\n") { print(line, terminator: terminator) }
func err(_ line: String) { FileHandle.standardError.write(Data((line + "\n").utf8)) }

/// A terminal tool reports failures on stderr. It never raises the GUI alert
/// the .app uses - nobody is there to dismiss it.
func fail(_ error: LauncherError) -> Never {
    err(error.title)
    err(error.message)
    exit(1)
}

func fail(_ message: String) -> Never {
    err(message)
    exit(1)
}

let codexLocator = CodexAppLocator(launchServicesLookup: LaunchServicesLookup.path(forAnyOf:))
let installedLocator = InstalledLauncherLocator()

func installed() -> [InstalledLauncher] {
    installedLocator.findAll(homeDirectory: home)
}

func launcher(forSlug slug: String) -> InstalledLauncher {
    guard let match = installedLocator.find(slug: slug, homeDirectory: home) else {
        let known = installed().map(\.profile.slug)
        err("No installed profile called \"\(slug)\".")
        err(known.isEmpty
            ? "None are installed. Install one from the releases page, then try again."
            : "Installed: " + known.joined(separator: ", "))
        exit(1)
    }
    return match
}

/// Everything `launch` and `plan` share: resolve Codex, build the plan, and put
/// it through the same isolation guard the .app uses. One path, so the command
/// line cannot become a way around the safety checks.
func plan(for launcher: InstalledLauncher) throws -> (LaunchPlan, CodexApp) {
    let profile = launcher.profile
    try LaunchPlanBuilder.validate(profile: profile, homeDirectory: home)
    let codex = try codexLocator.locate(profile: profile, environment: environment, homeDirectory: home)
    let plan = try LaunchPlanBuilder.make(
        profile: profile,
        codexApp: codex,
        baseEnvironment: environment,
        homeDirectory: home
    )
    try IsolationGuard().assertIsolated(plan, homeDirectory: home)
    return (plan, codex)
}

func isRunning(_ plan: LaunchPlan) -> Bool {
    // Matches how the profile instance is started: the isolated user-data
    // directory appears in its argument list.
    //
    // The leading "--" is left off the pattern on purpose. pgrep parses an
    // argument beginning with "--" as an option and fails with "illegal option
    // -- -", which reported every running profile as stopped. The path alone is
    // specific enough.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-f", "user-data-dir=" + plan.electronUserDataPath]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return false }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return !data.isEmpty
}

// MARK: - Commands

func commandList() {
    let launchers = installed()
    guard !launchers.isEmpty else {
        out("No profile launchers installed.")
        out("")
        out("Looked in:")
        for directory in InstalledLauncherLocator.searchDirectories(homeDirectory: home) {
            out("  \(directory)")
        }
        out("")
        out("Install one from https://github.com/nutthaphonCh/codex-the-second/releases")
        return
    }

    out("PROFILE      APP                      CODEX_HOME                      STATE")
    for launcher in launchers {
        let codexHome = PathResolver.expand(launcher.profile.codexHome, homeDirectory: home)
        let state = (try? plan(for: launcher)).map { isRunning($0.0) ? "running" : "stopped" } ?? "error"
        out(pad(launcher.profile.slug, 12)
            + pad(launcher.appName, 25)
            + pad(shorten(codexHome), 32)
            + state)
    }
}

func commandLaunch(slug: String) {
    let target = launcher(forSlug: slug)
    do {
        let (resolved, _) = try plan(for: target)
        let profileLauncher = ProfileLauncher()
        try profileLauncher.prepareDirectories(resolved)
        try ProfileNote().write(resolved, profileName: target.profile.name, homeDirectory: home)
        ProfileSkill().write(resolved, profile: target.profile, homeDirectory: home)
        let process = try profileLauncher.launch(resolved)
        try profileLauncher.checkForEarlyFailure(process, executablePath: resolved.executablePath)
        out("Started \(target.appName) with CODEX_HOME=\(shorten(resolved.codexHome))")
    } catch let error as LauncherError {
        fail(error)
    } catch {
        fail(error.localizedDescription)
    }
}

func commandPlan(slug: String) {
    let target = launcher(forSlug: slug)
    do {
        let (resolved, codex) = try plan(for: target)
        var described = resolved.describedForDiagnostics
        described["profile"] = target.profile.name
        described["launcher"] = target.bundlePath
        described["codexBundle"] = codex.bundlePath
        described["codexBundleIdentifier"] = codex.bundleIdentifier ?? "(none)"
        described["codexVersion"] = codex.shortVersion ?? "(unknown)"
        let data = try JSONSerialization.data(
            withJSONObject: described,
            options: [.prettyPrinted, .sortedKeys]
        )
        out(String(decoding: data, as: UTF8.self))
    } catch let error as LauncherError {
        fail(error)
    } catch {
        fail(error.localizedDescription)
    }
}

func commandMigrate(slug: String) {
    let target = launcher(forSlug: slug)
    switch ProfileMigration().inspect(profile: target.profile, homeDirectory: home) {
    case .nothingToDo:
        out("Nothing to move — \(target.profile.name) is already in place.")
    case let .blocked(from, to, reason):
        err("Cannot move \(shorten(from)) to \(shorten(to)).")
        err(reason)
        exit(1)
    case let .available(from, to, byteCount):
        out("Move \(shorten(from)) to \(shorten(to))?")
        out("  \(ProfileMigration.describe(byteCount: byteCount)), renamed in place — no copy, no extra disk.")
        out("")
        out("Type \"yes\" to continue: ", terminator: "")
        guard readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes" else {
            out("Left alone.")
            return
        }
        do {
            try ProfileMigration().perform(from: from, to: to)
            out("Moved. \(target.appName) will use \(shorten(to)).")
        } catch let error as LauncherError {
            fail(error)
        } catch {
            fail(error.localizedDescription)
        }
    }
}

func commandDoctor() {
    var problems = 0
    func check(_ label: String, _ detail: String, ok: Bool) {
        out("  \(ok ? "ok  " : "FAIL") \(pad(label, 26))\(detail)")
        if !ok { problems += 1 }
    }

    out("Codex Desktop")
    let anyProfile = installed().first?.profile
    switch Result(catching: {
        try codexLocator.locate(
            profile: anyProfile ?? Profile(
                name: "probe", slug: "probe", appName: "probe",
                bundleIdentifier: "io.github.nutthaphonch.codex-the-second.probe",
                codexHome: "~/.codex-probe",
                electronUserDataPath: "~/.codex-probe/electron-user-data"
            ),
            environment: environment,
            homeDirectory: home
        )
    }) {
    case let .success(codex):
        check("found", codex.bundlePath, ok: true)
        check("identifier", codex.bundleIdentifier ?? "(none)", ok: codex.bundleIdentifier == "com.openai.codex")
        check("version", codex.shortVersion ?? "(unknown)", ok: true)
        check("executable", codex.executablePath, ok: FileManager.default.isExecutableFile(atPath: codex.executablePath))
    case let .failure(error):
        check("found", (error as? LauncherError)?.title ?? "\(error)", ok: false)
    }

    let launchers = installed()
    out("")
    out("Installed profiles (\(launchers.count))")
    if launchers.isEmpty {
        check("none found", InstalledLauncherLocator.searchDirectories(homeDirectory: home).joined(separator: ", "), ok: false)
    }
    for launcher in launchers {
        out("  \(launcher.profile.slug) — \(launcher.bundlePath)")
        do {
            let (resolved, _) = try plan(for: launcher)
            check("profile valid", launcher.profile.appName, ok: true)
            check("isolated from ~/.codex", shorten(resolved.codexHome), ok: true)
            check("state", isRunning(resolved) ? "running" : "stopped", ok: true)
            if launcher.profile.allowAuthFromDefaultProfile == true {
                check(
                    "auth borrowing",
                    "allowed from ~/.codex, with consent each time",
                    ok: true
                )
            }
            for directory in resolved.directoriesToCreate {
                let exists = FileManager.default.fileExists(atPath: directory)
                check(exists ? "exists" : "not created yet", shorten(directory), ok: true)
            }
        } catch let error as LauncherError {
            check("rejected", error.title, ok: false)
            for line in error.message.split(separator: "\n").prefix(4) {
                out("       \(line)")
            }
        } catch {
            check("rejected", error.localizedDescription, ok: false)
        }
    }

    out("")
    out(problems == 0 ? "No problems found." : "\(problems) problem(s) found.")
    exit(problems == 0 ? 0 : 1)
}

func commandHelp() {
    out("""
    c2nd \(version) — run a second Codex account from the command line

    USAGE
      c2nd                     list installed profiles (same as `c2nd list`)
      c2nd list                installed profiles, their folders and state
      c2nd launch <profile>    start that profile
      c2nd plan <profile>      show what would be launched, without launching
      c2nd migrate <profile>   move a profile folder left by an older version
      c2nd doctor              check Codex, every profile, and its isolation
      c2nd version

    `plan` and `doctor` print only CODEX_HOME and CODEX_ELECTRON_USER_DATA_PATH,
    never the rest of the environment, so their output is safe to paste.

    This drives the launchers installed in /Applications; it does not create
    them. Build a new profile from the repository with scripts/build.sh.
    """)
}

// MARK: - Helpers

func pad(_ value: String, _ width: Int) -> String {
    value.count >= width ? value + " " : value + String(repeating: " ", count: width - value.count)
}

func shorten(_ path: String) -> String {
    path.hasPrefix(home + "/") ? "~/" + path.dropFirst(home.count + 1) : path
}

extension Result where Failure == Error {
    init(catching body: () throws -> Success) {
        do { self = .success(try body()) } catch { self = .failure(error) }
    }
}

// MARK: - Entry point

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case nil, "list", "ls":
    commandList()
case "launch", "run", "start":
    guard arguments.count >= 2 else { fail("Usage: c2nd launch <profile>") }
    commandLaunch(slug: arguments[1])
case "plan":
    guard arguments.count >= 2 else { fail("Usage: c2nd plan <profile>") }
    commandPlan(slug: arguments[1])
case "migrate":
    guard arguments.count >= 2 else { fail("Usage: c2nd migrate <profile>") }
    commandMigrate(slug: arguments[1])
case "doctor":
    commandDoctor()
case "version", "--version", "-v":
    out("c2nd \(version)")
case "help", "--help", "-h":
    commandHelp()
case let other?:
    err("Unknown command: \(other)")
    err("Run `c2nd help` for usage.")
    exit(2)
}
