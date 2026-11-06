import MorkDomain
import Foundation

public struct PendingCustomCommand: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let command: CustomCommand
    public let context: CustomCommandContext
    public let commandLine: String
}

extension RepositoryViewModel {
    public func setCustomCommands(_ commands: [CustomCommand]) {
        var menus: [CustomCommandLocation: [CustomCommand]] = [:]
        for command in commands where command.problem == nil {
            for location in CustomCommandLocation.allCases where command.appears(in: location) {
                menus[location, default: []].append(command)
            }
        }
        if customCommandMenus != menus { customCommandMenus = menus }
    }

    public func customCommands(for location: CustomCommandLocation) -> [CustomCommand] {
        customCommandMenus[location] ?? []
    }

    public func customCommandContext(branch: Branch? = nil, commit: Commit? = nil, file: String? = nil) -> CustomCommandContext {
        let remote = branch?.remoteName ?? (branch ?? currentBranch)?.upstream?.split(separator: "/").first.map(String.init)
        return CustomCommandContext(
            repository: url.path,
            branch: (branch ?? currentBranch)?.localName,
            sha: (commit ?? selectedCommit)?.hash,
            file: file,
            remote: remote
        )
    }

    public func run(_ command: CustomCommand, branch: Branch? = nil, commit: Commit? = nil, file: String? = nil) async {
        let context = customCommandContext(branch: branch, commit: commit, file: file)
        let invocation: CustomCommandInvocation
        do {
            invocation = try CustomCommandExpander.expand(command, in: context)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        if command.confirmsBeforeRunning {
            pendingCustomCommand = PendingCustomCommand(command: command, context: context, commandLine: invocation.displayLine)
            return
        }
        await execute(command, context: context)
    }

    public func confirmPendingCustomCommand() async {
        guard let pending = pendingCustomCommand else { return }
        pendingCustomCommand = nil
        await execute(pending.command, context: pending.context)
    }

    private func execute(_ command: CustomCommand, context: CustomCommandContext) async {
        await perform { try await $0.commit.runCustomCommand.execute(command, context: context) }
    }
}
