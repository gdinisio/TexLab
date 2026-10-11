//
//  GitCloner.swift
//  TexLab
//

import Foundation

/// Clones a Git repository — from GitHub, GitLab or an Overleaf project — with the git
/// that comes with the Xcode command line tools.
nonisolated enum GitCloner {
    /// The folder name git would choose for a repository address: `thesis` for
    /// `https://github.com/user/thesis.git`.
    static func defaultFolderName(for address: String) -> String {
        var trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        var name = trimmed.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? ""
        if name.lowercased().hasSuffix(".git") {
            name.removeLast(4)
        }
        return name.isEmpty ? String(localized: "Repository") : name
    }

    /// Whether `address` looks like something git can clone.
    static func isPlausibleAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return false }
        let prefixes = ["https://", "http://", "ssh://", "git://", "file://", "git@", "/", "~/"]
        return prefixes.contains { trimmed.lowercased().hasPrefix($0) }
    }

    /// Clones `address` into `destination`, which must not exist yet.
    static func clone(_ address: String, into destination: URL) async -> ProcessRunner.Result {
        var environment = ProcessInfo.processInfo.environment
        // Nobody can type a password into a process without a terminal; fail at once
        // instead, and let the keychain supply saved passwords.
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
        let transcript = FileManager.default.temporaryDirectory.appending(path: "TexLab-clone-\(UUID().uuidString).log")
        defer {
            try? FileManager.default.removeItem(at: transcript)
        }
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return await ProcessRunner.run(
            URL(filePath: "/usr/bin/git"),
            // "--" keeps an address that starts with a dash from being read as an option.
            arguments: ["clone", "--", (address as NSString).expandingTildeInPath, destination.path(percentEncoded: false)],
            in: destination.deletingLastPathComponent(),
            environment: environment,
            outputFile: transcript,
            timeout: 900
        )
    }

    /// Why cloning failed, in words, from git's output.
    static func failureDescription(for result: ProcessRunner.Result) -> String {
        if result.launchError != nil {
            return String(localized: "Git couldn’t be started. Install the Xcode command line tools by running “xcode-select --install” in Terminal.")
        }
        if result.timedOut {
            return String(localized: "Cloning took too long and was stopped.")
        }
        let output = result.output
        let lowercased = output.lowercased()
        if lowercased.contains("xcrun") || lowercased.contains("xcode-select") || lowercased.contains("active developer path") {
            return String(localized: "Git needs the Xcode command line tools. Install them by running “xcode-select --install” in Terminal, then try again.")
        }
        if lowercased.contains("could not read username") || lowercased.contains("terminal prompts disabled")
            || lowercased.contains("authentication failed") || lowercased.contains("could not read password") {
            return String(localized: "The server needs a user name and password — for Overleaf, the Git authentication token from your account settings. Clone the project once with git in Terminal so your keychain remembers them, then try again.")
        }
        if lowercased.contains("permission denied (publickey)") || lowercased.contains("host key verification failed") {
            return String(localized: "The server didn’t accept your SSH key. Check that it is added to your account and to ssh-agent, or use the repository’s https address.")
        }
        if lowercased.contains("could not resolve host") || lowercased.contains("couldn't connect") || lowercased.contains("failed to connect") {
            return String(localized: "The server couldn’t be reached. Check the address and your internet connection.")
        }
        if lowercased.contains("not found") || lowercased.contains("does not exist")
            || lowercased.contains("does not appear to be a git repository") {
            return String(localized: "No repository was found at that address, or you don’t have access to it.")
        }
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Cloning into") }
        let message = lines.suffix(2).joined(separator: " ")
            .replacingOccurrences(of: "fatal: ", with: "")
            .replacingOccurrences(of: "error: ", with: "")
        return message.isEmpty ? String(localized: "Git couldn’t clone the repository.") : redactingCredentials(in: message)
    }

    private static let credentialsPattern = try! NSRegularExpression(pattern: #"://[^/@\s]+@"#)

    /// `message` without a user name and password written into an address.
    static func redactingCredentials(in message: String) -> String {
        credentialsPattern.stringByReplacingMatches(
            in: message,
            range: NSRange(location: 0, length: (message as NSString).length),
            withTemplate: "://"
        )
    }
}
