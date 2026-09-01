import Foundation

public enum InstallationManager: String, CaseIterable, Sendable {
    case standalone
    case homebrew
    case npm
    case bun
    case unknown

    public var displayName: String {
        switch self {
        case .standalone: return "OpenAI 官方独立安装"
        case .homebrew: return "Homebrew"
        case .npm: return "npm"
        case .bun: return "Bun"
        case .unknown: return "未知安装方式"
        }
    }

    public var isManagedByHelper: Bool { self == .standalone }
}

public struct InstallationInspection: Equatable, Sendable {
    public let manager: InstallationManager?
    public let executableURL: URL?
    public let version: String?

    public init(manager: InstallationManager?, executableURL: URL?, version: String?) {
        self.manager = manager
        self.executableURL = executableURL
        self.version = version
    }

    public var isInstalled: Bool { executableURL != nil }
    public var canInstallOrUpdate: Bool { manager == nil || manager == .standalone }
}

public enum InstallerPhase: String, CaseIterable, Sendable {
    case idle
    case inspecting
    case ready
    case downloading
    case installing
    case verifying
    case awaitingLogin
    case signingIn
    case complete
    case failed

    public func allowsTransition(to next: InstallerPhase) -> Bool {
        if self == next { return true }
        switch (self, next) {
        case (.idle, .inspecting),
             (.inspecting, .ready),
             (.inspecting, .failed),
             (.ready, .downloading),
             (.ready, .verifying),
             (.ready, .signingIn),
             (.downloading, .installing),
             (.downloading, .failed),
             (.installing, .verifying),
             (.installing, .failed),
             (.verifying, .awaitingLogin),
             (.verifying, .complete),
             (.verifying, .failed),
             (.awaitingLogin, .signingIn),
             (.signingIn, .complete),
             (.signingIn, .awaitingLogin),
             (.signingIn, .failed),
             (.failed, .inspecting),
             (.failed, .ready),
             (.failed, .awaitingLogin),
             (.complete, .inspecting):
            return true
        default:
            return false
        }
    }
}

public enum InstallerFailure: Error, Equatable, LocalizedError, Sendable {
    case unsupportedSystem(String)
    case invalidDownloadURL
    case invalidInstallerScript
    case downloadFailed(String)
    case processFailed(command: String, exitCode: Int32, message: String)
    case verificationFailed(String)
    case unmanagedInstallation(path: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSystem(message): return message
        case .invalidDownloadURL:
            return "官方安装脚本的下载地址未通过安全检查。"
        case .invalidInstallerScript:
            return "下载内容不是有效的 Codex 官方安装脚本。"
        case let .downloadFailed(message):
            return "无法下载官方安装脚本：\(message)"
        case let .processFailed(command, exitCode, message):
            return "\(command) 执行失败（退出码 \(exitCode)）：\(message)"
        case let .verificationFailed(message):
            return "Codex 安装验证失败：\(message)"
        case let .unmanagedInstallation(path):
            return "检测到由其他工具管理的 Codex：\(path)。安装助手不会覆盖或卸载它。"
        }
    }
}

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var combinedOutput: String {
        [standardOutput, standardError]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }
}

public enum VersionParser {
    public static func parse(_ output: String) -> String? {
        let pattern = #"(?:codex(?:-cli)?\s+)?([0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return String(output[valueRange])
    }
}
