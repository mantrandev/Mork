import MorkDomain
import Foundation

public final class FileSystemIntegrationDetector: IntegrationDetectorProtocol {
    public static let defaultApplicationDirectories = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    private let applicationDirectories: [URL]
    private let searchPaths: [String]
    private let locateApplication: @Sendable (String) -> URL?

    public init(
        applicationDirectories: [URL] = FileSystemIntegrationDetector.defaultApplicationDirectories,
        searchPaths: [String] = FileSystemIntegrationDetector.searchPaths(environment: ProcessInfo.processInfo.environment),
        locateApplication: @escaping @Sendable (String) -> URL? = { _ in nil }
    ) {
        self.applicationDirectories = applicationDirectories
        self.searchPaths = searchPaths
        self.locateApplication = locateApplication
    }

    public static func searchPaths(environment: [String: String]) -> [String] {
        let paths = (environment["PATH"] ?? "").split(separator: ":").map(String.init) + ["/opt/homebrew/bin", "/usr/local/bin"]
        var seen = Set<String>()
        return paths.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public func detect() async -> IntegrationInventory {
        let tools = ExternalToolCatalog.all.compactMap { definition -> DetectedExternalTool? in
            guard let executable = bundledExecutable(of: definition.bundles) ?? command(definition.commands) else { return nil }
            return DetectedExternalTool(definition: definition, executable: executable)
        }
        let apps = IntegrationAppCatalog.all.compactMap { definition -> DetectedIntegrationApp? in
            guard let application = definition.bundles.lazy.compactMap(application(of:)).first else { return nil }
            return DetectedIntegrationApp(
                definition: definition,
                application: application.path,
                executable: bundledExecutable(of: definition.bundles) ?? command(definition.commands)
            )
        }
        return IntegrationInventory(tools: tools, apps: apps)
    }

    public func isExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    public func locate(command name: String) -> String? {
        searchPaths.lazy.map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }.first(where: isExecutable)
    }

    private func command(_ names: [String]) -> String? {
        names.lazy.compactMap(locate(command:)).first
    }

    private func bundledExecutable(of bundles: [ExternalToolBundle]) -> String? {
        bundles.lazy.compactMap { bundle -> String? in
            guard !bundle.executable.isEmpty, let application = self.application(of: bundle) else { return nil }
            let path = application.appendingPathComponent(bundle.executable).path
            return self.isExecutable(path) ? path : nil
        }.first
    }

    private func application(of bundle: ExternalToolBundle) -> URL? {
        var isDirectory: ObjCBool = false
        let installed = applicationDirectories.lazy
            .map { $0.appendingPathComponent(bundle.name) }
            .first { FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDirectory) && isDirectory.boolValue }
        return installed ?? bundle.identifiers.lazy.compactMap(locateApplication).first
    }
}
