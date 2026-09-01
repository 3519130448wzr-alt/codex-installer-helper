import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol InstallerScriptDownloading: Sendable {
    func downloadInstallerScript() async throws -> URL
}

public final class OfficialInstallerDownloader: InstallerScriptDownloading, @unchecked Sendable {
    public static let installerURL = URL(string: "https://chatgpt.com/codex/install.sh")!
    private static let maximumScriptSize = 2 * 1024 * 1024

    private let session: URLSession
    private let fileManager: FileManager

    public init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    public func downloadInstallerScript() async throws -> URL {
        do {
            let (data, response) = try await session.data(from: Self.installerURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  Self.isAllowedFinalURL(httpResponse.url) else {
                throw InstallerFailure.invalidDownloadURL
            }
            guard data.count <= Self.maximumScriptSize,
                  Self.isValidScript(data) else {
                throw InstallerFailure.invalidInstallerScript
            }

            let directory = fileManager.temporaryDirectory
                .appendingPathComponent("codex-installer-download-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let scriptURL = directory.appendingPathComponent("install.sh")
            try data.write(to: scriptURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL
        } catch let failure as InstallerFailure {
            throw failure
        } catch {
            throw InstallerFailure.downloadFailed(error.localizedDescription)
        }
    }

    public static func isAllowedFinalURL(_ url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https" else {
            return false
        }
        let endpoint = (url.host?.lowercased(), url.path)
        return endpoint == ("chatgpt.com", "/codex/install.sh") ||
            endpoint == ("releases.openai.com", "/codex/install.sh")
    }

    public static func isValidScript(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(4096), encoding: .utf8) else { return false }
        return prefix.hasPrefix("#!/bin/sh") &&
            prefix.contains("CODEX_INSTALL_DIR") &&
            prefix.contains("releases.openai.com/codex")
    }
}
