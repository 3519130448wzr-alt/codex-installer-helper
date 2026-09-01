using System.Net;
using System.Text;

namespace CodexInstaller.Core;

public sealed class DownloadedInstaller : IAsyncDisposable
{
    public string ScriptPath { get; }
    private readonly string _temporaryDirectory;

    internal DownloadedInstaller(string scriptPath, string temporaryDirectory)
    {
        ScriptPath = scriptPath;
        _temporaryDirectory = temporaryDirectory;
    }

    public ValueTask DisposeAsync()
    {
        var tempRoot = Path.GetFullPath(Path.GetTempPath());
        var target = Path.GetFullPath(_temporaryDirectory);
        if (target.StartsWith(tempRoot, StringComparison.OrdinalIgnoreCase) &&
            Path.GetFileName(target).StartsWith("codex-installer-download-", StringComparison.Ordinal))
        {
            try { Directory.Delete(target, recursive: true); } catch { }
        }

        return ValueTask.CompletedTask;
    }
}

public sealed class OfficialInstallerDownloader
{
    public static readonly Uri EntryUri = new("https://chatgpt.com/codex/install.ps1");
    public static readonly Uri RedirectUri = new("https://releases.openai.com/codex/install.ps1");
    public const int MaximumScriptBytes = 4 * 1024 * 1024;

    private readonly HttpClient _client;

    public OfficialInstallerDownloader(HttpClient? client = null)
    {
        _client = client ?? new HttpClient(new HttpClientHandler
        {
            AllowAutoRedirect = true,
            MaxAutomaticRedirections = 4,
            AutomaticDecompression = DecompressionMethods.All,
        });
        _client.Timeout = TimeSpan.FromSeconds(45);
    }

    public async Task<DownloadedInstaller> DownloadAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            using var response = await _client.GetAsync(
                EntryUri,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            response.EnsureSuccessStatusCode();

            var finalUri = response.RequestMessage?.RequestUri;
            if (finalUri is null || !IsAllowedFinalUri(finalUri))
            {
                throw new InstallerFailure(
                    InstallerFailureKind.InvalidDownloadUrl,
                    "官方安装脚本的最终下载地址未通过安全检查。");
            }

            if (response.Content.Headers.ContentLength > MaximumScriptBytes)
            {
                throw new InstallerFailure(
                    InstallerFailureKind.InvalidInstallerScript,
                    "下载的安装脚本大小异常。");
            }

            await using var source = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var buffer = new MemoryStream();
            var chunk = new byte[32 * 1024];
            while (true)
            {
                var read = await source.ReadAsync(chunk, cancellationToken);
                if (read == 0) break;
                if (buffer.Length + read > MaximumScriptBytes)
                {
                    throw new InstallerFailure(
                        InstallerFailureKind.InvalidInstallerScript,
                        "下载的安装脚本大小异常。");
                }
                await buffer.WriteAsync(chunk.AsMemory(0, read), cancellationToken);
            }

            var script = new UTF8Encoding(false, true).GetString(buffer.ToArray());
            if (!IsValidScript(script))
            {
                throw new InstallerFailure(
                    InstallerFailureKind.InvalidInstallerScript,
                    "下载内容不是可识别的 OpenAI Codex 官方安装脚本。");
            }

            var directory = Path.Combine(Path.GetTempPath(), $"codex-installer-download-{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            var scriptPath = Path.Combine(directory, "install.ps1");
            await File.WriteAllTextAsync(scriptPath, script, new UTF8Encoding(false), cancellationToken);
            return new DownloadedInstaller(scriptPath, directory);
        }
        catch (InstallerFailure)
        {
            throw;
        }
        catch (Exception error) when (error is not OperationCanceledException)
        {
            throw new InstallerFailure(
                InstallerFailureKind.DownloadFailed,
                $"无法下载 OpenAI 官方安装脚本：{error.Message}",
                inner: error);
        }
    }

    public static bool IsAllowedFinalUri(Uri uri) =>
        uri.Scheme == Uri.UriSchemeHttps &&
        (uri == EntryUri || uri == RedirectUri);

    public static bool IsValidScript(string script)
    {
        string[] requiredSignals =
        [
            "[CmdletBinding()]",
            "CODEX_NON_INTERACTIVE",
            "CODEX_INSTALL_DIR",
            "https://releases.openai.com/codex",
            "Get-FileHash",
            "codex.exe",
        ];
        return script.Length is > 1_000 and <= MaximumScriptBytes &&
               requiredSignals.All(signal => script.Contains(signal, StringComparison.OrdinalIgnoreCase));
    }
}
