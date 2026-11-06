import Foundation

public enum ExternalToolCommand {
    public static func merge(_ launch: ExternalToolLaunch, trustsExitCode: Bool, path: String) -> [String] {
        let tool = launch.tool
        return ["-c", setting(of: launch, section: "mergetool"),
                "-c", "mergetool.\(tool).trustExitCode=\(trustsExitCode)",
                "-c", "mergetool.keepBackup=false",
                "--literal-pathspecs",
                "mergetool", "--no-prompt", "--tool=\(tool)",
                "--", path]
    }

    public static func diff(_ launch: ExternalToolLaunch, revisions: [String], path: String) -> [String] {
        ["-c", setting(of: launch, section: "difftool"),
         "--literal-pathspecs",
         "difftool", "--no-prompt", "--tool=\(launch.tool)"]
            + revisions
            + ["--", path]
    }

    public static func preview(_ arguments: [String]) -> String {
        (["git"] + arguments.dropLast().map(ShellWords.quote) + ["<file>"]).joined(separator: " ")
    }

    private static func setting(of launch: ExternalToolLaunch, section: String) -> String {
        switch launch {
        case let .backend(tool, path): "\(section).\(tool).path=\(path)"
        case let .command(tool, command): "\(section).\(tool).cmd=\(command)"
        }
    }
}
