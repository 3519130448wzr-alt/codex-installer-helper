using System.Diagnostics;
using CodexInstaller.Core;

namespace CodexInstaller.Windows;

public sealed class MainForm : Form
{
    private readonly CodexInstallerService _installer = new();
    private readonly OfficialInstallerDownloader _downloader = new();
    private readonly CancellationTokenSource _lifetime = new();
    private readonly CodexAuthService _auth;

    private readonly Label _stepLabel = new();
    private readonly Label _statusLabel = new();
    private readonly Label _detailLabel = new();
    private readonly Label _resultLabel = new();
    private readonly ProgressBar _progress = new();
    private readonly Button _primaryButton = new();
    private readonly Button _copyMigrationButton = new();
    private readonly Button _browserLoginButton = new();
    private readonly Button _deviceLoginButton = new();
    private readonly Button _checkLoginButton = new();
    private readonly Button _openTerminalButton = new();
    private readonly Button _copyCommandButton = new();
    private readonly RichTextBox _diagnostics = new();

    private InstallerPhase _phase = InstallerPhase.Idle;
    private InstallationInspection _inspection = new(null, null, null);
    private string? _activeExecutablePath;
    private string? _installedVersion;
    private string? _errorMessage;

    public MainForm()
    {
        _auth = new CodexAuthService(_installer);
        Text = "Codex 安装助手（非官方）";
        MinimumSize = new Size(720, 650);
        Size = new Size(820, 720);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(247, 248, 250);
        Font = new Font("Microsoft YaHei UI", 9F);
        BuildInterface();
        Shown += async (_, _) => await InspectAsync();
        FormClosing += (_, _) => _lifetime.Cancel();
    }

    private void BuildInterface()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(30, 24, 30, 24),
            ColumnCount = 1,
            RowCount = 8,
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var title = new Label
        {
            AutoSize = true,
            Text = "Codex 安装助手",
            Font = new Font(Font.FontFamily, 22F, FontStyle.Bold),
            ForeColor = Color.FromArgb(28, 32, 39),
            Margin = new Padding(0, 0, 0, 4),
        };
        var disclaimer = new Label
        {
            AutoSize = true,
            Text = "非 OpenAI 官方产品 · 仅调用 OpenAI 官方安装与 ChatGPT 登录流程",
            ForeColor = Color.FromArgb(91, 99, 113),
            Margin = new Padding(0, 0, 0, 22),
        };

        _stepLabel.AutoSize = true;
        _stepLabel.ForeColor = Color.FromArgb(80, 86, 99);
        _stepLabel.Margin = new Padding(0, 0, 0, 7);
        _statusLabel.AutoSize = true;
        _statusLabel.Font = new Font(Font.FontFamily, 15F, FontStyle.Bold);
        _statusLabel.ForeColor = Color.FromArgb(28, 32, 39);
        _statusLabel.Margin = new Padding(0, 0, 0, 7);
        _detailLabel.AutoSize = true;
        _detailLabel.MaximumSize = new Size(720, 0);
        _detailLabel.ForeColor = Color.FromArgb(75, 82, 94);
        _detailLabel.Margin = new Padding(0, 0, 0, 15);

        _progress.Dock = DockStyle.Top;
        _progress.Style = ProgressBarStyle.Marquee;
        _progress.MarqueeAnimationSpeed = 35;
        _progress.Height = 5;
        _progress.Margin = new Padding(0, 0, 0, 16);

        var actions = new FlowLayoutPanel
        {
            AutoSize = true,
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            Margin = new Padding(0, 0, 0, 12),
        };
        ConfigureButton(_primaryButton, true);
        ConfigureButton(_copyMigrationButton, false);
        ConfigureButton(_browserLoginButton, false);
        ConfigureButton(_deviceLoginButton, false);
        ConfigureButton(_checkLoginButton, false);
        ConfigureButton(_openTerminalButton, false);
        ConfigureButton(_copyCommandButton, false);
        _primaryButton.Click += async (_, _) => await PrimaryActionAsync();
        _copyMigrationButton.Click += (_, _) => CopyMigrationInstructions();
        _browserLoginButton.Click += async (_, _) => await BrowserLoginAsync();
        _deviceLoginButton.Click += (_, _) => StartDeviceLogin();
        _checkLoginButton.Click += async (_, _) => await CheckLoginStatusAsync();
        _openTerminalButton.Click += (_, _) => OpenTerminal();
        _copyCommandButton.Click += (_, _) => CopyCommand();
        actions.Controls.AddRange([
            _primaryButton,
            _copyMigrationButton,
            _browserLoginButton,
            _deviceLoginButton,
            _checkLoginButton,
            _openTerminalButton,
            _copyCommandButton,
        ]);

        _resultLabel.AutoSize = true;
        _resultLabel.ForeColor = Color.FromArgb(45, 105, 68);
        _resultLabel.Margin = new Padding(0, 0, 0, 10);

        var diagnosticsGroup = new GroupBox
        {
            Text = "本地诊断信息（不会上传）",
            Dock = DockStyle.Fill,
            Padding = new Padding(12),
            ForeColor = Color.FromArgb(60, 66, 76),
        };
        _diagnostics.Dock = DockStyle.Fill;
        _diagnostics.ReadOnly = true;
        _diagnostics.BackColor = Color.FromArgb(252, 252, 253);
        _diagnostics.BorderStyle = BorderStyle.None;
        _diagnostics.Font = new Font("Consolas", 9F);
        diagnosticsGroup.Controls.Add(_diagnostics);

        var privacy = new Label
        {
            AutoSize = true,
            Text = "不需要管理员权限 · 不保存密码、Token 或 API Key · 不包含 Codex 二进制",
            ForeColor = Color.FromArgb(98, 104, 116),
            Margin = new Padding(0, 12, 0, 0),
        };

        root.Controls.Add(title);
        root.Controls.Add(disclaimer);
        root.Controls.Add(_stepLabel);
        root.Controls.Add(_statusLabel);
        root.Controls.Add(_detailLabel);
        root.Controls.Add(_progress);
        var content = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
        content.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        content.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        content.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        content.Controls.Add(actions);
        content.Controls.Add(_resultLabel);
        content.Controls.Add(diagnosticsGroup);
        root.Controls.Add(content);
        root.Controls.Add(privacy);
        Controls.Add(root);
        Render();
    }

    private static void ConfigureButton(Button button, bool primary)
    {
        button.AutoSize = true;
        button.Padding = new Padding(12, 7, 12, 7);
        button.Margin = new Padding(0, 0, 9, 8);
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = primary ? 0 : 1;
        button.BackColor = primary ? Color.FromArgb(38, 87, 235) : Color.White;
        button.ForeColor = primary ? Color.White : Color.FromArgb(43, 50, 62);
        button.Cursor = Cursors.Hand;
    }

    private async Task InspectAsync()
    {
        try
        {
            MoveTo(InstallerPhase.Inspecting);
            Log("开始检查 Windows 环境和已有 Codex");
            _inspection = await _installer.InspectAsync(_lifetime.Token);
            _activeExecutablePath = _inspection.ExecutablePath;
            if (_inspection.IsInstalled)
            {
                Log($"检测到 Codex：{_inspection.ExecutablePath}");
                Log($"安装来源：{_inspection.Manager?.DisplayName()}");
                if (_inspection.Version is not null) Log($"当前版本：{_inspection.Version}");
            }
            else
            {
                Log("未检测到现有 Codex");
            }
            MoveTo(InstallerPhase.Ready);
        }
        catch (OperationCanceledException) { }
        catch (Exception error) { Fail(error); }
    }

    private async Task PrimaryActionAsync()
    {
        if (_phase == InstallerPhase.Failed)
        {
            await InspectAsync();
            return;
        }
        if (_phase != InstallerPhase.Ready) return;

        try
        {
            _errorMessage = null;
            if (_inspection.CanInstallOrUpdate)
            {
                MoveTo(InstallerPhase.Downloading);
                await using var downloaded = await _downloader.DownloadAsync(_lifetime.Token);
                Log("官方脚本已下载，最终域名与内容信号检查通过");
                MoveTo(InstallerPhase.Installing);
                var result = await _installer.RunOfficialInstallerAsync(downloaded.ScriptPath, _lifetime.Token);
                LogInstallerOutput(result);
                _activeExecutablePath = _installer.StandaloneExecutablePath;
            }

            if (_activeExecutablePath is null)
            {
                throw new InstallerFailure(InstallerFailureKind.VerificationFailed, "没有可验证的 Codex 路径。");
            }
            MoveTo(InstallerPhase.Verifying);
            _installedVersion = await _installer.VerifyCodexAsync(_activeExecutablePath, _lifetime.Token);
            Log($"版本验证成功：Codex CLI {_installedVersion}");
            await AuthenticateAfterVerificationAsync();
        }
        catch (OperationCanceledException) { }
        catch (Exception error) { Fail(error); }
    }

    private async Task AuthenticateAfterVerificationAsync()
    {
        if (_activeExecutablePath is null) return;
        var status = await _auth.GetLoginStatusAsync(_activeExecutablePath, _lifetime.Token);
        if (status.IsLoggedIn)
        {
            Log("ChatGPT 登录状态验证成功");
            MoveTo(InstallerPhase.Complete);
            return;
        }
        MoveTo(InstallerPhase.AwaitingLogin);
        await BrowserLoginAsync();
    }

    private async Task BrowserLoginAsync()
    {
        if (_phase != InstallerPhase.AwaitingLogin || _activeExecutablePath is null) return;
        try
        {
            MoveTo(InstallerPhase.SigningIn);
            Log("已启动 Codex 自身的 ChatGPT 浏览器登录流程");
            await _auth.LoginAsync(_activeExecutablePath, _lifetime.Token);
            var status = await _auth.GetLoginStatusAsync(_activeExecutablePath, _lifetime.Token);
            if (status.IsLoggedIn)
            {
                Log("ChatGPT 登录状态验证成功");
                MoveTo(InstallerPhase.Complete);
            }
            else
            {
                _errorMessage = "尚未检测到登录状态；可以重试或使用设备登录。";
                MoveTo(InstallerPhase.AwaitingLogin);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception error)
        {
            _errorMessage = error.Message;
            Log($"浏览器登录未完成：{error.Message}");
            MoveTo(InstallerPhase.AwaitingLogin);
        }
    }

    private void StartDeviceLogin()
    {
        if (_phase != InstallerPhase.AwaitingLogin || _activeExecutablePath is null) return;
        try
        {
            _auth.StartDeviceLogin(_activeExecutablePath);
            Log("已在独立终端启动设备登录；本应用不会读取设备码");
        }
        catch (Exception error)
        {
            _errorMessage = $"无法打开设备登录终端：{error.Message}";
            Log(_errorMessage);
            Render();
        }
    }

    private async Task CheckLoginStatusAsync()
    {
        if (_phase != InstallerPhase.AwaitingLogin || _activeExecutablePath is null) return;
        try
        {
            MoveTo(InstallerPhase.SigningIn);
            var status = await _auth.GetLoginStatusAsync(_activeExecutablePath, _lifetime.Token);
            if (status.IsLoggedIn)
            {
                Log("ChatGPT 登录状态验证成功");
                MoveTo(InstallerPhase.Complete);
            }
            else
            {
                _errorMessage = "仍未检测到登录状态，请先在浏览器或终端完成登录。";
                MoveTo(InstallerPhase.AwaitingLogin);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception error) { Fail(error); }
    }

    private void OpenTerminal()
    {
        try
        {
            var terminal = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Microsoft", "WindowsApps", "wt.exe");
            var startInfo = new ProcessStartInfo
            {
                FileName = File.Exists(terminal) ? terminal : "cmd.exe",
                UseShellExecute = false,
                CreateNoWindow = false,
                WorkingDirectory = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            };
            if (_activeExecutablePath is not null)
            {
                var binDirectory = Path.GetDirectoryName(_activeExecutablePath);
                if (!string.IsNullOrWhiteSpace(binDirectory))
                {
                    startInfo.Environment["PATH"] = binDirectory + Path.PathSeparator +
                        (Environment.GetEnvironmentVariable("PATH") ?? string.Empty);
                }
            }
            Process.Start(startInfo);
        }
        catch (Exception error)
        {
            MessageBox.Show(this, error.Message, "无法打开终端", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void CopyCommand()
    {
        Clipboard.SetText("codex");
        _resultLabel.Text = "已复制命令：codex";
    }

    private void CopyMigrationInstructions()
    {
        var instructions = _inspection.Manager switch
        {
            InstallationManager.Npm => "如需迁移到 OpenAI 官方 standalone：先关闭安装助手，在终端运行 npm uninstall -g @openai/codex；确认 codex 命令已移除后，重新打开安装助手。迁移前请先了解卸载操作的影响。",
            InstallationManager.Bun => "如需迁移到 OpenAI 官方 standalone：先关闭安装助手，在终端运行 bun remove -g @openai/codex；确认 codex 命令已移除后，重新打开安装助手。迁移前请先了解卸载操作的影响。",
            _ => "检测到未知来源的 Codex。请先查明它由哪个工具安装，并按该工具的官方说明自行卸载；确认 codex 命令已移除后，再重新打开安装助手。安装助手不会代为删除。",
        };
        Clipboard.SetText(instructions);
        _resultLabel.Text = "已复制迁移说明；安装助手没有执行卸载。";
    }

    private void Fail(Exception error)
    {
        _errorMessage = error.Message;
        Log($"失败：{error.Message}");
        MoveTo(InstallerPhase.Failed);
    }

    private void MoveTo(InstallerPhase next)
    {
        if (!InstallerStateMachine.Allows(_phase, next))
        {
            Log($"忽略无效状态转换：{_phase} → {next}");
            return;
        }
        _phase = next;
        Render();
    }

    private void Render()
    {
        var busy = _phase is InstallerPhase.Inspecting or InstallerPhase.Downloading or InstallerPhase.Installing or InstallerPhase.Verifying or InstallerPhase.SigningIn;
        _stepLabel.Text = $"步骤 {PhaseNumber(_phase)} / 7";
        _statusLabel.Text = StatusTitle();
        _detailLabel.Text = StatusDetail();
        _progress.Visible = busy;

        _primaryButton.Visible = _phase is InstallerPhase.Ready or InstallerPhase.Failed;
        _primaryButton.Enabled = !busy;
        _primaryButton.Text = _phase == InstallerPhase.Failed
            ? "重新检查"
            : _inspection.Manager == InstallationManager.Standalone
                ? "更新 Codex 并登录"
                : _inspection.IsInstalled
                    ? "使用现有 Codex 并登录"
                    : "安装 Codex 并登录";
        _copyMigrationButton.Visible = _phase == InstallerPhase.Ready &&
            _inspection.Manager is not null &&
            !_inspection.Manager.Value.IsManagedByHelper();
        _copyMigrationButton.Text = "复制迁移说明";
        _browserLoginButton.Visible = _phase == InstallerPhase.AwaitingLogin;
        _browserLoginButton.Text = "重试浏览器登录";
        _deviceLoginButton.Visible = _phase == InstallerPhase.AwaitingLogin;
        _deviceLoginButton.Text = "使用设备登录";
        _checkLoginButton.Visible = _phase == InstallerPhase.AwaitingLogin;
        _checkLoginButton.Text = "检查登录状态";
        _openTerminalButton.Visible = _phase == InstallerPhase.Complete;
        _openTerminalButton.Text = "打开终端";
        _copyCommandButton.Visible = _phase == InstallerPhase.Complete;
        _copyCommandButton.Text = "复制 codex 命令";
        _resultLabel.Text = _phase == InstallerPhase.Complete
            ? $"安装路径：{_activeExecutablePath}\r\n已验证版本：{_installedVersion ?? "未知"}"
            : string.Empty;
    }

    private string StatusTitle() => _phase switch
    {
        InstallerPhase.Idle => "准备开始",
        InstallerPhase.Inspecting => "正在检查电脑环境…",
        InstallerPhase.Ready when _inspection.Manager is not null => $"检测到 {_inspection.Manager.Value.DisplayName()}",
        InstallerPhase.Ready => "可以安装 Codex",
        InstallerPhase.Downloading => "正在下载 OpenAI 官方安装脚本…",
        InstallerPhase.Installing => "正在安装 Codex CLI…",
        InstallerPhase.Verifying => "正在验证安装结果…",
        InstallerPhase.AwaitingLogin => "需要登录 ChatGPT",
        InstallerPhase.SigningIn => "请在浏览器中完成登录…",
        InstallerPhase.Complete => "Codex 已准备好",
        InstallerPhase.Failed => "操作没有完成",
        _ => "准备开始",
    };

    private string StatusDetail() => _phase switch
    {
        InstallerPhase.Idle => "安装器只使用 OpenAI 官方下载与登录流程。",
        InstallerPhase.Inspecting => "正在检查已有版本、安装来源与可执行路径。",
        InstallerPhase.Ready when _inspection.Manager is not null && !_inspection.Manager.Value.IsManagedByHelper() =>
            $"安装助手不会覆盖或卸载由 {_inspection.Manager.Value.DisplayName()} 管理的版本。",
        InstallerPhase.Ready => "点击按钮后才会联网并修改当前用户目录。",
        InstallerPhase.Downloading => "只允许 chatgpt.com 与 releases.openai.com 的精确官方脚本端点。",
        InstallerPhase.Installing => "安装到当前用户目录，不会请求管理员权限。",
        InstallerPhase.Verifying => "通过直接运行 codex --version 确认可执行文件有效。",
        InstallerPhase.AwaitingLogin => _errorMessage ?? "登录由 Codex 官方流程处理，本应用不接触账号凭据。",
        InstallerPhase.SigningIn => "浏览器窗口可能位于本应用后方，请完成 ChatGPT 账号确认。",
        InstallerPhase.Complete => $"已验证 Codex CLI {_installedVersion ?? ""} 和 ChatGPT 登录状态。",
        InstallerPhase.Failed => _errorMessage ?? "请查看本地诊断信息后重试。",
        _ => string.Empty,
    };

    private static int PhaseNumber(InstallerPhase phase) => phase switch
    {
        InstallerPhase.Idle or InstallerPhase.Inspecting => 1,
        InstallerPhase.Ready => 2,
        InstallerPhase.Downloading => 3,
        InstallerPhase.Installing => 4,
        InstallerPhase.Verifying => 5,
        InstallerPhase.AwaitingLogin or InstallerPhase.SigningIn => 6,
        InstallerPhase.Complete => 7,
        InstallerPhase.Failed => 1,
        _ => 1,
    };

    private void LogInstallerOutput(ProcessResult result)
    {
        var output = result.CombinedOutput.Trim();
        if (output.Length == 0) return;
        Log(output.Length <= 8_000 ? output : output[^8_000..]);
    }

    private void Log(string message)
    {
        var line = $"[{DateTime.Now:HH:mm:ss}] {message}";
        _diagnostics.AppendText((_diagnostics.TextLength == 0 ? "" : Environment.NewLine) + line);
        _diagnostics.SelectionStart = _diagnostics.TextLength;
        _diagnostics.ScrollToCaret();
    }
}
