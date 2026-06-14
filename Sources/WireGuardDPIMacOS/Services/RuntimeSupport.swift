import Foundation

enum Shell {
    static let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = defaultPath
        return environment
    }

    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func firstExecutable(named name: String) -> String? {
        for directory in defaultPath.split(separator: ":").map(String.init) {
            let path = "\(directory)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}

enum WireGuardLaunchDaemon {
    static let label = "com.aliozkanozdurmus.wireguard-dpi-macos.wireguard"
    static let legacyLabel = "com.splitwire.wireguard"

    static var plistPath: String {
        "/Library/LaunchDaemons/\(label).plist"
    }

    static var legacyPlistPath: String {
        "/Library/LaunchDaemons/\(legacyLabel).plist"
    }

    static let allLabels = [label, legacyLabel]

    static let allPlistPaths = [plistPath, legacyPlistPath]
}

enum CiadpiLocator {
    private static let resourceBundleName = "wireguard-dpi-macos_WireGuardDPIMacOS.bundle"

    static func find() -> String? {
        for url in candidateURLs() {
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url.path
            }
        }

        return nil
    }

    static var searchDescription: String {
        candidateURLs().map(\.path).joined(separator: "\n")
    }

    private static func candidateURLs() -> [URL] {
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("bin/ciadpi"))
            candidates.append(resourceURL.appendingPathComponent("ciadpi"))
            candidates.append(resourceURL.appendingPathComponent(resourceBundleName).appendingPathComponent("ciadpi"))
        }

        candidates.append(Bundle.main.bundleURL.appendingPathComponent(resourceBundleName).appendingPathComponent("ciadpi"))

        if let executablePath = Bundle.main.executablePath {
            let executableDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            candidates.append(executableDirectory.appendingPathComponent("bin/ciadpi"))
            candidates.append(executableDirectory.appendingPathComponent(resourceBundleName).appendingPathComponent("ciadpi"))
            candidates.append(executableDirectory.appendingPathComponent("../Resources/bin/ciadpi").standardizedFileURL)
            candidates.append(executableDirectory.appendingPathComponent("../Resources/ciadpi").standardizedFileURL)
            candidates.append(executableDirectory.appendingPathComponent("../Resources/\(resourceBundleName)/ciadpi").standardizedFileURL)
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.append(currentDirectory.appendingPathComponent("Sources/WireGuardDPIMacOS/Resources/bin/ciadpi"))
        candidates.append(currentDirectory.appendingPathComponent(".build/release/\(resourceBundleName)/ciadpi"))
        candidates.append(currentDirectory.appendingPathComponent("byedpi/ciadpi"))

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(homeDirectory.appendingPathComponent("Downloads/wireguard-dpi-macos/Sources/WireGuardDPIMacOS/Resources/bin/ciadpi"))
        candidates.append(homeDirectory.appendingPathComponent("Downloads/wireguard-dpi-macos/byedpi/ciadpi"))

        return unique(candidates.map { $0.standardizedFileURL })
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()

        return urls.filter { url in
            let path = url.path
            guard !seen.contains(path) else {
                return false
            }

            seen.insert(path)
            return true
        }
    }
}
