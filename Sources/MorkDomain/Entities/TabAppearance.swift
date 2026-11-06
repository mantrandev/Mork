import Foundation

public enum TabColor: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, gray
}

public struct TabAppearance: Equatable, Sendable {
    public var title: String?
    public var color: TabColor?

    public init(title: String? = nil, color: TabColor? = nil) {
        self.title = title
        self.color = color
    }

    public var isEmpty: Bool {
        title == nil && color == nil
    }
}

public struct TabAppearances: Equatable, Sendable {
    public private(set) var byPath: [String: TabAppearance]

    public init(byPath: [String: TabAppearance] = [:]) {
        self.byPath = byPath.filter { !$0.value.isEmpty }
    }

    public func appearance(for repository: URL) -> TabAppearance {
        byPath[Self.key(for: repository)] ?? TabAppearance()
    }

    public mutating func rename(_ repository: URL, to title: String?) {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        update(repository) { $0.title = trimmed.isEmpty ? nil : trimmed }
    }

    public mutating func setColor(_ color: TabColor?, for repository: URL) {
        update(repository) { $0.color = color }
    }

    private mutating func update(_ repository: URL, _ change: (inout TabAppearance) -> Void) {
        let key = Self.key(for: repository)
        var appearance = byPath[key] ?? TabAppearance()
        change(&appearance)
        byPath[key] = appearance.isEmpty ? nil : appearance
    }

    private static func key(for repository: URL) -> String {
        let path = repository.standardizedFileURL.path
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
