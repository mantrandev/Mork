import Foundation

struct LaunchOptions: Equatable {
    let repositoryURL: URL?
    let defaultsSuite: String?
    let resetsDefaults: Bool
    let settingsFile: URL?
    let offlineAvatars: Bool
    let openPanelFile: URL?
    let savePanelFile: URL?
    let folderPanelPath: URL?
    let keychainService: String?
    let hostingFixture: URL?
    let sshDirectory: URL?
    let supportDirectory: URL?
    let windowSize: CGSize?
    let expandsSidebarSections: Bool

    init(arguments: [String]) {
        repositoryURL = Self.value(after: "--repo", in: arguments).map { URL(fileURLWithPath: $0) }
        defaultsSuite = Self.value(after: "--defaults-suite", in: arguments)
        resetsDefaults = arguments.contains("--reset-defaults")
        offlineAvatars = arguments.contains("--offline-avatars")
        settingsFile = Self.value(after: "--settings-file", in: arguments).map { URL(fileURLWithPath: $0) }
        openPanelFile = Self.value(after: "--open-panel-file", in: arguments).map { URL(fileURLWithPath: $0) }
        savePanelFile = Self.value(after: "--save-panel-file", in: arguments).map { URL(fileURLWithPath: $0) }
        folderPanelPath = Self.value(after: "--folder-panel-path", in: arguments).map { URL(fileURLWithPath: $0) }
        keychainService = Self.value(after: "--keychain-service", in: arguments)
        hostingFixture = Self.value(after: "--hosting-fixture", in: arguments).map { URL(fileURLWithPath: $0) }
        sshDirectory = Self.value(after: "--ssh-dir", in: arguments).map { URL(fileURLWithPath: $0) }
        supportDirectory = Self.value(after: "--support-dir", in: arguments).map { URL(fileURLWithPath: $0) }
        windowSize = Self.value(after: "--window-size", in: arguments).flatMap(Self.size)
        expandsSidebarSections = arguments.contains("--expand-sidebar-sections")
    }

    private static func size(_ text: String) -> CGSize? {
        let parts = text.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts.allSatisfy({ $0 > 0 }) else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        let prefix = flag + "="
        if let inline = arguments.first(where: { $0.hasPrefix(prefix) }) {
            let value = String(inline.dropFirst(prefix.count))
            return value.isEmpty ? nil : value
        }
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
