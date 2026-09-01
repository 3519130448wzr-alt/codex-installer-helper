import Foundation

public final class CodexAuthService: @unchecked Sendable {
    private let runner: any ProcessRunning
    private let homeDirectory: URL

    public init(
        runner: any ProcessRunning = FoundationProcessRunner(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.runner = runner
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func loginStatus(executableURL: URL) async -> (isLoggedIn: Bool, result: ProcessResult) {
        do {
            let result = try await run(executableURL: executableURL, arguments: ["login", "status"])
            return (result.exitCode == 0, result)
        } catch {
            return (
                false,
                ProcessResult(exitCode: -1, standardError: error.localizedDescription)
            )
        }
    }

    public func login(executableURL: URL, useDeviceAuth: Bool = false) async throws -> ProcessResult {
        var arguments = ["login"]
        if useDeviceAuth { arguments.append("--device-auth") }
        let result = try await run(executableURL: executableURL, arguments: arguments)
        guard result.exitCode == 0 else {
            throw InstallerFailure.processFailed(
                command: useDeviceAuth ? "Codex 设备登录" : "Codex ChatGPT 登录",
                exitCode: result.exitCode,
                message: result.combinedOutput.isEmpty ? "登录被取消或未完成。" : result.combinedOutput
            )
        }
        return result
    }

    private func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        try await runner.run(
            executable: executableURL,
            arguments: arguments,
            environment: ["HOME": homeDirectory.path],
            currentDirectory: homeDirectory
        )
    }
}
