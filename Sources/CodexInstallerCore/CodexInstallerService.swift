import Foundation

public final class CodexInstallerService: @unchecked Sendable {
    public static let shellURL = URL(fileURLWithPath: "/bin/sh")

    private let runner: any ProcessRunning
    private let downloader: any InstallerScriptDownloading
    private let fileManager: FileManager
    public let homeDirectory: URL

    public init(
        runner: any ProcessRunning = FoundationProcessRunner(),
        downloader: any InstallerScriptDownloading = OfficialInstallerDownloader(),
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.runner = runner
        self.downloader = downloader
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public var standaloneExecutableURL: URL {
        homeDirectory.appendingPathComponent(".local/bin/codex")
    }

    public func inspect() async -> InstallationInspection {
        if fileManager.isExecutableFile(atPath: standaloneExecutableURL.path) {
            return InstallationInspection(
                manager: .standalone,
                executableURL: standaloneExecutableURL,
                version: await versionIfAvailable(at: standaloneExecutableURL)
            )
        }

        for candidate in candidateExecutableURLs() where fileManager.isExecutableFile(atPath: candidate.path) {
            let resolved = candidate.resolvingSymlinksInPath()
            return InstallationInspection(
                manager: Self.classifyInstallation(
                    executableURL: candidate,
                    resolvedURL: resolved,
                    homeDirectory: homeDirectory
                ),
                executableURL: candidate,
                version: await versionIfAvailable(at: candidate)
            )
        }
        return InstallationInspection(manager: nil, executableURL: nil, version: nil)
    }

    public func downloadOfficialInstaller() async throws -> URL {
        try await downloader.downloadInstallerScript()
    }

    public func runOfficialInstaller(at scriptURL: URL) async throws -> ProcessResult {
        defer { cleanupTemporaryInstaller(at: scriptURL) }
        let environment = [
            "HOME": homeDirectory.path,
            "CODEX_NON_INTERACTIVE": "true",
            "CODEX_INSTALL_DIR": homeDirectory.appendingPathComponent(".local/bin").path,
        ]
        let result = try await runner.run(
            executable: Self.shellURL,
            arguments: [scriptURL.path],
            environment: environment,
            currentDirectory: homeDirectory
        )
        guard result.exitCode == 0 else {
            throw InstallerFailure.processFailed(
                command: "OpenAI 官方安装脚本",
                exitCode: result.exitCode,
                message: Self.safeMessage(from: result)
            )
        }
        return result
    }

    public func verifyCodex(at executableURL: URL? = nil) async throws -> String {
        let target = executableURL ?? standaloneExecutableURL
        guard fileManager.isExecutableFile(atPath: target.path) else {
            throw InstallerFailure.verificationFailed("没有在预期位置找到可执行文件：\(target.path)")
        }
        let result: ProcessResult
        do {
            result = try await runner.run(
                executable: target,
                arguments: ["--version"],
                environment: ["HOME": homeDirectory.path],
                currentDirectory: homeDirectory
            )
        } catch {
            throw InstallerFailure.verificationFailed(error.localizedDescription)
        }
        guard result.exitCode == 0,
              let version = VersionParser.parse(result.combinedOutput) else {
            throw InstallerFailure.verificationFailed(Self.safeMessage(from: result))
        }
        return version
    }

    public static func classifyInstallation(
        executableURL: URL,
        resolvedURL: URL,
        homeDirectory: URL
    ) -> InstallationManager {
        let original = executableURL.standardizedFileURL.path.lowercased()
        let resolved = resolvedURL.standardizedFileURL.path.lowercased()
        let standalone = homeDirectory.appendingPathComponent(".local/bin/codex")
            .standardizedFileURL.path.lowercased()
        let standaloneRoot = homeDirectory.appendingPathComponent(".codex/packages/standalone")
            .standardizedFileURL.path.lowercased()

        if original == standalone || resolved.hasPrefix(standaloneRoot + "/") {
            return .standalone
        }
        if resolved.contains("/caskroom/codex/") ||
            resolved.contains("/homebrew/") ||
            (original.hasPrefix("/opt/homebrew/") && !resolved.contains("node_modules")) {
            return .homebrew
        }
        if original.contains("/.bun/") || resolved.contains("/.bun/") {
            return .bun
        }
        if original.contains("node_modules") || resolved.contains("node_modules") ||
            original.contains("/.npm") || resolved.contains("/.npm") {
            return .npm
        }
        return .unknown
    }

    private func candidateExecutableURLs() -> [URL] {
        var paths: [String] = []
        if let environmentPath = ProcessInfo.processInfo.environment["PATH"] {
            paths.append(contentsOf: environmentPath.split(separator: ":").map(String.init))
        }
        paths.append(contentsOf: [
            homeDirectory.appendingPathComponent(".npm-global/bin").path,
            homeDirectory.appendingPathComponent(".bun/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
        ])

        var seen = Set<String>()
        return paths.compactMap { directory in
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("codex")
                .standardizedFileURL
            guard candidate != standaloneExecutableURL,
                  seen.insert(candidate.path).inserted else {
                return nil
            }
            return candidate
        }
    }

    private func versionIfAvailable(at executableURL: URL) async -> String? {
        let result = try? await runner.run(
            executable: executableURL,
            arguments: ["--version"],
            environment: ["HOME": homeDirectory.path],
            currentDirectory: homeDirectory
        )
        guard let result, result.exitCode == 0 else { return nil }
        return VersionParser.parse(result.combinedOutput)
    }

    private func cleanupTemporaryInstaller(at scriptURL: URL) {
        let parent = scriptURL.deletingLastPathComponent().standardizedFileURL
        let temporaryRoot = fileManager.temporaryDirectory.standardizedFileURL
        guard parent.path.hasPrefix(temporaryRoot.path + "/"),
              parent.lastPathComponent.hasPrefix("codex-installer-") else {
            return
        }
        try? fileManager.removeItem(at: parent)
    }

    private static func safeMessage(from result: ProcessResult) -> String {
        let message = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty { return "命令没有返回可用的诊断信息。" }
        return String(message.suffix(4_000))
    }
}
