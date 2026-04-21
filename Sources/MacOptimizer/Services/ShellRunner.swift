import Foundation

class ShellRunner {
    static let shared = ShellRunner()

    /// Run a shell command and return stdout as a trimmed string.
    func run(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError  = Pipe()

            process.terminationHandler = { _ in
                let data   = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a command with macOS administrator privileges via osascript.
    func runWithAdmin(_ command: String) async throws -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError  = Pipe()

            process.terminationHandler = { _ in
                let data   = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Returns the disk usage of a path in bytes (using `du -sk`).
    func directorySize(at path: String) async -> Int64 {
        guard let output = try? await run("du -sk '\(path)' 2>/dev/null | awk '{print $1}'"),
              let kb = Int64(output) else { return 0 }
        return kb * 1024
    }
}
