import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class CustomCommandsSettingsViewModel {
    public private(set) var commands: [CustomCommand]
    public var selectedID: UUID?
    @ObservationIgnored public var onChange: (@MainActor ([CustomCommand]) -> Void)?

    private let dependencies: CustomCommandsDependencies

    public init(dependencies: CustomCommandsDependencies) {
        self.dependencies = dependencies
        commands = dependencies.loadCommands.execute()
        selectedID = commands.first?.id
    }

    public var selected: CustomCommand? {
        commands.first { $0.id == selectedID }
    }

    public func add() {
        let command = CustomCommand(name: "New Command", commandLine: "")
        commands.append(command)
        selectedID = command.id
        persist()
    }

    public func remove(_ id: UUID) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        commands.remove(at: index)
        if selectedID == id { selectedID = commands.indices.contains(index) ? commands[index].id : commands.last?.id }
        persist()
    }

    public func update(_ id: UUID, _ change: (inout CustomCommand) -> Void) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        var command = commands[index]
        change(&command)
        guard command != commands[index] else { return }
        commands[index] = command
        persist()
    }

    public func setLocation(_ location: CustomCommandLocation, enabled: Bool, for id: UUID) {
        update(id) { command in
            if enabled { command.locations.insert(location) } else { command.locations.remove(location) }
        }
    }

    private func persist() {
        dependencies.saveCommands.execute(commands)
        onChange?(commands)
    }
}
