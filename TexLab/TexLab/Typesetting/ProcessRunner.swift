//
//  ProcessRunner.swift
//  TexLab
//

import Foundation

/// Runs command-line tools without blocking, with cancellation and a time limit.
///
/// Output goes to a file rather than a pipe, so a chatty tool can never stall on a full
/// pipe buffer, and the transcript can be shown to the user afterwards.
nonisolated enum ProcessRunner {
    nonisolated struct Result: Sendable {
        var exitCode: Int32 = 0
        var output = ""
        var wasCancelled = false
        var timedOut = false
        /// Set when the tool couldn't be started at all.
        var launchError: String?

        var succeeded: Bool {
            launchError == nil && !wasCancelled && !timedOut && exitCode == 0
        }
    }

    static func run(
        _ executable: URL,
        arguments: [String],
        in workingDirectory: URL,
        environment: [String: String],
        outputFile: URL,
        timeout: TimeInterval = 300
    ) async -> Result {
        if Task.isCancelled {
            return Result(wasCancelled: true)
        }

        FileManager.default.createFile(atPath: outputFile.filePath, contents: nil)
        let outputHandle: FileHandle
        do {
            outputHandle = try FileHandle(forWritingTo: outputFile)
        } catch {
            return Result(launchError: error.localizedDescription)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        let control = ProcessControl(process)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Result, Never>) in
                process.terminationHandler = { finished in
                    try? outputHandle.close()
                    let data = (try? Data(contentsOf: outputFile)) ?? Data()
                    continuation.resume(returning: Result(
                        exitCode: finished.terminationStatus,
                        output: String(decoding: data, as: UTF8.self),
                        wasCancelled: control.wasCancelled,
                        timedOut: control.timedOut
                    ))
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    try? outputHandle.close()
                    continuation.resume(returning: Result(launchError: error.localizedDescription))
                    return
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    control.timeOut()
                }
            }
        } onCancel: {
            control.cancel()
        }
    }
}

/// Stops a running process from another thread and remembers why it was stopped.
nonisolated private final class ProcessControl: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var cancelled = false
    private var expired = false

    init(_ process: Process) {
        self.process = process
    }

    var wasCancelled: Bool {
        lock.withLock { cancelled }
    }

    var timedOut: Bool {
        lock.withLock { expired }
    }

    func cancel() {
        lock.withLock { cancelled = true }
        terminate()
    }

    func timeOut() {
        guard process.isRunning else { return }
        lock.withLock { expired = true }
        terminate()
    }

    private func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }
}
