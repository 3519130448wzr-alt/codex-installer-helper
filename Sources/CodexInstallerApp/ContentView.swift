import AppKit
import CodexInstallerCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: InstallerViewModel
    @State private var showsDiagnostics = false
    @State private var deviceAuthStarted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusCard
                    installationDetails
                    privacyNotice
                    actionArea
                    diagnostics
                }
                .padding(28)
            }
        }
        .frame(minWidth: 680, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if viewModel.phase == .idle { viewModel.prepare() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.55, blue: 0.56), .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "terminal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex 安装助手")
                    .font(.title2.bold())
                Text("非 OpenAI 官方产品 · 仅连接 OpenAI 官方安装与登录服务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link("官方安装文档", destination: URL(string: "https://learn.chatgpt.com/docs/codex/cli")!)
                .font(.callout)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if viewModel.isBusy {
                    ProgressView().controlSize(.large)
                } else {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 30))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.statusTitle)
                    .font(.title3.bold())
                Text(viewModel.statusDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var installationDetails: some View {
        if viewModel.phase == .ready || viewModel.phase == .complete || viewModel.phase == .awaitingLogin {
            VStack(alignment: .leading, spacing: 10) {
                Text("安装信息").font(.headline)
                detailRow("安装方式", value: viewModel.inspection.manager?.displayName ?? "OpenAI 官方独立安装")
                if let path = viewModel.inspection.executableURL?.path {
                    detailRow("当前路径", value: path)
                } else {
                    detailRow("目标路径", value: "~/.local/bin/codex")
                }
                if let version = viewModel.installedVersion ?? viewModel.inspection.version {
                    detailRow("Codex 版本", value: version)
                }

                if let manager = viewModel.inspection.manager, !manager.isManagedByHelper {
                    Label(
                        "此版本由 \(manager.displayName) 管理。安装助手不会卸载、覆盖或新增另一套 Codex。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("安全与隐私", systemImage: "lock.shield")
                .font(.headline)
            Text("不包含 Codex 二进制，不使用第三方 API，不读取 ~/.codex/auth.json，不收集日志或遥测。安装下载与登录凭据均由 OpenAI 官方端点和 Codex 官方程序处理。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        HStack(spacing: 12) {
            switch viewModel.phase {
            case .ready:
                Button(viewModel.primaryButtonTitle) { viewModel.installOrContinue() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            case .awaitingLogin:
                Button("重试浏览器登录") { viewModel.retryBrowserLogin() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("在终端进行设备登录") { openDeviceAuthTerminal() }
                    .controlSize(.large)
                if deviceAuthStarted {
                    Button("检查登录状态") { viewModel.checkLoginStatus() }
                        .controlSize(.large)
                }
            case .failed:
                Button("重新检查") { viewModel.prepare() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            case .complete:
                Button("打开终端") { openTerminal() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("复制 codex 命令") { copyCodexCommand() }
                    .controlSize(.large)
                Button("重新检查") { viewModel.prepare() }
                    .controlSize(.large)
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    private var diagnostics: some View {
        DisclosureGroup("本地诊断信息", isExpanded: $showsDiagnostics) {
            ScrollView([.horizontal, .vertical]) {
                Text(viewModel.diagnosticLog.isEmpty ? "暂无诊断信息" : viewModel.diagnosticLog)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 110, maxHeight: 190)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 8)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
        }
        .font(.callout)
    }

    private var statusSymbol: String {
        switch viewModel.phase {
        case .complete: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .awaitingLogin: return "person.crop.circle.badge.questionmark"
        default: return "arrow.down.app.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.phase {
        case .complete: return .green
        case .failed: return .red
        case .awaitingLogin: return .blue
        default: return .accentColor
        }
    }

    private func copyCodexCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("codex", forType: .string)
    }

    private func openTerminal() {
        let candidates = [
            "/System/Applications/Utilities/Terminal.app",
            "/Applications/Utilities/Terminal.app",
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: configuration,
            completionHandler: nil
        )
    }

    private func openDeviceAuthTerminal() {
        guard let executablePath = viewModel.activeExecutablePath else { return }
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("codex-installer-device-auth-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let commandURL = directory.appendingPathComponent("Codex Device Login.command")
            let quotedExecutable = shellQuote(executablePath)
            let script = """
            #!/bin/zsh
            clear
            echo 'Codex 设备登录'
            echo '请按照下面的官方提示，在浏览器中输入设备验证码。'
            echo
            \(quotedExecutable) login --device-auth
            result=$?
            echo
            if [ "$result" -eq 0 ]; then
              echo '登录命令已完成。请回到 Codex 安装助手并点击“检查登录状态”。'
            else
              echo '登录没有完成。你可以关闭窗口后重试。'
            fi
            echo '按任意键关闭此窗口。'
            read -k 1
            script_path="$0"
            script_dir="${0:h}"
            rm -f -- "$script_path"
            rmdir "$script_dir" 2>/dev/null || true
            exit "$result"
            """
            try script.write(to: commandURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: commandURL.path)
            NSWorkspace.shared.open(commandURL)
            deviceAuthStarted = true
        } catch {
            deviceAuthStarted = false
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
