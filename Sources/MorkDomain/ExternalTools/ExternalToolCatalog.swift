import Foundation

public enum ExternalToolCatalog {
    public static let all: [ExternalToolDefinition] = [
        ExternalToolDefinition(
            id: "bc",
            name: "Beyond Compare",
            bundles: [ExternalToolBundle(name: "Beyond Compare.app", identifiers: ["com.ScooterSoftware.BeyondCompare"], executable: "Contents/MacOS/bcomp")],
            commands: ["bcomp", "bcompare"]
        ),
        ExternalToolDefinition(
            id: "opendiff",
            name: "FileMerge",
            bundles: [ExternalToolBundle(name: "Xcode.app", identifiers: ["com.apple.dt.Xcode"], executable: "Contents/Developer/usr/bin/opendiff")],
            commands: ["opendiff"]
        ),
        ExternalToolDefinition(
            id: "kaleidoscope",
            name: "Kaleidoscope",
            bundles: [
                ExternalToolBundle(
                    name: "Kaleidoscope.app",
                    identifiers: ["app.kaleidoscope.v4", "app.kaleidoscope.v3", "com.blackpixel.kaleidoscope"],
                    executable: "Contents/Resources/bin/ksdiff"
                )
            ],
            commands: ["ksdiff"],
            mergeArguments: #"--merge --output "$MERGED" --base "$BASE" -- "$LOCAL" --snapshot "$REMOTE" --snapshot"#,
            diffArguments: #"--partial-changeset --relative-path "$MERGED" -- "$LOCAL" "$REMOTE""#
        ),
        ExternalToolDefinition(
            id: "p4merge",
            name: "P4Merge",
            bundles: [ExternalToolBundle(name: "p4merge.app", identifiers: ["com.perforce.p4merge"], executable: "Contents/Resources/launchp4merge")],
            commands: ["p4merge"]
        ),
        ExternalToolDefinition(
            id: "vscode",
            name: "Visual Studio Code",
            bundles: [ExternalToolBundle(name: "Visual Studio Code.app", identifiers: ["com.microsoft.VSCode"], executable: "Contents/Resources/app/bin/code")],
            commands: ["code"]
        ),
        ExternalToolDefinition(
            id: "smerge",
            name: "Sublime Merge",
            bundles: [ExternalToolBundle(name: "Sublime Merge.app", identifiers: ["com.sublimemerge"], executable: "Contents/SharedSupport/bin/smerge")],
            commands: ["smerge"]
        ),
        ExternalToolDefinition(
            id: "kdiff3",
            name: "KDiff3",
            bundles: [ExternalToolBundle(name: "kdiff3.app", identifiers: ["org.kde.kdiff3"], executable: "Contents/MacOS/kdiff3")],
            commands: ["kdiff3"]
        ),
        ExternalToolDefinition(
            id: "diffmerge",
            name: "DiffMerge",
            bundles: [ExternalToolBundle(name: "DiffMerge.app", identifiers: ["com.sourcegear.DiffMerge"], executable: "Contents/MacOS/DiffMerge")],
            commands: ["diffmerge"]
        ),
        ExternalToolDefinition(
            id: "araxis",
            name: "Araxis Merge",
            bundles: [ExternalToolBundle(name: "Araxis Merge.app", identifiers: ["com.araxis.merge"], executable: "Contents/Utilities/compare")],
            commands: []
        ),
        ExternalToolDefinition(
            id: "meld",
            name: "Meld",
            bundles: [ExternalToolBundle(name: "Meld.app", identifiers: ["org.gnome.meld"], executable: "Contents/MacOS/Meld")],
            commands: ["meld"]
        )
    ]

    public static func definition(id: String) -> ExternalToolDefinition? {
        all.first { $0.id == id }
    }

    public static func displayName(for selection: String?) -> String? {
        guard let selection else { return nil }
        if selection == ExternalToolSettings.customID { return "Custom Tool" }
        return definition(id: selection)?.name
    }
}
