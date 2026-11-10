import Foundation

public enum AutoFetchInterval: Int, CaseIterable, Codable, Identifiable, Sendable {
    case off = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case thirtyMinutes = 30

    public var id: Int { rawValue }

    public var duration: Duration? {
        self == .off ? nil : .seconds(rawValue * 60)
    }

    public var title: String {
        self == .off ? "Off" : "Every \(rawValue) minutes"
    }
}

public struct DiffSettings: Codable, Hashable, Sendable {
    public static let fontSizes = 10...18
    public static let tabWidths = [2, 4, 8]
    public static let contextLineRange = 0...10

    public var fontSize: Int
    public var tabWidth: Int
    public var showsWhitespaceChanges: Bool
    public var contextLines: Int
    public var showsSideBySide: Bool
    public var showsEntireFile: Bool
    public var wrapsLines: Bool
    public var showsInvisibles: Bool

    public init(
        fontSize: Int = 12,
        tabWidth: Int = 4,
        showsWhitespaceChanges: Bool = true,
        contextLines: Int = DiffOptions.defaultContextLines,
        showsSideBySide: Bool = false,
        showsEntireFile: Bool = false,
        wrapsLines: Bool = false,
        showsInvisibles: Bool = false
    ) {
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.showsWhitespaceChanges = showsWhitespaceChanges
        self.contextLines = contextLines
        self.showsSideBySide = showsSideBySide
        self.showsEntireFile = showsEntireFile
        self.wrapsLines = wrapsLines
        self.showsInvisibles = showsInvisibles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = DiffSettings()
        self.init(
            fontSize: container.value(Int.self, .fontSize) ?? standard.fontSize,
            tabWidth: container.value(Int.self, .tabWidth) ?? standard.tabWidth,
            showsWhitespaceChanges: container.value(Bool.self, .showsWhitespaceChanges) ?? standard.showsWhitespaceChanges,
            contextLines: container.value(Int.self, .contextLines) ?? standard.contextLines,
            showsSideBySide: container.value(Bool.self, .showsSideBySide) ?? standard.showsSideBySide,
            showsEntireFile: container.value(Bool.self, .showsEntireFile) ?? standard.showsEntireFile,
            wrapsLines: container.value(Bool.self, .wrapsLines) ?? standard.wrapsLines,
            showsInvisibles: container.value(Bool.self, .showsInvisibles) ?? standard.showsInvisibles
        )
    }

    public var options: DiffOptions {
        DiffOptions(contextLines: showsEntireFile ? DiffOptions.entireFileContextLines : contextLines, ignoresWhitespace: !showsWhitespaceChanges)
    }

    public func normalized() -> DiffSettings {
        DiffSettings(
            fontSize: min(max(fontSize, Self.fontSizes.lowerBound), Self.fontSizes.upperBound),
            tabWidth: Self.tabWidths.contains(tabWidth) ? tabWidth : DiffSettings().tabWidth,
            showsWhitespaceChanges: showsWhitespaceChanges,
            contextLines: min(max(contextLines, Self.contextLineRange.lowerBound), Self.contextLineRange.upperBound),
            showsSideBySide: showsSideBySide,
            showsEntireFile: showsEntireFile,
            wrapsLines: wrapsLines,
            showsInvisibles: showsInvisibles
        )
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var defaultPullMode: PullMode
    public var autoFetch: AutoFetchInterval
    public var confirmsDestructiveActions: Bool
    public var showsConsoleOnLaunch: Bool
    public var diff: DiffSettings
    public var showsLessons: Bool
    public var showsReadCommands: Bool
    public var showsAuthorAvatars: Bool
    public var externalTools: ExternalToolSettings
    public var integration: IntegrationSettings

    public init(
        defaultPullMode: PullMode = .default,
        autoFetch: AutoFetchInterval = .off,
        confirmsDestructiveActions: Bool = true,
        showsConsoleOnLaunch: Bool = true,
        diff: DiffSettings = DiffSettings(),
        showsLessons: Bool = true,
        showsReadCommands: Bool = false,
        showsAuthorAvatars: Bool = true,
        externalTools: ExternalToolSettings = ExternalToolSettings(),
        integration: IntegrationSettings = IntegrationSettings()
    ) {
        self.defaultPullMode = defaultPullMode
        self.autoFetch = autoFetch
        self.confirmsDestructiveActions = confirmsDestructiveActions
        self.showsConsoleOnLaunch = showsConsoleOnLaunch
        self.diff = diff
        self.showsLessons = showsLessons
        self.showsReadCommands = showsReadCommands
        self.showsAuthorAvatars = showsAuthorAvatars
        self.externalTools = externalTools
        self.integration = integration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = AppSettings()
        self.init(
            defaultPullMode: container.value(PullMode.self, .defaultPullMode) ?? standard.defaultPullMode,
            autoFetch: container.value(AutoFetchInterval.self, .autoFetch) ?? standard.autoFetch,
            confirmsDestructiveActions: container.value(Bool.self, .confirmsDestructiveActions) ?? standard.confirmsDestructiveActions,
            showsConsoleOnLaunch: container.value(Bool.self, .showsConsoleOnLaunch) ?? standard.showsConsoleOnLaunch,
            diff: container.value(DiffSettings.self, .diff) ?? standard.diff,
            showsLessons: container.value(Bool.self, .showsLessons) ?? standard.showsLessons,
            showsReadCommands: container.value(Bool.self, .showsReadCommands) ?? standard.showsReadCommands,
            showsAuthorAvatars: container.value(Bool.self, .showsAuthorAvatars) ?? standard.showsAuthorAvatars,
            externalTools: container.value(ExternalToolSettings.self, .externalTools) ?? standard.externalTools,
            integration: container.value(IntegrationSettings.self, .integration) ?? standard.integration
        )
    }

    public static let standard = AppSettings()

    public func normalized() -> AppSettings {
        var settings = self
        settings.diff = diff.normalized()
        return settings
    }
}

private extension KeyedDecodingContainer {
    func value<Value: Decodable>(_ type: Value.Type, _ key: Key) -> Value? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
