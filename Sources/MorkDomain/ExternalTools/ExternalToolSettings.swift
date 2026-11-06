import Foundation

public struct ExternalToolSettings: Codable, Hashable, Sendable {
    public static let customID = "custom"

    public var mergeTool: String?
    public var diffTool: String?
    public var customMergeCommand: String
    public var customDiffCommand: String
    public var trustsExitCode: Bool

    public init(
        mergeTool: String? = nil,
        diffTool: String? = nil,
        customMergeCommand: String = "",
        customDiffCommand: String = "",
        trustsExitCode: Bool = false
    ) {
        self.mergeTool = mergeTool
        self.diffTool = diffTool
        self.customMergeCommand = customMergeCommand
        self.customDiffCommand = customDiffCommand
        self.trustsExitCode = trustsExitCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<Value: Decodable>(_ type: Value.Type, _ key: CodingKeys) -> Value? {
            (try? container.decodeIfPresent(type, forKey: key)) ?? nil
        }
        self.init(
            mergeTool: value(String.self, .mergeTool),
            diffTool: value(String.self, .diffTool),
            customMergeCommand: value(String.self, .customMergeCommand) ?? "",
            customDiffCommand: value(String.self, .customDiffCommand) ?? "",
            trustsExitCode: value(Bool.self, .trustsExitCode) ?? false
        )
    }

    public func tool(for role: ExternalToolRole) -> String? {
        switch role {
        case .merge: mergeTool
        case .diff: diffTool
        }
    }

    public func customCommand(for role: ExternalToolRole) -> String {
        switch role {
        case .merge: customMergeCommand
        case .diff: customDiffCommand
        }
    }
}
