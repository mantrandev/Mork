import Foundation

extension Lessons {
    static let configKeys: [String: String] = [
        "commit.template": "commit.template: a file whose text prefills every new commit message; Mork puts it into the empty composer, and lines starting with the comment character are removed when you commit, exactly like git does in its editor",
        "core.commentchar": "core.commentChar: the character that starts a comment line in a commit message (# by default); those lines never end up in the commit",
        "commit.gpgsign": "commit.gpgsign: true signs every commit git creates (commit, amend, merge, cherry-pick, revert, rebase), so others can check it really comes from you",
        "gpg.format": "gpg.format: which tool signs: openpgp (gpg, the default) or ssh (ssh-keygen with an SSH key, no gpg needed)",
        "user.signingkey": "user.signingkey: the key that signs; a gpg key ID or fingerprint for openpgp, the path to a public key (.pub) for ssh",
        "gpg.ssh.allowedsignersfile": "gpg.ssh.allowedSignersFile: a file listing the SSH keys you trust (\"email key-type key\" per line); git needs it to verify SSH signatures"
    ]

    static let signatureFormat = "%G?: signature status: G good, B bad, U good but untrusted key, X or Y expired, R revoked key, E cannot check (missing key), N not signed. %GS is the signer, %GK the key"

    static func commitNotes(_ arguments: [String], subcommand: String) -> [String] {
        var notes: [String] = []
        if subcommand == "config" {
            notes += Set(arguments.map { $0.lowercased() }).compactMap { configKeys[$0] }
        }
        if arguments.contains(where: { $0.contains("%G") }) {
            notes.append(signatureFormat)
        }
        return notes
    }
}

extension Lessons {
    public static let customShellCommand = """
        A custom shell command from Settings ▸ Custom Commands. Mork runs it with /bin/sh -c in the repository root and shows everything it prints here. ${repo}, ${branch}, ${sha}, ${file} and ${remote} were replaced by quoted values first, so a branch or file name can never run as code. Git commands inside it are not explained one by one; add the command as a Git command to get a lesson for it.
        """
}
