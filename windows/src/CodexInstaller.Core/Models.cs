using System.Text.RegularExpressions;

namespace CodexInstaller.Core;

public enum InstallationManager
{
    Standalone,
    Npm,
    Bun,
    Unknown,
}

public static class InstallationManagerExtensions
{
    public static string DisplayName(this InstallationManager manager) => manager switch
    {
        InstallationManager.Standalone => "OpenAI 官方独立安装",
        InstallationManager.Npm => "npm",
        InstallationManager.Bun => "Bun",
        _ => "未知安装方式",
    };

    public static bool IsManagedByHelper(this InstallationManager manager) =>
        manager == InstallationManager.Standalone;
}

public sealed record InstallationInspection(
    InstallationManager? Manager,
    string? ExecutablePath,
    string? Version)
{
    public bool IsInstalled => !string.IsNullOrWhiteSpace(ExecutablePath);
    public bool CanInstallOrUpdate => Manager is null or InstallationManager.Standalone;
}

public enum InstallerPhase
{
    Idle,
    Inspecting,
    Ready,
    Downloading,
    Installing,
    Verifying,
    AwaitingLogin,
    SigningIn,
    Complete,
    Failed,
}

public static class InstallerStateMachine
{
    private static readonly HashSet<(InstallerPhase, InstallerPhase)> Allowed =
    [
        (InstallerPhase.Idle, InstallerPhase.Inspecting),
        (InstallerPhase.Inspecting, InstallerPhase.Ready),
        (InstallerPhase.Inspecting, InstallerPhase.Failed),
        (InstallerPhase.Ready, InstallerPhase.Downloading),
        (InstallerPhase.Ready, InstallerPhase.Verifying),
        (InstallerPhase.Downloading, InstallerPhase.Installing),
        (InstallerPhase.Downloading, InstallerPhase.Failed),
        (InstallerPhase.Installing, InstallerPhase.Verifying),
        (InstallerPhase.Installing, InstallerPhase.Failed),
        (InstallerPhase.Verifying, InstallerPhase.AwaitingLogin),
        (InstallerPhase.Verifying, InstallerPhase.Complete),
        (InstallerPhase.Verifying, InstallerPhase.Failed),
        (InstallerPhase.AwaitingLogin, InstallerPhase.SigningIn),
        (InstallerPhase.SigningIn, InstallerPhase.Complete),
        (InstallerPhase.SigningIn, InstallerPhase.AwaitingLogin),
        (InstallerPhase.SigningIn, InstallerPhase.Failed),
        (InstallerPhase.Failed, InstallerPhase.Inspecting),
        (InstallerPhase.Complete, InstallerPhase.Inspecting),
    ];

    public static bool Allows(InstallerPhase current, InstallerPhase next) =>
        current == next || Allowed.Contains((current, next));
}

public enum InstallerFailureKind
{
    UnsupportedSystem,
    InvalidDownloadUrl,
    InvalidInstallerScript,
    DownloadFailed,
    ProcessFailed,
    VerificationFailed,
    UnmanagedInstallation,
}

public sealed class InstallerFailure : Exception
{
    public InstallerFailureKind Kind { get; }
    public int? ExitCode { get; }

    public InstallerFailure(InstallerFailureKind kind, string message, int? exitCode = null, Exception? inner = null)
        : base(message, inner)
    {
        Kind = kind;
        ExitCode = exitCode;
    }
}

public sealed record ProcessResult(int ExitCode, string StandardOutput = "", string StandardError = "")
{
    public string CombinedOutput => string.Join(
        Environment.NewLine,
        new[] { StandardOutput, StandardError }.Where(value => !string.IsNullOrWhiteSpace(value)));
}

public static partial class VersionParser
{
    [GeneratedRegex(@"(?:codex(?:-cli)?\s+)?([0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?)", RegexOptions.IgnoreCase)]
    private static partial Regex VersionPattern();

    public static string? Parse(string output)
    {
        var match = VersionPattern().Match(output);
        return match.Success ? match.Groups[1].Value : null;
    }
}

public sealed record InstallerEnvironment(string UserProfile, string LocalAppData, string PathValue)
{
    public static InstallerEnvironment Current => new(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        Environment.GetEnvironmentVariable("PATH") ?? string.Empty);
}
