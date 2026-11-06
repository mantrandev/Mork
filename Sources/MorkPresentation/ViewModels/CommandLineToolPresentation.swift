import MorkDomain
import Foundation

struct CommandLineToolPresentation: Equatable {
    let summary: String
    let buttonTitle: String
    let canInstall: Bool
    let caption: String

    init(_ status: CommandLineToolStatus?) {
        switch status {
        case nil:
            summary = "Checking…"
            buttonTitle = "Install"
            canInstall = false
            caption = Self.usage(name: "mork")
        case .unavailable:
            summary = "Not available in this build"
            buttonTitle = "Install"
            canInstall = false
            caption = "The command ships inside Mork.app. Build the app with scripts/build-app.sh and open it from Applications."
        case let .notInstalled(name):
            summary = "Not installed"
            buttonTitle = "Install"
            canInstall = true
            caption = Self.usage(name: name) + " Install links \(name) into /opt/homebrew/bin, /usr/local/bin or ~/.local/bin, the first one Mork can write to."
        case let .installed(name, path, needsPathEntry):
            summary = path
            buttonTitle = "Reinstall"
            canInstall = true
            let folder = (path as NSString).deletingLastPathComponent
            caption = Self.usage(name: name) + (needsPathEntry ? " Add \(folder) to PATH in your shell profile to run \(name) from any folder." : "")
        }
    }

    private static func usage(name: String) -> String {
        "Run \(name) in a terminal to open the repository of the current folder, or \(name) <folder> for another one."
    }
}
