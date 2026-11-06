import MorkDomain
import Foundation

public struct CustomCommandsDependencies: Sendable {
    public let loadCommands: LoadCustomCommandsUseCaseProtocol
    public let saveCommands: SaveCustomCommandsUseCaseProtocol

    public init(loadCommands: LoadCustomCommandsUseCaseProtocol, saveCommands: SaveCustomCommandsUseCaseProtocol) {
        self.loadCommands = loadCommands
        self.saveCommands = saveCommands
    }
}
