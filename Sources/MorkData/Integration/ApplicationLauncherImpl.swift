import MorkDomain
import Foundation

public final class ApplicationLauncherImpl: ApplicationLauncherProtocol {
    public typealias OpenWithApplication = @Sendable ([URL], URL) async throws -> Void

    private let openWithApplication: OpenWithApplication

    public init(openWithApplication: @escaping OpenWithApplication) {
        self.openWithApplication = openWithApplication
    }

    public func launch(_ launch: ApplicationLaunch) async throws {
        switch launch {
        case let .open(paths, application):
            try await openWithApplication(paths.map { URL(fileURLWithPath: $0) }, URL(fileURLWithPath: application))
        case let .run(executable, arguments, environment):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in }
            try process.run()
        }
    }
}
