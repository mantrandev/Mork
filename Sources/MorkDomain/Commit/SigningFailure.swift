import Foundation

public enum SigningFailure {
    public static func hint(for message: String) -> String? {
        let text = message.lowercased()
        if text.contains("cannot run gpg") {
            return "Signing failed: gpg is not installed or not on PATH. Install GnuPG (brew install gnupg) or set gpg.program, or switch the signing format to SSH in Settings ▸ Git."
        }
        if text.contains("pinentry") || text.contains("inappropriate ioctl") {
            return "Signing failed: gpg-agent cannot ask for your passphrase because pinentry is missing. Install pinentry-mac (brew install pinentry-mac), add \"pinentry-program $(which pinentry-mac)\" to ~/.gnupg/gpg-agent.conf, then run gpgconf --kill gpg-agent."
        }
        if text.contains("gpg:"), text.contains("no secret key") {
            return "Signing failed: gpg has no secret key for user.signingkey. Pick a key listed in Settings ▸ Git, or import yours with gpg --import."
        }
        if text.contains("gpg failed to sign the data") {
            return "Signing failed: gpg could not sign the commit. Check that gpg-agent is running and that user.signingkey names one of your secret keys (gpg --list-secret-keys). If gpg needs a passphrase, pinentry-mac must be installed."
        }
        if text.contains("either user.signingkey or gpg.ssh.defaultkeycommand needs to be configured") {
            return "Signing failed: SSH signing needs a key. Choose your public key (.pub) as the signing key in Settings ▸ Git."
        }
        if text.contains("couldn't load public key") {
            return "Signing failed: user.signingkey must point to an existing SSH public key (.pub) file, with its private key next to it or loaded in ssh-agent."
        }
        if text.contains("incorrect passphrase") || text.contains("agent refused operation") || text.contains("couldn't sign message") {
            return "Signing failed: ssh-keygen could not use your private key. Mork cannot type a passphrase, so load the key into ssh-agent first: ssh-add --apple-use-keychain <private key>."
        }
        return nil
    }
}
