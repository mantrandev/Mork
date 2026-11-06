import MorkDomain
import Foundation

public final class AskpassScripts: Sendable {
    public static let gitScriptName = "git-askpass.sh"
    public static let sshScriptName = "ssh-askpass.sh"

    static let gitScript = """
        #!/bin/sh
        prompt=$1
        url=${prompt#*\\'}
        url=${url%%\\'*}
        host=${url#*://}
        host=${host%%/*}
        host=${host##*@}
        host=$(printf '%s' "$host" | /usr/bin/tr '[:upper:]' '[:lower:]')
        i=0
        while [ "$i" -lt "${MORK_ASKPASS_COUNT:-0}" ]; do
          eval "candidate=\\${MORK_ASKPASS_HOST_$i}"
          if [ "$candidate" = "$host" ]; then
            case "$prompt" in
              Username*) eval "printf '%s\\\\n' \\"\\${MORK_ASKPASS_USERNAME_$i}\\"" ;;
              *) eval "printf '%s\\\\n' \\"\\${MORK_ASKPASS_PASSWORD_$i}\\"" ;;
            esac
            exit 0
          fi
          i=$((i + 1))
        done
        exit 1

        """

    static let sshScript = """
        #!/bin/sh
        printf '%s\\n' "$MORK_SSH_PASSPHRASE"

        """

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func gitAskpass() throws -> URL {
        try install(Self.gitScriptName, Self.gitScript)
    }

    public func sshAskpass() throws -> URL {
        try install(Self.sshScriptName, Self.sshScript)
    }

    private func install(_ name: String, _ contents: String) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let file = directory.appendingPathComponent(name)
        let current = try? String(contentsOf: file, encoding: .utf8)
        let mode = (try? manager.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int) ?? nil
        if current != contents || mode != 0o700 {
            try Data(contents.utf8).write(to: file, options: .atomic)
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        }
        return file
    }
}

public enum CredentialEnvironment {
    public static func make(for plan: GitCredentialPlan, askpass: AskpassScripts, inheriting base: [String: String] = ProcessInfo.processInfo.environment) throws -> [String: String] {
        guard !plan.credentials.isEmpty else { return [:] }
        var environment = ProcessRunner.configEnvironment([("credential.helper", "")], inheriting: base)
        environment["GIT_ASKPASS"] = try askpass.gitAskpass().path
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["MORK_ASKPASS_COUNT"] = String(plan.credentials.count)
        for (index, credential) in plan.credentials.enumerated() {
            environment["MORK_ASKPASS_HOST_\(index)"] = credential.host
            environment["MORK_ASKPASS_USERNAME_\(index)"] = credential.username
            environment["MORK_ASKPASS_PASSWORD_\(index)"] = credential.secret
        }
        return environment
    }
}
