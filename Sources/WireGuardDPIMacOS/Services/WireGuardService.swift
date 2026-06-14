import Foundation
import Combine
import AppKit

@MainActor
class WireGuardService: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = ""

    private let configDir: URL
    private let wgcfPath: URL

    private struct GitHubRelease: Decodable {
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
    }

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.configDir = homeDir.appendingPathComponent(".config/wireguard")
        self.wgcfPath = homeDir.appendingPathComponent(".local/bin/wgcf")

        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: wgcfPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func installStandard(includeBrowsers: Bool) async {
        isProcessing = true
        statusMessage = "wgcf indiriliyor..."

        do {
            // Download wgcf if needed
            try await downloadWgcf()

            statusMessage = "WireGuard profili oluşturuluyor..."

            // Register and generate profile
            try await registerAndGenerateProfile()

            // Configure profile
            try await configureProfile(customFolders: [], includeBrowsers: includeBrowsers)

            // Install WireGuard tunnel
            try await installTunnel()

            statusMessage = "Kurulum başarıyla tamamlandı!"

            // Show success alert
            await showAlert(title: "Başarılı", message: "WireGuard kurulumu başarıyla tamamlandı. Sistem yeniden başlatıldığında otomatik olarak aktif olacaktır.")

        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
            await showAlert(title: "Hata", message: "Kurulum başarısız: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    func installCustom(customFolders: [String], includeBrowsers: Bool) async {
        isProcessing = true
        statusMessage = "wgcf indiriliyor..."

        do {
            try await downloadWgcf()
            statusMessage = "WireGuard profili oluşturuluyor..."
            try await registerAndGenerateProfile()
            try await configureProfile(customFolders: customFolders, includeBrowsers: includeBrowsers)
            try await installTunnel()

            statusMessage = "Özel kurulum başarıyla tamamlandı!"
            await showAlert(title: "Başarılı", message: "WireGuard özel kurulumu başarıyla tamamlandı.")

        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
            await showAlert(title: "Hata", message: "Kurulum başarısız: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    func uninstall() async {
        isProcessing = true
        statusMessage = "WireGuard kaldırılıyor..."

        let wgQuickPath = Shell.firstExecutable(named: "wg-quick") ?? "/opt/homebrew/bin/wg-quick"
        let bashPath = Shell.firstExecutable(named: "bash") ?? "/opt/homebrew/bin/bash"
        _ = try? await executePrivilegedShellCommand("\(Shell.quote(bashPath)) \(Shell.quote(wgQuickPath)) down wgcf || true")
        _ = try? await executePrivilegedShellCommand(launchDaemonBootoutCommand())
        _ = try? await executePrivilegedShellCommand("rm -f \(Shell.quote(WireGuardLaunchDaemon.plistPath)) \(Shell.quote(WireGuardLaunchDaemon.legacyPlistPath)) /etc/wireguard/wgcf.conf")

        // Remove configuration files
        let configPath = configDir.appendingPathComponent("wgcf.conf")
        let accountPath = configDir.appendingPathComponent("wgcf-account.toml")
        let profilePath = configDir.appendingPathComponent("wgcf-profile.conf")

        try? FileManager.default.removeItem(at: configPath)
        try? FileManager.default.removeItem(at: accountPath)
        try? FileManager.default.removeItem(at: profilePath)

        statusMessage = "WireGuard başarıyla kaldırıldı!"
        await showAlert(title: "Başarılı", message: "WireGuard başarıyla kaldırıldı.")

        isProcessing = false
    }

    // MARK: - Private Methods

    private func downloadWgcf() async throws {
        if isValidWgcf(at: wgcfPath) {
            print("valid wgcf already exists at \(wgcfPath.path)")
            return
        }

        try? FileManager.default.removeItem(at: wgcfPath)

        let downloadURL = try await latestWgcfDownloadURL()
        let (localURL, response) = try await URLSession.shared.download(from: downloadURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "WireGuardService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "wgcf indirilemedi. HTTP \(httpResponse.statusCode)"]
            )
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 1_000_000 else {
            throw NSError(
                domain: "WireGuardService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "İndirilen wgcf dosyası geçerli bir binary değil."]
            )
        }

        try FileManager.default.moveItem(at: localURL, to: wgcfPath)

        try await executeShellCommand("chmod +x \(Shell.quote(wgcfPath.path))")

        guard isValidWgcf(at: wgcfPath) else {
            try? FileManager.default.removeItem(at: wgcfPath)
            throw NSError(
                domain: "WireGuardService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "wgcf indirildi ancak çalıştırılabilir görünmüyor."]
            )
        }
    }

    private func registerAndGenerateProfile() async throws {
        // Remove existing account if exists
        let accountPath = configDir.appendingPathComponent("wgcf-account.toml")
        try? FileManager.default.removeItem(at: accountPath)

        // Register
        let registerCommand = "cd \(Shell.quote(configDir.path)) && \(Shell.quote(wgcfPath.path)) register --accept-tos"
        try await executeShellCommand(registerCommand)

        // Generate profile
        let generateCommand = "cd \(Shell.quote(configDir.path)) && \(Shell.quote(wgcfPath.path)) generate"
        try await executeShellCommand(generateCommand)
    }

    private func configureProfile(customFolders: [String], includeBrowsers: Bool) async throws {
        let profilePath = configDir.appendingPathComponent("wgcf-profile.conf")
        let configPath = configDir.appendingPathComponent("wgcf.conf")

        guard FileManager.default.fileExists(atPath: profilePath.path) else {
            throw NSError(domain: "WireGuardService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profil dosyası bulunamadı"])
        }

        // Read profile
        var content = try String(contentsOf: profilePath, encoding: .utf8)

        // Build allowed apps list
        var allowedApps = [
            "/Applications/Discord.app",
            "/Applications/Discord PTB.app",
            "discord",
            "Discord.app"
        ]

        if includeBrowsers {
            allowedApps += [
                "/Applications/Google Chrome.app",
                "/Applications/Firefox.app",
                "/Applications/Opera.app",
                "/Applications/Brave Browser.app",
                "/Applications/Microsoft Edge.app",
                "/Applications/Vivaldi.app",
                "/Applications/Safari.app"
            ]
        }

        allowedApps += customFolders

        // Add AllowedApps line after Endpoint
        if let endpointRange = content.range(of: "Endpoint = ") {
            let lineEnd = content[endpointRange.upperBound...].firstIndex(of: "\n") ?? content.endIndex
            let insertPosition = content.index(after: lineEnd)
            let allowedAppsLine = "# AllowedApps = \(allowedApps.joined(separator: ", "))\n"
            content.insert(contentsOf: allowedAppsLine, at: insertPosition)
        }

        // Write to final config
        try content.write(to: configPath, atomically: true, encoding: .utf8)
    }

    private func installTunnel() async throws {
        let configPath = configDir.appendingPathComponent("wgcf.conf")
        _ = try requireExecutable(named: "wg")
        let wgQuickPath = try requireExecutable(named: "wg-quick")
        let bashPath = try requireExecutable(named: "bash")
        let wireGuardGoPath = try requireExecutable(named: "wireguard-go")

        let wgQuickCommand = "\(Shell.quote(bashPath)) \(Shell.quote(wgQuickPath))"

        try await executePrivilegedShellCommand(
            "mkdir -p /etc/wireguard && cp \(Shell.quote(configPath.path)) /etc/wireguard/wgcf.conf && (\(wgQuickCommand) down wgcf 2>/dev/null || true) && \(wgQuickCommand) up wgcf"
        )

        // Enable at startup (create LaunchDaemon)
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(WireGuardLaunchDaemon.label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(bashPath)</string>
                <string>\(wgQuickPath)</string>
                <string>up</string>
                <string>wgcf</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>\(Shell.defaultPath)</string>
                <key>WG_QUICK_USERSPACE_IMPLEMENTATION</key>
                <string>\(wireGuardGoPath)</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        let plistPath = "/tmp/\(WireGuardLaunchDaemon.label).plist"
        try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)

        try? await executePrivilegedShellCommand(
            "\(launchDaemonBootoutCommand()); rm -f \(Shell.quote(WireGuardLaunchDaemon.legacyPlistPath)); cp \(Shell.quote(plistPath)) \(Shell.quote(WireGuardLaunchDaemon.plistPath)) && chown root:wheel \(Shell.quote(WireGuardLaunchDaemon.plistPath)) && chmod 644 \(Shell.quote(WireGuardLaunchDaemon.plistPath)) && launchctl bootstrap system \(Shell.quote(WireGuardLaunchDaemon.plistPath))"
        )
    }

    private func launchDaemonBootoutCommand() -> String {
        zip(WireGuardLaunchDaemon.allLabels, WireGuardLaunchDaemon.allPlistPaths)
            .map { label, plistPath in
                "launchctl bootout system/\(label) 2>/dev/null || launchctl bootout system \(Shell.quote(plistPath)) 2>/dev/null || launchctl unload \(Shell.quote(plistPath)) 2>/dev/null || true"
            }
            .joined(separator: "; ")
    }

    private func latestWgcfDownloadURL() async throws -> URL {
        let releaseURL = URL(string: "https://api.github.com/repos/ViRb3/wgcf/releases/latest")!
        let (data, response) = try await URLSession.shared.data(from: releaseURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "WireGuardService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "wgcf son sürüm bilgisi alınamadı. HTTP \(httpResponse.statusCode)"]
            )
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "amd64"
        #endif

        guard let asset = release.assets.first(where: {
            $0.name.hasPrefix("wgcf_") && $0.name.hasSuffix("_darwin_\(architecture)")
        }),
        let url = URL(string: asset.browserDownloadURL) else {
            throw NSError(
                domain: "WireGuardService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Bu Mac için uygun wgcf binary bulunamadı (darwin_\(architecture))."]
            )
        }

        return url
    }

    private func isValidWgcf(at url: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: url.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return false
        }

        return fileSize.intValue > 1_000_000
    }

    private func requireExecutable(named name: String) throws -> String {
        if let path = Shell.firstExecutable(named: name) {
            return path
        }

        throw NSError(
            domain: "WireGuardService",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "\(name) bulunamadı. Terminal'de `brew install wireguard-tools` çalıştırıp tekrar deneyin."]
        )
    }

    @discardableResult
    private func executeShellCommand(_ command: String) async throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.environment = Shell.environment

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            throw NSError(domain: "ShellCommand", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }

        return output
    }

    private func executePrivilegedShellCommand(_ command: String) async throws {
        let commandWithPath = "export PATH=\(Shell.quote(Shell.defaultPath)); \(command)"
        let script = "do shell script \(appleScriptString(commandWithPath)) with administrator privileges"

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            throw NSError(
                domain: "AppleScript",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.description]
            )
        }
    }

    private func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return "\"\(escaped)\""
    }

    private func showAlert(title: String, message: String) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Hata" ? .critical : .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }
}
