import Foundation

extension Lessons {
    public static let credentialHelpers = """
        Over https, git asks for a username and password. First it asks each credential helper (credential.helper, for example osxkeychain or gh); a credential helper is a small program that answers from its own store. If none answers, git runs the program named in GIT_ASKPASS and reads its answer from standard output. Without either, it would prompt in a terminal, which Mork turns off with GIT_TERMINAL_PROMPT=0.
        When a remote's host matches one of your accounts, Mork runs that one git command with GIT_ASKPASS pointing to a small script, puts the username and token in environment variables of that process only, and clears credential.helper for it, so no helper answers first or keeps a copy. The token never appears in the command line or the console.
        """

    public static let sshKeygen = """
        ssh-keygen -t ed25519 creates a key pair: a private key (the file without an extension) that stays on this Mac, and a public key (.pub) you can hand out. ed25519 keys are short, fast and the current recommendation. -C stores a comment, usually your email, so you recognise the key later. A passphrase encrypts the private key file, so a stolen copy is useless without it.
        """

    public static let sshFingerprint = """
        A fingerprint is a short hash of the public key, shown by ssh-keygen -lf as SHA256:… Websites show the same value next to each key you added, so you can compare them and see which key is which without reading the key itself.
        """

    public static let sshPublicKey = """
        The server stores your public key. When you connect, ssh proves it holds the matching private key by signing a challenge; the server checks the signature with the public key. The private key never leaves this Mac, which is why only the .pub file goes to GitHub or GitLab.
        """
}
