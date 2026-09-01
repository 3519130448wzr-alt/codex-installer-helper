using System.Net;
using System.Text;
using CodexInstaller.Core;

var tests = new (string Name, Func<Task> Run)[]
{
    ("版本解析", TestVersionParser),
    ("状态转换", TestStateMachine),
    ("官方最终地址限制", TestAllowedUris),
    ("官方脚本内容信号", TestScriptSignals),
    ("安装来源分类", TestInstallationClassification),
    ("受控下载成功", TestDownloaderSuccess),
    ("下载跳转到非官方域名时失败", TestDownloaderRejectsHost),
    ("临时 HOME 假安装脚本", TestFakeInstallerIntegration),
    ("CMD 版本验证", TestCmdVerification),
};

var failures = new List<string>();
var skipped = new List<string>();
foreach (var test in tests)
{
    try
    {
        await test.Run();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (TestSkipped error)
    {
        skipped.Add(test.Name);
        Console.WriteLine($"SKIP {test.Name}: {error.Message}");
    }
    catch (Exception error)
    {
        failures.Add($"FAIL {test.Name}: {error.Message}");
        Console.Error.WriteLine(failures[^1]);
    }
}

Console.WriteLine($"\n{tests.Length - failures.Count - skipped.Count} passed, {skipped.Count} skipped, {failures.Count} failed");
return failures.Count == 0 ? 0 : 1;

static Task TestVersionParser()
{
    Equal("0.98.0", VersionParser.Parse("codex-cli 0.98.0\r\n"));
    Equal("1.2.3-beta.1", VersionParser.Parse("codex 1.2.3-beta.1"));
    Equal<string?>(null, VersionParser.Parse("not a version"));
    return Task.CompletedTask;
}

static Task TestStateMachine()
{
    True(InstallerStateMachine.Allows(InstallerPhase.Idle, InstallerPhase.Inspecting));
    True(InstallerStateMachine.Allows(InstallerPhase.SigningIn, InstallerPhase.AwaitingLogin));
    False(InstallerStateMachine.Allows(InstallerPhase.Ready, InstallerPhase.Complete));
    False(InstallerStateMachine.Allows(InstallerPhase.Complete, InstallerPhase.Installing));
    return Task.CompletedTask;
}

static Task TestAllowedUris()
{
    True(OfficialInstallerDownloader.IsAllowedFinalUri(new Uri("https://chatgpt.com/codex/install.ps1")));
    True(OfficialInstallerDownloader.IsAllowedFinalUri(new Uri("https://releases.openai.com/codex/install.ps1")));
    False(OfficialInstallerDownloader.IsAllowedFinalUri(new Uri("http://releases.openai.com/codex/install.ps1")));
    False(OfficialInstallerDownloader.IsAllowedFinalUri(new Uri("https://releases.openai.com/codex/install.ps1?mirror=1")));
    False(OfficialInstallerDownloader.IsAllowedFinalUri(new Uri("https://example.com/install.ps1")));
    return Task.CompletedTask;
}

static Task TestScriptSignals()
{
    True(OfficialInstallerDownloader.IsValidScript(ValidScript()));
    False(OfficialInstallerDownloader.IsValidScript(ValidScript().Replace("Get-FileHash", "NoHash", StringComparison.Ordinal)));
    False(OfficialInstallerDownloader.IsValidScript("Write-Host 'short'"));
    return Task.CompletedTask;
}

static Task TestInstallationClassification()
{
    var root = Path.Combine(Path.GetTempPath(), "codex-classification-test");
    var standalone = Path.Combine(root, "Local", "Programs", "OpenAI", "Codex", "bin", "codex.exe");
    Equal(InstallationManager.Standalone, CodexInstallerService.ClassifyInstallation(standalone, standalone));
    Equal(InstallationManager.Npm, CodexInstallerService.ClassifyInstallation(Path.Combine(root, "AppData", "Roaming", "npm", "codex.cmd"), standalone));
    Equal(InstallationManager.Bun, CodexInstallerService.ClassifyInstallation(Path.Combine(root, ".bun", "bin", "codex.exe"), standalone));
    Equal(InstallationManager.Unknown, CodexInstallerService.ClassifyInstallation(Path.Combine(root, "tools", "codex.exe"), standalone));
    return Task.CompletedTask;
}

static async Task TestDownloaderSuccess()
{
    using var client = new HttpClient(new FakeHandler(
        new Uri("https://releases.openai.com/codex/install.ps1"),
        ValidScript()));
    var downloader = new OfficialInstallerDownloader(client);
    await using var download = await downloader.DownloadAsync();
    True(File.Exists(download.ScriptPath));
    True((await File.ReadAllTextAsync(download.ScriptPath)).Contains("Get-FileHash", StringComparison.Ordinal));
}

static async Task TestDownloaderRejectsHost()
{
    using var client = new HttpClient(new FakeHandler(new Uri("https://example.com/install.ps1"), ValidScript()));
    var downloader = new OfficialInstallerDownloader(client);
    var failure = await ThrowsAsync<InstallerFailure>(() => downloader.DownloadAsync());
    Equal(InstallerFailureKind.InvalidDownloadUrl, failure.Kind);
}

static async Task TestFakeInstallerIntegration()
{
    if (!OperatingSystem.IsWindows()) throw new TestSkipped("requires Windows PowerShell");
    var root = Path.Combine(Path.GetTempPath(), $"codex-installer-test-{Guid.NewGuid():N}");
    var profile = Path.Combine(root, "profile");
    var local = Path.Combine(profile, "AppData", "Local");
    Directory.CreateDirectory(local);
    try
    {
        var script = Path.Combine(root, "fake-install.ps1");
        await File.WriteAllTextAsync(script, """
            [CmdletBinding()]
            param()
            New-Item -ItemType Directory -Force -Path $env:CODEX_INSTALL_DIR | Out-Null
            Set-Content -LiteralPath (Join-Path $env:CODEX_INSTALL_DIR 'installer-marker.txt') -Value $env:CODEX_NON_INTERACTIVE
            exit 0
            """, new UTF8Encoding(false));
        var service = new CodexInstallerService(
            environment: new InstallerEnvironment(profile, local, string.Empty),
            powerShellPath: "powershell.exe");
        var result = await service.RunOfficialInstallerAsync(script);
        Equal(0, result.ExitCode);
        var marker = Path.Combine(local, "Programs", "OpenAI", "Codex", "bin", "installer-marker.txt");
        Equal("true", (await File.ReadAllTextAsync(marker)).Trim());
    }
    finally
    {
        try { Directory.Delete(root, recursive: true); } catch { }
    }
}

static async Task TestCmdVerification()
{
    if (!OperatingSystem.IsWindows()) throw new TestSkipped("requires cmd.exe");
    var root = Path.Combine(Path.GetTempPath(), $"codex-command-test-{Guid.NewGuid():N}");
    Directory.CreateDirectory(root);
    try
    {
        var command = Path.Combine(root, "codex.cmd");
        await File.WriteAllTextAsync(command, "@echo off\r\necho codex-cli 9.8.7\r\n", Encoding.ASCII);
        var service = new CodexInstallerService(
            environment: new InstallerEnvironment(root, root, root),
            powerShellPath: "powershell.exe");
        Equal("9.8.7", await service.VerifyCodexAsync(command));
    }
    finally
    {
        try { Directory.Delete(root, recursive: true); } catch { }
    }
}

static string ValidScript() => """
    [CmdletBinding()]
    param()
    $NonInteractive = $env:CODEX_NON_INTERACTIVE
    $InstallDirectory = $env:CODEX_INSTALL_DIR
    $ReleasesBaseUri = "https://releases.openai.com/codex"
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath "codex.exe"
    Write-Output "codex.exe"
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    # padding padding padding padding padding padding padding padding padding padding
    """;

static void True(bool value)
{
    if (!value) throw new InvalidOperationException("expected true");
}

static void False(bool value) => True(!value);

static void Equal<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"expected {expected}, got {actual}");
    }
}

static async Task<T> ThrowsAsync<T>(Func<Task> action) where T : Exception
{
    try
    {
        await action();
    }
    catch (T error)
    {
        return error;
    }
    throw new InvalidOperationException($"expected {typeof(T).Name}");
}

sealed class FakeHandler(Uri finalUri, string content) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var response = new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(content, Encoding.UTF8, "text/plain"),
            RequestMessage = new HttpRequestMessage(HttpMethod.Get, finalUri),
        };
        return Task.FromResult(response);
    }
}

sealed class TestSkipped(string message) : Exception(message);
