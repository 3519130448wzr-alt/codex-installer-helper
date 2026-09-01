namespace CodexInstaller.Core;

public sealed class CodexInstallerService
{
    private readonly IProcessRunner _runner;
    private readonly InstallerEnvironment _environment;
    private readonly string _powerShellPath;

    public CodexInstallerService(
        IProcessRunner? runner = null,
        InstallerEnvironment? environment = null,
        string? powerShellPath = null)
    {
        _runner = runner ?? new ProcessRunner();
        _environment = environment ?? InstallerEnvironment.Current;
        _powerShellPath = powerShellPath ?? ResolvePowerShellPath();
    }

    public string StandaloneExecutablePath => Path.Combine(
        _environment.LocalAppData,
        "Programs", "OpenAI", "Codex", "bin", "codex.exe");

    public string StandaloneBinDirectory => Path.GetDirectoryName(StandaloneExecutablePath)!;

    public async Task<InstallationInspection> InspectAsync(CancellationToken cancellationToken = default)
    {
        foreach (var candidate in CandidatePaths())
        {
            if (!File.Exists(candidate)) continue;
            var manager = ClassifyInstallation(candidate, StandaloneExecutablePath);
            var version = await TryGetVersionAsync(candidate, cancellationToken);
            return new InstallationInspection(manager, candidate, version);
        }

        return new InstallationInspection(null, null, null);
    }

    public async Task<ProcessResult> RunOfficialInstallerAsync(
        string scriptPath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(scriptPath))
        {
            throw new InstallerFailure(InstallerFailureKind.ProcessFailed, "找不到已下载的安装脚本。");
        }

        var result = await _runner.RunAsync(
            new ProcessRequest(
                _powerShellPath,
                ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", scriptPath],
                new Dictionary<string, string?>
                {
                    ["CODEX_NON_INTERACTIVE"] = "true",
                    ["CODEX_INSTALL_DIR"] = StandaloneBinDirectory,
                }),
            cancellationToken);

        if (result.ExitCode != 0)
        {
            throw new InstallerFailure(
                InstallerFailureKind.ProcessFailed,
                $"官方安装脚本执行失败（退出码 {result.ExitCode}）：{SafeTail(result.CombinedOutput)}",
                result.ExitCode);
        }

        return result;
    }

    public async Task<string> VerifyCodexAsync(string executablePath, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(executablePath))
        {
            throw new InstallerFailure(
                InstallerFailureKind.VerificationFailed,
                $"未找到 Codex 可执行文件：{executablePath}");
        }

        var result = await RunCodexAsync(executablePath, ["--version"], cancellationToken);
        var version = VersionParser.Parse(result.CombinedOutput);
        if (result.ExitCode != 0 || version is null)
        {
            throw new InstallerFailure(
                InstallerFailureKind.VerificationFailed,
                $"codex --version 未返回有效版本：{SafeTail(result.CombinedOutput)}",
                result.ExitCode);
        }
        return version;
    }

    public Task<ProcessResult> RunCodexAsync(
        string executablePath,
        IReadOnlyList<string> arguments,
        CancellationToken cancellationToken = default)
    {
        if (Path.GetExtension(executablePath).Equals(".cmd", StringComparison.OrdinalIgnoreCase))
        {
            var command = $"\"{executablePath.Replace("\"", "\"\"")}\" {string.Join(' ', arguments)}";
            return _runner.RunAsync(
                new ProcessRequest("cmd.exe", ["/D", "/S", "/C", command]),
                cancellationToken);
        }

        return _runner.RunAsync(new ProcessRequest(executablePath, arguments), cancellationToken);
    }

    public static InstallationManager ClassifyInstallation(string path, string standalonePath)
    {
        var normalized = Path.GetFullPath(path);
        var standalone = Path.GetFullPath(standalonePath);
        if (normalized.Equals(standalone, StringComparison.OrdinalIgnoreCase) ||
            normalized.Contains($"{Path.DirectorySeparatorChar}.codex{Path.DirectorySeparatorChar}packages{Path.DirectorySeparatorChar}standalone{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
        {
            return InstallationManager.Standalone;
        }
        if (normalized.Contains($"{Path.DirectorySeparatorChar}.bun{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
        {
            return InstallationManager.Bun;
        }
        if (normalized.EndsWith("codex.cmd", StringComparison.OrdinalIgnoreCase) ||
            normalized.Contains($"{Path.DirectorySeparatorChar}npm{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase) ||
            normalized.Contains($"{Path.DirectorySeparatorChar}node_modules{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
        {
            return InstallationManager.Npm;
        }
        return InstallationManager.Unknown;
    }

    private IEnumerable<string> CandidatePaths()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var segment in _environment.PathValue.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var directory = segment.Trim().Trim('"');
            if (string.IsNullOrWhiteSpace(directory)) continue;
            foreach (var name in new[] { "codex.exe", "codex.cmd" })
            {
                var path = Path.Combine(directory, name);
                if (seen.Add(path)) yield return path;
            }
        }

        foreach (var path in new[]
        {
            Path.Combine(_environment.UserProfile, "AppData", "Roaming", "npm", "codex.cmd"),
            Path.Combine(_environment.UserProfile, ".bun", "bin", "codex.exe"),
            Path.Combine(_environment.UserProfile, ".bun", "bin", "codex.cmd"),
            StandaloneExecutablePath,
        })
        {
            if (seen.Add(path)) yield return path;
        }
    }

    private async Task<string?> TryGetVersionAsync(string path, CancellationToken cancellationToken)
    {
        try
        {
            var result = await RunCodexAsync(path, ["--version"], cancellationToken);
            return result.ExitCode == 0 ? VersionParser.Parse(result.CombinedOutput) : null;
        }
        catch
        {
            return null;
        }
    }

    private static string ResolvePowerShellPath()
    {
        var system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        var candidate = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        return File.Exists(candidate) ? candidate : "powershell.exe";
    }

    private static string SafeTail(string value)
    {
        var trimmed = value.Trim();
        if (trimmed.Length == 0) return "未提供错误详情";
        return trimmed.Length <= 2_000 ? trimmed : trimmed[^2_000..];
    }
}
