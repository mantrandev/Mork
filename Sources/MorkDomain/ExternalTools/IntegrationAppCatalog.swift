import Foundation

public enum IntegrationAppCatalog {
    public static let defaultTerminalID = "terminal"

    public static let all: [IntegrationAppDefinition] = terminals + editors

    private static let terminals: [IntegrationAppDefinition] = [
        terminal("terminal", "Terminal", "Terminal.app", ["com.apple.Terminal"]),
        terminal("iterm", "iTerm", "iTerm.app", ["com.googlecode.iterm2"]),
        terminal("warp", "Warp", "Warp.app", ["dev.warp.Warp-Stable"]),
        terminal("ghostty", "Ghostty", "Ghostty.app", ["com.mitchellh.ghostty"]),
        terminal("alacritty", "Alacritty", "Alacritty.app", ["org.alacritty"], folder: .openArguments(["--working-directory"])),
        terminal("kitty", "kitty", "kitty.app", ["net.kovidgoyal.kitty"], folder: .openArguments(["--single-instance", "--directory"])),
        terminal("wezterm", "WezTerm", "WezTerm.app", ["com.github.wez.wezterm"], folder: .openArguments(["start", "--cwd"])),
        terminal("hyper", "Hyper", "Hyper.app", ["co.zeit.hyper"])
    ]

    private static let editors: [IntegrationAppDefinition] = [
        editor("vscode", "Visual Studio Code", [bundle("Visual Studio Code.app", ["com.microsoft.VSCode"], "Contents/Resources/app/bin/code")], commands: ["code"], line: .goto),
        editor("cursor", "Cursor", [bundle("Cursor.app", ["com.todesktop.230313mzl4w4u92"], "Contents/Resources/app/bin/cursor")], commands: ["cursor"], line: .goto),
        editor("zed", "Zed", [bundle("Zed.app", ["dev.zed.Zed"], "Contents/MacOS/cli")], commands: ["zed"], line: .colon),
        editor("sublime", "Sublime Text", [bundle("Sublime Text.app", ["com.sublimetext.4", "com.sublimetext.3"], "Contents/SharedSupport/bin/subl")], commands: ["subl"], line: .colon),
        editor("xcode", "Xcode", [bundle("Xcode.app", ["com.apple.dt.Xcode"], "Contents/Developer/usr/bin/xed")], commands: ["xed"], line: .flag("-l")),
        editor("bbedit", "BBEdit", [bundle("BBEdit.app", ["com.barebones.bbedit"], "")], commands: ["bbedit"], line: .plus),
        editor("nova", "Nova", [bundle("Nova.app", ["com.panic.Nova"], "")]),
        editor("textmate", "TextMate", [bundle("TextMate.app", ["com.macromates.TextMate"], "Contents/MacOS/mate")], commands: ["mate"], line: .flag("-l")),
        editor(
            "intellij",
            "IntelliJ IDEA",
            [bundle("IntelliJ IDEA.app", ["com.jetbrains.intellij"], ""), bundle("IntelliJ IDEA CE.app", ["com.jetbrains.intellij.ce"], "")],
            line: .openArguments("--line")
        ),
        editor("appcode", "AppCode", [bundle("AppCode.app", ["com.jetbrains.AppCode"], "")], line: .openArguments("--line")),
        editor("androidstudio", "Android Studio", [bundle("Android Studio.app", ["com.google.android.studio"], "")], line: .openArguments("--line")),
        editor("fleet", "Fleet", [bundle("Fleet.app", ["com.jetbrains.fleet"], "")]),
        editor("coteditor", "CotEditor", [bundle("CotEditor.app", ["com.coteditor.CotEditor"], "Contents/SharedSupport/bin/cot")], commands: ["cot"], line: .flag("-l"))
    ]

    public static func apps(_ kind: IntegrationAppKind) -> [IntegrationAppDefinition] {
        all.filter { $0.kind == kind }
    }

    public static func definition(id: String, kind: IntegrationAppKind) -> IntegrationAppDefinition? {
        all.first { $0.id == id && $0.kind == kind }
    }

    public static func displayName(for selection: String?, kind: IntegrationAppKind) -> String? {
        let selection = kind == .terminal ? selection ?? defaultTerminalID : selection
        guard let selection else { return nil }
        if selection == ExternalToolSettings.customID { return kind == .terminal ? "Custom Terminal" : "Custom Editor" }
        return definition(id: selection, kind: kind)?.name
    }

    private static func bundle(_ name: String, _ identifiers: [String], _ executable: String) -> ExternalToolBundle {
        ExternalToolBundle(name: name, identifiers: identifiers, executable: executable)
    }

    private static func terminal(_ id: String, _ name: String, _ bundleName: String, _ identifiers: [String], folder: TerminalFolderStyle = .workspace) -> IntegrationAppDefinition {
        IntegrationAppDefinition(id: id, name: name, kind: .terminal, bundles: [bundle(bundleName, identifiers, "")], folder: folder)
    }

    private static func editor(_ id: String, _ name: String, _ bundles: [ExternalToolBundle], commands: [String] = [], line: EditorLineStyle = .none) -> IntegrationAppDefinition {
        IntegrationAppDefinition(id: id, name: name, kind: .editor, bundles: bundles, commands: commands, line: line)
    }
}
