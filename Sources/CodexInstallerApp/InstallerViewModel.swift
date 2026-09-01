import CodexInstallerCore
import Foundation

@MainActor
final class InstallerViewModel: ObservableObject {
    @Published private(set) var phase: InstallerPhase = .idle
    @Published private(set) var inspection = InstallationInspection(
        manager: nil,
        executableURL: nil,
        version: nil
    )
    @Published private(set) var installedVersion: String?
    @Published private(set) var diagnosticLog = ""
    @Published private(set) var errorMessage: String?

    private let installerService: CodexInstallerService
    private let authService: CodexAuthService
    private var activeExecutableURL: URL?

    init(
        installerService: CodexInstallerService = CodexInstallerService(),
        authService: CodexAuthService = CodexAuthService()
    ) {
        self.installerService = installerService
        self.authService = authService
    }

    var isBusy: Bool {
        [.inspecting, .downloading, .installing, .verifying, .signingIn].contains(phase)
    }

    var activeExecutablePath: String? { activeExecutableURL?.path }

    var primaryButtonTitle: String {
        if inspection.manager == .standalone { return "更新 Codex 并登录" }
        if inspection.isInstalled { return "使用现有 Codex 并登录" }
        return "安装 Codex 并登录"
    }

    var statusTitle: String {
        switch phase {
        case .idle: return "准备开始"
        case .inspecting: return "正在检查电脑环境…"
        case .ready:
            if let manager = inspection.manager {
                return "检测到 \(manager.displayName)"
            }
            return "可以安装 Codex"
        case .downloading: return "正在从 OpenAI 下载官方安装脚本…"
        case .installing: return "正在安装 Codex CLI…"
        case .verifying: return "正在验证安装结果…"
        case .awaitingLogin: return "需要登录 ChatGPT"
        case .signingIn: return "请在浏览器中完成登录…"
        case .complete: return "Codex 已准备好"
        case .failed: return "操作没有完成"
        }
    }

    var statusDetail: String {
        switch phase {
        case .idle: return "安装器只使用 OpenAI 官方下载与登录流程。"
        case .inspecting: return "正在检查已有版本和安装来源。"
        case .ready:
            if let manager = inspection.manager, !manager.isManagedByHelper {
                return "安装助手不会覆盖或卸载由 \(manager.displayName) 管理的版本。"
            }
            return "点击下方按钮后才会联网并修改用户目录。"
        case .downloading: return "只允许 chatgpt.com 与 releases.openai.com 的精确官方安装端点。"
        case .installing: return "安装位置为 ~/.local/bin，通常不需要管理员权限。"
        case .verifying: return "通过运行 codex --version 确认可执行文件有效。"
        case .awaitingLogin: return "登录由 Codex 官方流程处理，本应用不接触账号凭据。"
        case .signingIn: return "登录窗口可能位于浏览器中，请不要关闭本应用。"
        case .complete:
            return installedVersion.map { "已验证 Codex CLI \($0)，并确认登录状态。" }
                ?? "安装与登录均已验证。"
        case .failed: return errorMessage ?? "请展开诊断信息后重试。"
        }
    }

    func prepare() {
        guard phase == .idle || phase == .failed || phase == .complete else { return }
        Task { await inspectEnvironment() }
    }

    func installOrContinue() {
        guard phase == .ready else { return }
        Task {
            errorMessage = nil
            if inspection.canInstallOrUpdate {
                await installStandalone()
            } else if let executableURL = inspection.executableURL {
                await verifyAndAuthenticate(executableURL: executableURL, beginsAtReady: true)
            }
        }
    }

    func retryBrowserLogin() {
        guard phase == .awaitingLogin, let executableURL = activeExecutableURL else { return }
        Task { await signIn(executableURL: executableURL) }
    }

    func checkLoginStatus() {
        guard phase == .awaitingLogin, let executableURL = activeExecutableURL else { return }
        Task {
            move(to: .signingIn)
            let status = await authService.loginStatus(executableURL: executableURL)
            appendCommandOutput(status.result)
            if status.isLoggedIn {
                errorMessage = nil
                appendLog("登录状态验证成功")
                move(to: .complete)
            } else {
                errorMessage = "尚未检测到登录状态。请先在终端完成设备登录。"
                move(to: .awaitingLogin)
            }
        }
    }

    private func inspectEnvironment() async {
        move(to: .inspecting)
        appendLog("开始环境检查")
        inspection = await installerService.inspect()
        activeExecutableURL = inspection.executableURL
        if let executableURL = inspection.executableURL {
            appendLog("检测到 Codex：\(executableURL.path)")
            if let version = inspection.version { appendLog("当前版本：\(version)") }
            if let manager = inspection.manager { appendLog("安装来源：\(manager.displayName)") }
        } else {
            appendLog("未检测到现有 Codex")
        }
        move(to: .ready)
    }

    private func installStandalone() async {
        do {
            move(to: .downloading)
            let scriptURL = try await installerService.downloadOfficialInstaller()
            appendLog("官方脚本已下载并通过来源与内容检查")

            move(to: .installing)
            let result = try await installerService.runOfficialInstaller(at: scriptURL)
            appendCommandOutput(result)

            move(to: .verifying)
            let executableURL = installerService.standaloneExecutableURL
            let version = try await installerService.verifyCodex(at: executableURL)
            activeExecutableURL = executableURL
            installedVersion = version
            appendLog("安装验证成功：Codex CLI \(version)")
            await authenticateAfterVerification(executableURL: executableURL)
        } catch {
            fail(error)
        }
    }

    private func verifyAndAuthenticate(executableURL: URL, beginsAtReady: Bool) async {
        do {
            if beginsAtReady { move(to: .verifying) }
            let version = try await installerService.verifyCodex(at: executableURL)
            installedVersion = version
            activeExecutableURL = executableURL
            appendLog("现有安装验证成功：Codex CLI \(version)")
            await authenticateAfterVerification(executableURL: executableURL)
        } catch {
            fail(error)
        }
    }

    private func authenticateAfterVerification(executableURL: URL) async {
        let status = await authService.loginStatus(executableURL: executableURL)
        appendCommandOutput(status.result)
        if status.isLoggedIn {
            appendLog("Codex 已处于登录状态")
            move(to: .complete)
            return
        }
        move(to: .awaitingLogin)
        await signIn(executableURL: executableURL)
    }

    private func signIn(executableURL: URL) async {
        move(to: .signingIn)
        appendLog("启动 ChatGPT 浏览器登录流程")
        do {
            let loginResult = try await authService.login(
                executableURL: executableURL,
                useDeviceAuth: false
            )
            appendCommandOutput(loginResult)
            let status = await authService.loginStatus(executableURL: executableURL)
            appendCommandOutput(status.result)
            if status.isLoggedIn {
                appendLog("登录状态验证成功")
                move(to: .complete)
            } else {
                errorMessage = "登录尚未完成。可以重试浏览器登录或改用设备登录。"
                move(to: .awaitingLogin)
            }
        } catch {
            errorMessage = error.localizedDescription
            appendLog("登录未完成：\(error.localizedDescription)")
            move(to: .awaitingLogin)
        }
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        appendLog("失败：\(error.localizedDescription)")
        move(to: .failed)
    }

    private func move(to next: InstallerPhase) {
        guard phase.allowsTransition(to: next) else {
            appendLog("忽略无效状态转换：\(phase.rawValue) → \(next.rawValue)")
            return
        }
        phase = next
    }

    private func appendCommandOutput(_ result: ProcessResult) {
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return }
        appendLog(String(output.suffix(8_000)))
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        diagnosticLog = diagnosticLog.isEmpty ? line : diagnosticLog + "\n" + line
    }
}
