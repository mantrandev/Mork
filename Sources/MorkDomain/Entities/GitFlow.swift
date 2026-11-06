import Foundation

public struct GitFlowConfiguration: Equatable, Sendable {
    public var mainBranch: String
    public var developBranch: String
    public var featurePrefix: String
    public var releasePrefix: String
    public var hotfixPrefix: String
    public var supportPrefix: String
    public var versionTagPrefix: String

    public init(
        mainBranch: String = "main",
        developBranch: String = "develop",
        featurePrefix: String = "feature/",
        releasePrefix: String = "release/",
        hotfixPrefix: String = "hotfix/",
        supportPrefix: String = "support/",
        versionTagPrefix: String = ""
    ) {
        self.mainBranch = mainBranch
        self.developBranch = developBranch
        self.featurePrefix = featurePrefix
        self.releasePrefix = releasePrefix
        self.hotfixPrefix = hotfixPrefix
        self.supportPrefix = supportPrefix
        self.versionTagPrefix = versionTagPrefix
    }

    public static let standard = GitFlowConfiguration()

    public init?(config: [String: String]) {
        let values = Dictionary(config.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        guard let main = values["gitflow.branch.master"], let develop = values["gitflow.branch.develop"], !main.isEmpty, !develop.isEmpty else { return nil }
        let standard = Self.standard
        self.init(
            mainBranch: main,
            developBranch: develop,
            featurePrefix: values["gitflow.prefix.feature"] ?? standard.featurePrefix,
            releasePrefix: values["gitflow.prefix.release"] ?? standard.releasePrefix,
            hotfixPrefix: values["gitflow.prefix.hotfix"] ?? standard.hotfixPrefix,
            supportPrefix: values["gitflow.prefix.support"] ?? standard.supportPrefix,
            versionTagPrefix: values["gitflow.prefix.versiontag"] ?? standard.versionTagPrefix
        )
    }

    public var configEntries: [(key: String, value: String)] {
        [
            ("gitflow.branch.master", mainBranch),
            ("gitflow.branch.develop", developBranch),
            ("gitflow.prefix.feature", featurePrefix),
            ("gitflow.prefix.release", releasePrefix),
            ("gitflow.prefix.hotfix", hotfixPrefix),
            ("gitflow.prefix.support", supportPrefix),
            ("gitflow.prefix.versiontag", versionTagPrefix)
        ]
    }

    public func prefix(for kind: GitFlowBranchKind) -> String {
        switch kind {
        case .feature: featurePrefix
        case .release: releasePrefix
        case .hotfix: hotfixPrefix
        }
    }

    public func base(for kind: GitFlowBranchKind) -> String {
        kind == .hotfix ? mainBranch : developBranch
    }
}

public enum GitFlowBranchKind: String, CaseIterable, Identifiable, Sendable {
    case feature
    case release
    case hotfix

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var createsTag: Bool { self != .feature }

    public var namePlaceholder: String {
        switch self {
        case .feature: "login-form"
        case .release, .hotfix: "1.2.0"
        }
    }
}

public enum GitFlowAction: Equatable, Sendable {
    case initialize(GitFlowConfiguration)
    case start(GitFlowBranchKind, name: String)
    case finish(GitFlowBranchKind, name: String)
}

public struct GitFlowContext: Equatable, Sendable {
    public let configuration: GitFlowConfiguration?
    public let localBranches: [String]
    public let tags: [String]
    public let currentBranch: String?
    public let hasCommits: Bool

    public init(configuration: GitFlowConfiguration?, localBranches: [String], tags: [String], currentBranch: String?, hasCommits: Bool) {
        self.configuration = configuration
        self.localBranches = localBranches
        self.tags = tags
        self.currentBranch = currentBranch
        self.hasCommits = hasCommits
    }

    public var isInitialized: Bool { configuration != nil }

    public func branches(of kind: GitFlowBranchKind) -> [String] {
        guard let prefix = configuration?.prefix(for: kind), !prefix.isEmpty else { return [] }
        return localBranches.filter { $0.hasPrefix(prefix) && $0.count > prefix.count }
    }
}

public struct GitFlowStep: Equatable, Hashable, Sendable {
    public let arguments: [String]
    public let note: String
    public let isMerge: Bool

    public init(_ arguments: [String], note: String, isMerge: Bool = false) {
        self.arguments = arguments
        self.note = note
        self.isMerge = isMerge
    }

    public var commandLine: String {
        (["git"] + arguments.map(ShellWords.quote)).joined(separator: " ")
    }
}

public enum GitFlowOutcome: Equatable, Sendable {
    case completed
    case stoppedOnConflict(GitFlowStep, remaining: [GitFlowStep])
}

public enum GitFlowError: LocalizedError, Equatable, Sendable {
    case notInitialized
    case emptyName
    case invalidName(String)
    case sameMainAndDevelop
    case emptyPrefix(String)
    case branchExists(String)
    case branchMissing(String)
    case tagExists(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized: "Git Flow is not set up in this repository yet. Initialize it first."
        case .emptyName: "Enter a name."
        case let .invalidName(name): "\"\(name)\" cannot be part of a branch name: no spaces, ~ ^ : ? * [ \\ or \"..\"."
        case .sameMainAndDevelop: "The production and development branches must be different."
        case let .emptyPrefix(kind): "The \(kind) prefix cannot be empty."
        case let .branchExists(name): "The branch \(name) already exists."
        case let .branchMissing(name): "The branch \(name) does not exist."
        case let .tagExists(name): "The tag \(name) already exists."
        }
    }
}
