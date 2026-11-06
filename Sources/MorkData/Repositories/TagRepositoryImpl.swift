import MorkDomain
import Foundation

public final class TagRepositoryImpl: TagRepositoryProtocol, TagActionsRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func tags() async throws -> [Tag] {
        GitOutputParser.tags(try await executor.read([
            "for-each-ref", "--sort=refname", "--format=\(GitOutputParser.tagFormat)", "refs/tags"
        ]))
    }

    public func create(named name: String, message: String) async throws {
        if message.isEmpty {
            try await executor.write(["tag", name])
        } else {
            try await executor.write(["tag", "-a", name, "-m", message])
        }
    }

    public func delete(_ tag: Tag) async throws {
        try await executor.write(["tag", "-d", tag.name])
    }

    public func delete(_ tag: Tag, from remote: String) async throws {
        try await executor.write(["push", remote, ":\(tag.reference)"])
    }

    public func details(of tag: Tag) async throws -> String {
        try await executor.read(["show", "--no-patch", "--format=fuller", tag.reference, "--"])
    }

    public func merge(_ tag: Tag) async throws {
        try await executor.write(["merge", "--no-edit", tag.reference])
    }

    public func rebase(onto tag: Tag, autostash: Bool) async throws {
        let scripts = RebaseEditorScripts(directory: FileManager.default.temporaryDirectory)
        try await executor.write(["rebase"] + (autostash ? ["--autostash"] : []) + [tag.reference], environment: try scripts.editorEnvironment())
    }
}
