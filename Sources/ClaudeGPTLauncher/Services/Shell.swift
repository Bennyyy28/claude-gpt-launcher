import Foundation

enum ShellError: LocalizedError {
    case launchFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message), .commandFailed(let message): message
        }
    }
}

struct ShellResult {
    let output: String
    let error: String
    let status: Int32
}

enum Shell {
    static func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()
        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

        return ShellResult(
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self),
            status: process.terminationStatus
        )
    }
}
