//
//  CloneRepositoryView.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// Clone Git Repository, from the Welcome window: an address, then where to put the
/// project; the cloned folder opens at its main file.
struct CloneRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var isCloning = false
    @State private var cloneTask: Task<Void, Never>?
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clone Git Repository")
                        .font(.headline)
                    Text("From GitHub, GitLab, or the Git address of an Overleaf project.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TextField("Repository Address", text: $address, prompt: Text(verbatim: "https://github.com/user/thesis.git"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .disabled(isCloning)
                .onSubmit(chooseDestination)
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            HStack {
                if isCloning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Cloning…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    if isCloning {
                        cloneTask?.cancel()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
                Button("Clone…") {
                    chooseDestination()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isCloning || !GitCloner.isPlausibleAddress(address))
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    /// Asks where to put the clone, named after the repository.
    private func chooseDestination() {
        guard !isCloning, GitCloner.isPlausibleAddress(address) else { return }
        let panel = NSSavePanel()
        panel.title = String(localized: "Clone Git Repository")
        panel.message = String(localized: "Choose where to put the project folder.")
        panel.prompt = String(localized: "Clone")
        panel.nameFieldLabel = String(localized: "Clone As:")
        panel.nameFieldStringValue = GitCloner.defaultFolderName(for: address)
        panel.canCreateDirectories = true
        let address = address
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            MainActor.assumeIsolated {
                clone(address, into: destination)
            }
        }
    }

    private func clone(_ address: String, into destination: URL) {
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            failure = String(localized: "“\(destination.lastPathComponent)” already exists there. Choose another name.")
            return
        }
        failure = nil
        isCloning = true
        cloneTask = Task {
            let result = await GitCloner.clone(address, into: destination)
            isCloning = false
            cloneTask = nil
            if result.succeeded {
                dismiss()
                ProjectOpener.openProject(at: destination)
                return
            }
            // Don't leave half a clone behind; the folder didn't exist before.
            try? FileManager.default.removeItem(at: destination)
            if !result.wasCancelled {
                failure = GitCloner.failureDescription(for: result)
            }
        }
    }
}
