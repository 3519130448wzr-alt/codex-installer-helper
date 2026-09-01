import CodexInstallerCore
import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private struct StaticDownloader: InstallerScriptDownloading {
    let scriptURL: URL
    func downloadInstallerScript() async throws -> URL { scriptURL }
}

private struct FailingDownloader: InstallerScriptDownloading {
    func downloadInstallerScript() async throws -> URL {
        throw InstallerFailure.downloadFailed("offline")
    }
}

private actor RecordingRunner: ProcessRunning {
    struct Call: Sendable {
        let executable: URL
        let arguments: [String]
    }

    private var results: [ProcessResult]
    private var recordedCalls: [Call] = []

    init(results: [ProcessResult]) {
        self.results = results
    }

    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessResult {
        recordedCalls.append(Call(executable: executable, arguments: arguments))
        guard !results.isEmpty else { return ProcessResult(exitCode: 0) }
        return results.removeFirst()
    }

    func calls() -> [Call] { recordedCalls }
}

@main
enum CoreTestRunner {
    static func main() async {
        let tests: [(String, () async throws -> Void)] = [
            ("version parser", testVersionParser),
            ("installation classification", testInstallationClassification),
            ("state transitions", testStateTransitions),
            ("download URL and script validation", testDownloadValidation),
            ("temporary HOME install and verification", testTemporaryHomeInstall),
            ("repeated install", testRepeatedInstall),
            ("failed installer", testFailedInstaller),
            ("network failure containment", testNetworkFailure),
            ("opaque authentication commands", testAuthenticationCommands),
        ]

        var failures: [String] = []
        for (name, test) in tests {
            do {
                try await test()
                print("PASS  \(name)")
            } catch {
                failures.append("\(name): \(error)")
                print("FAIL  \(name): \(error)")
            }
        }

        if failures.isEmpty {
            print("\nAll \(tests.count) tests passed.")
            exit(EXIT_SUCCESS)
        }
        print("\n\(failures.count) test(s) failed:")
        failures.forEach { print("- \($0)") }
        exit(EXIT_FAILURE)
    }

    private static func check(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() { throw TestFailure(description: message) }
    }

    private static func testVersionParser() async throws {
        try check(VersionParser.parse("codex-cli 1.2.3\n") == "1.2.3", "stable version")
        try check(VersionParser.parse("codex 0.99.0-alpha.2") == "0.99.0-alpha.2", "alpha version")
        try check(VersionParser.parse("not a version") == nil, "invalid output")
    }

    private static func testInstallationClassification() async throws {
        let home = URL(fileURLWithPath: "/Users/test")
        try check(
            CodexInstallerService.classifyInstallation(
                executableURL: home.appendingPathComponent(".local/bin/codex"),
                resolvedURL: home.appendingPathComponent(".codex/packages/standalone/current/bin/codex"),
                homeDirectory: home
            ) == .standalone,
            "standalone classification"
        )
        try check(
            CodexInstallerService.classifyInstallation(
                executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
                resolvedURL: URL(fileURLWithPath: "/opt/homebrew/Caskroom/codex/1.2.3/codex"),
                homeDirectory: home
            ) == .homebrew,
            "Homebrew classification"
        )
        try check(
            CodexInstallerService.classifyInstallation(
                executableURL: home.appendingPathComponent(".npm-global/bin/codex"),
                resolvedURL: home.appendingPathComponent(".npm-global/lib/node_modules/@openai/codex/bin/codex.js"),
                homeDirectory: home
            ) == .npm,
            "npm classification"
        )
        try check(
            CodexInstallerService.classifyInstallation(
                executableURL: home.appendingPathComponent(".bun/bin/codex"),
                resolvedURL: home.appendingPathComponent(".bun/install/global/node_modules/@openai/codex/bin/codex.js"),
                homeDirectory: home
            ) == .bun,
            "Bun classification"
        )
    }

    private static func testStateTransitions() async throws {
        try check(InstallerPhase.idle.allowsTransition(to: .inspecting), "idle to inspecting")
        try check(InstallerPhase.ready.allowsTransition(to: .downloading), "ready to downloading")
        try check(InstallerPhase.signingIn.allowsTransition(to: .awaitingLogin), "login retry")
        try check(!InstallerPhase.idle.allowsTransition(to: .complete), "reject idle to complete")
        try check(!InstallerPhase.installing.allowsTransition(to: .signingIn), "reject install to login")
    }

    private static func testDownloadValidation() async throws {
        try check(
            OfficialInstallerDownloader.isAllowedFinalURL(
                URL(string: "https://chatgpt.com/codex/install.sh")
            ),
            "official URL"
        )
        try check(
            !OfficialInstallerDownloader.isAllowedFinalURL(
                URL(string: "https://example.com/codex/install.sh")
            ),
            "reject third-party URL"
        )
        try check(
            OfficialInstallerDownloader.isAllowedFinalURL(
                URL(string: "https://releases.openai.com/codex/install.sh")
            ),
            "official release redirect"
        )
        try check(
            !OfficialInstallerDownloader.isAllowedFinalURL(
                URL(string: "https://releases.openai.com/other/install.sh")
            ),
            "reject unexpected official-domain path"
        )
        let validScript = Data(
            "#!/bin/sh\nCODEX_INSTALL_DIR=x\nRELEASES_BASE=https://releases.openai.com/codex\n".utf8
        )
        try check(OfficialInstallerDownloader.isValidScript(validScript), "official script signals")
        try check(
            !OfficialInstallerDownloader.isValidScript(Data("#!/bin/sh\necho mirror\n".utf8)),
            "reject unrecognized script"
        )
    }

    private static func testTemporaryHomeInstall() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let scriptURL = try makeInstallerScript(version: "1.2.3")
        let service = CodexInstallerService(
            downloader: StaticDownloader(scriptURL: scriptURL),
            homeDirectory: home
        )
        let result = try await service.runOfficialInstaller(
            at: try await service.downloadOfficialInstaller()
        )
        try check(result.exitCode == 0, "installer exit")
        let verifiedVersion = try await service.verifyCodex()
        try check(verifiedVersion == "1.2.3", "verified version")
        let inspection = await service.inspect()
        try check(inspection.manager == .standalone, "inspection after install")
        try check(
            !FileManager.default.fileExists(atPath: scriptURL.deletingLastPathComponent().path),
            "temporary script cleanup"
        )
    }

    private static func testRepeatedInstall() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        for version in ["1.0.0", "1.1.0"] {
            let scriptURL = try makeInstallerScript(version: version)
            let service = CodexInstallerService(
                downloader: StaticDownloader(scriptURL: scriptURL),
                homeDirectory: home
            )
            _ = try await service.runOfficialInstaller(at: scriptURL)
            let verifiedVersion = try await service.verifyCodex()
            try check(verifiedVersion == version, "version \(version)")
        }
        let binary = home.appendingPathComponent(".local/bin/codex")
        try check(FileManager.default.fileExists(atPath: binary.path), "single visible binary")
    }

    private static func testFailedInstaller() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = try makeScriptDirectory()
        let scriptURL = directory.appendingPathComponent("install.sh")
        try "#!/bin/sh\necho simulated checksum failure >&2\nexit 23\n".write(
            to: scriptURL,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        let service = CodexInstallerService(homeDirectory: home)
        do {
            _ = try await service.runOfficialInstaller(at: scriptURL)
            throw TestFailure(description: "expected failure")
        } catch let failure as InstallerFailure {
            guard case let .processFailed(_, exitCode, message) = failure else { throw failure }
            try check(exitCode == 23, "failure exit code")
            try check(message.contains("checksum failure"), "failure detail")
        }
    }

    private static func testNetworkFailure() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let service = CodexInstallerService(
            downloader: FailingDownloader(),
            homeDirectory: home
        )
        do {
            _ = try await service.downloadOfficialInstaller()
            throw TestFailure(description: "expected download failure")
        } catch is InstallerFailure {
            try check(
                !FileManager.default.fileExists(atPath: service.standaloneExecutableURL.path),
                "no binary after network failure"
            )
        }
    }

    private static func testAuthenticationCommands() async throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let executable = home.appendingPathComponent(".local/bin/codex")
        let runner = RecordingRunner(results: [
            ProcessResult(exitCode: 1, standardOutput: "Not logged in"),
            ProcessResult(exitCode: 0, standardOutput: "Login successful"),
        ])
        let service = CodexAuthService(runner: runner, homeDirectory: home)
        let status = await service.loginStatus(executableURL: executable)
        try check(!status.isLoggedIn, "logged-out exit status")
        _ = try await service.login(executableURL: executable)

        let calls = await runner.calls()
        try check(calls.count == 2, "two auth subprocesses")
        try check(calls[0].arguments == ["login", "status"], "status arguments")
        try check(calls[1].arguments == ["login"], "browser login arguments")
        try check(calls.allSatisfy { $0.executable == executable }, "direct executable use")
    }

    private static func makeTemporaryHome() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-installer-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeInstallerScript(version: String) throws -> URL {
        let directory = try makeScriptDirectory()
        let scriptURL = directory.appendingPathComponent("install.sh")
        let script = """
        #!/bin/sh
        set -eu
        mkdir -p "$CODEX_INSTALL_DIR"
        printf '%s\n' '#!/bin/sh' 'echo "codex-cli \(version)"' > "$CODEX_INSTALL_DIR/codex"
        chmod 700 "$CODEX_INSTALL_DIR/codex"
        echo fake install complete
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private static func makeScriptDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-installer-script-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
