//
//  FileOperations.swift
//  TexLab
//

import Foundation

/// Changes to project files that open documents follow.
nonisolated enum FileOperations {
    /// Moves or renames a file or folder through file coordination, which tells the
    /// documents open on it — in TexLab or another app — where it went. Coordination waits
    /// for those documents, so it runs away from the main thread they answer on.
    static func move(_ source: URL, to destination: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            try coordinatedMove(source, to: destination)
        }.value
    }

    private static func coordinatedMove(_ source: URL, to destination: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var moveError: Error?
        coordinator.coordinate(
            writingItemAt: source,
            options: .forMoving,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError
        ) { from, to in
            do {
                coordinator.item(at: from, willMoveTo: to)
                try FileManager.default.moveItem(at: from, to: to)
                coordinator.item(at: from, didMoveTo: to)
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError {
            throw error
        }
    }
}
