import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var selectedTab = 1  // Default to ByeDPI tab
    @Published var isDarkMode = false
    @Published var selectedLanguage: Language = .turkish

    // WireGuard State
    @Published var isWireGuardConfigured = false
    @Published var isWireGuardActive = false
    @Published var wireGuardStatus = "Yapılandırılmadı"

    // Service States
    @Published var installedServices: [String] = []

    // Folder customization
    @Published var customFolders: [String] = []
    @Published var includeBrowsers = false

    // Favorite Apps for Quick Actions
    @Published var favoriteApps: [FavoriteApp] = []

    enum Language: String, CaseIterable {
        case turkish = "Türkçe"
        case english = "English"
        case russian = "Русский"
    }

    struct FavoriteApp: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        let path: String
        let bundleIdentifier: String?
        var customArgs: String  // Custom proxy arguments for this app

        init(name: String, path: String, bundleIdentifier: String? = nil, customArgs: String = "--proxy-server=socks5://127.0.0.1:1080") {
            self.id = UUID()
            self.name = name
            self.path = path
            self.bundleIdentifier = bundleIdentifier
            self.customArgs = customArgs
        }
    }

    init() {
        loadSettings()
        checkServices()
    }

    func loadSettings() {
        if let isDark = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool {
            isDarkMode = isDark
        }

        if let langRaw = UserDefaults.standard.string(forKey: "language"),
           let lang = Language(rawValue: langRaw) {
            selectedLanguage = lang
        }

        customFolders = UserDefaults.standard.stringArray(forKey: "customFolders") ?? []
        includeBrowsers = UserDefaults.standard.bool(forKey: "includeBrowsers")

        // Load favorite apps
        if let data = UserDefaults.standard.data(forKey: "favoriteApps"),
           let apps = try? JSONDecoder().decode([FavoriteApp].self, from: data) {
            favoriteApps = apps
        } else {
            // Default favorites
            favoriteApps = [
                FavoriteApp(name: "Discord", path: "/Applications/Discord.app", bundleIdentifier: "com.hnc.Discord")
            ]
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "language")
        UserDefaults.standard.set(customFolders, forKey: "customFolders")
        UserDefaults.standard.set(includeBrowsers, forKey: "includeBrowsers")

        // Save favorite apps
        if let data = try? JSONEncoder().encode(favoriteApps) {
            UserDefaults.standard.set(data, forKey: "favoriteApps")
        }
    }

    // Favorite Apps Management
    func addFavoriteApp(_ app: FavoriteApp) {
        if !favoriteApps.contains(where: { $0.path == app.path }) {
            favoriteApps.append(app)
            saveSettings()
        }
    }

    func removeFavoriteApp(_ app: FavoriteApp) {
        favoriteApps.removeAll { $0.id == app.id }
        saveSettings()
    }

    func updateFavoriteApp(_ app: FavoriteApp) {
        if let index = favoriteApps.firstIndex(where: { $0.id == app.id }) {
            favoriteApps[index] = app
            saveSettings()
        }
    }

    func isFavorite(_ appPath: String) -> Bool {
        favoriteApps.contains { $0.path == appPath }
    }

    func checkServices() {
        // Check WireGuard status
        Task {
            await checkWireGuardStatus()
        }
    }

    @MainActor
    func checkWireGuardStatus() async {
        let userConfigPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/wireguard/wgcf.conf")
        let systemConfigPath = "/etc/wireguard/wgcf.conf"

        let hasConfig = FileManager.default.fileExists(atPath: userConfigPath.path)
            || FileManager.default.fileExists(atPath: systemConfigPath)
        let launchdStatus = (try? await executeShellCommand("launchctl print system/com.splitwire.wireguard 2>/dev/null")) ?? ""
        let routeStatus = (try? await executeShellCommand("route -n get 1.1.1.1 2>/dev/null")) ?? ""

        isWireGuardConfigured = hasConfig
        isWireGuardActive = launchdStatus.contains("state = running")
            || routeStatus.contains("interface: utun")

        if isWireGuardActive {
            wireGuardStatus = "Aktif"
        } else if isWireGuardConfigured {
            wireGuardStatus = "Kurulu ama çalışmıyor"
        } else {
            wireGuardStatus = "Yapılandırılmadı"
        }
    }

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
        return String(data: data, encoding: .utf8) ?? ""
    }

    func addCustomFolder(_ folder: String) {
        if !customFolders.contains(folder) {
            customFolders.append(folder)
            saveSettings()
        }
    }

    func removeCustomFolder(_ folder: String) {
        customFolders.removeAll { $0 == folder }
        saveSettings()
    }

    func clearCustomFolders() {
        customFolders.removeAll()
        saveSettings()
    }
}
