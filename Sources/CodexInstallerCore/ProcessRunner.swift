import Foundation

public protocol ProcessRunning: Sendable {
    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessResult
}

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory

            var mergedEnvironment = ProcessInfo.processInfo.environment
            environment.forEach { mergedEnvironment[$0.key] = $0.value }
            process.environment = mergedEnvironment

            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("codex-installer-process-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            let stdoutURL = temporaryDirectory.appendingPathComponent("stdout.log")
            let stderrURL = temporaryDirectory.appendingPathComponent("stderr.log")
            FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
            }
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            try process.run()
            process.waitUntilExit()
            try stdoutHandle.synchronize()
            try stderrHandle.synchronize()

            let stdout = String(decoding: (try? Data(contentsOf: stdoutURL)) ?? Data(), as: UTF8.self)
            let stderr = String(decoding: (try? Data(contentsOf: stderrURL)) ?? Data(), as: UTF8.self)
            return ProcessResult(
                exitCode: process.terminationStatus,
                standardOutput: stdout,
                standardError: stderr
            )
        }.value
    }
}
