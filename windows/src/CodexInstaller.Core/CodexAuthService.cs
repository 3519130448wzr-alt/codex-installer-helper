using System.Diagnostics;

namespace CodexInstaller.Core;

public sealed record LoginStatus(bool IsLoggedIn, ProcessResult Result);

public sealed class CodexAuthService
{
    private readonly CodexInstallerService _installer;

    public CodexAuthService(CodexInstallerService installer)
    {
        _installer = installer;
    }

    public async Task<LoginStatus> GetLoginStatusAsync(
        string executablePath,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _installer.RunCodexAsync(executablePath, ["login", "status"], cancellationToken);
            return new LoginStatus(result.ExitCode == 0, result);
        }
        catch (InstallerFailure error)
        {
            return new LoginStatus(error.ExitCode == 0, new ProcessResult(error.ExitCode ?? -1, StandardError: error.Message));
        }
    }

    public async Task<ProcessResult> LoginAsync(
        string executablePath,
        CancellationToken cancellationToken = default)
    {
        var result = await _installer.RunCodexAsync(executablePath, ["login"], cancellationToken);
        if (result.ExitCode != 0)
        {
            throw new InstallerFailure(
                InstallerFailureKind.ProcessFailed,
                $"ChatGPT 登录未完成（退出码 {result.ExitCode}）。",
                result.ExitCode);
        }
        return result;
    }

    public void StartDeviceLogin(string executablePath)
    {
        var command = $"\"{executablePath.Replace("\"", "\"\"")}\" login --device-auth";
        var startInfo = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            UseShellExecute = true,
        };
        startInfo.ArgumentList.Add("/D");
        startInfo.ArgumentList.Add("/K");
        startInfo.ArgumentList.Add(command);
        Process.Start(startInfo);
    }
}
