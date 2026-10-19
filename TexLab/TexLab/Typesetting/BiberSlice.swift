//
//  BiberSlice.swift
//  TexLab
//

import Foundation

/// A Biber that starts on any Mac.
///
/// TeX Live's Biber for the Mac is a universal binary that, as it starts, has `lipo`
/// extract the slice for the Mac's processor and runs that. Newer versions of `lipo` take
/// other options, so that fails — "extracting arm64 binary with lipo failed" — and Biber
/// never runs, in TexLab or anywhere else. TexLab then extracts the slice itself, reading
/// the universal binary's header as `lipo -thin` does, and runs the slice, which starts
/// directly. It's kept in TexLab's caches under the original's size and date, so an
/// updated Biber gets a fresh copy.
nonisolated enum BiberSlice {
    /// What Biber prints when its own extraction fails.
    static let failureMarker = "binary with lipo failed"

    /// The folder holding an extracted Biber for `distribution`, if there is one.
    static func existingFolder(for distribution: TeXDistribution) -> URL? {
        guard let folder = folder(for: distribution),
              FileManager.default.isExecutableFile(atPath: folder.appending(path: "biber").filePath) else { return nil }
        return folder
    }

    /// Extracts the slice for this Mac's processor from the distribution's Biber into a
    /// folder of its own, as `biber`, and returns the folder; nil when Biber isn't a
    /// universal binary with such a slice.
    static func extract(for distribution: TeXDistribution) -> URL? {
        if let folder = existingFolder(for: distribution) {
            return folder
        }
        guard let source = distribution.executable("biber"), let folder = folder(for: distribution),
              let slice = try? slice(of: source.resolvingSymlinksInPath(), cpuType: nativeCPUType) else { return nil }
        let fileManager = FileManager.default
        let destination = folder.appending(path: "biber")
        // Copies made for Biber versions since replaced.
        let parent = folder.deletingLastPathComponent()
        for old in (try? fileManager.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        where old.lastPathComponent != folder.lastPathComponent {
            try? fileManager.removeItem(at: old)
        }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            // Written aside and moved into place, so a window typesetting at the same time
            // never runs half a file.
            let partial = folder.appending(path: "biber-\(UUID().uuidString).partial")
            try slice.write(to: partial)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: partial.filePath)
            do {
                try fileManager.moveItem(at: partial, to: destination)
            } catch {
                try? fileManager.removeItem(at: partial)
                guard fileManager.isExecutableFile(atPath: destination.filePath) else { throw error }
            }
            return folder
        } catch {
            return nil
        }
    }

    // MARK: - Universal binaries

    /// The slice of a universal binary for `cpuType`, byte for byte as `lipo -thin` writes
    /// it; nil for a file that isn't a universal binary or has no such slice.
    ///
    /// A universal binary starts with a big-endian header — its magic number and how many
    /// slices it has — then, for each slice, its processor type and subtype, and where it
    /// is in the file: 32-bit offsets and sizes with `FAT_MAGIC`, 64-bit with
    /// `FAT_MAGIC_64`.
    static func slice(of url: URL, cpuType: Int32) throws -> Data? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 8), header.count == 8 else { return nil }
        let magic = header.bigEndianUInt32(at: 0)
        guard magic == 0xCAFE_BABE || magic == 0xCAFE_BABF else { return nil }
        let is64Bit = magic == 0xCAFE_BABF
        let count = Int(header.bigEndianUInt32(at: 4))
        // Java class files start with the same magic number, then a version far above this.
        guard count > 0, count < 32 else { return nil }
        let entrySize = is64Bit ? 32 : 20
        guard let table = try handle.read(upToCount: count * entrySize), table.count == count * entrySize else { return nil }
        for index in 0..<count {
            let entry = index * entrySize
            guard Int32(bitPattern: table.bigEndianUInt32(at: entry)) == cpuType else { continue }
            let offset = is64Bit ? table.bigEndianUInt64(at: entry + 8) : UInt64(table.bigEndianUInt32(at: entry + 8))
            let size = is64Bit ? table.bigEndianUInt64(at: entry + 16) : UInt64(table.bigEndianUInt32(at: entry + 12))
            guard size > 0, size < UInt64(Int.max) else { return nil }
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: Int(size)), data.count == Int(size) else { return nil }
            return data
        }
        return nil
    }

    /// `CPU_TYPE_ARM64` or `CPU_TYPE_X86_64`: the processor TexLab runs on, whose slice
    /// macOS would pick.
    private static var nativeCPUType: Int32 {
        #if arch(arm64)
        return 0x0100_000C
        #else
        return 0x0100_0007
        #endif
    }

    private static var nativeArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    /// Where the slice of the distribution's Biber goes, named after the processor and the
    /// original's size and date.
    private static func folder(for distribution: TeXDistribution) -> URL? {
        guard let source = distribution.executable("biber"),
              let attributes = try? FileManager.default.attributesOfItem(atPath: source.resolvingSymlinksInPath().filePath),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              let date = attributes[.modificationDate] as? Date else { return nil }
        let name = "biber-\(nativeArchitecture)-\(size)-\(Int(date.timeIntervalSince1970))"
        return BuildNaming.buildRoot.deletingLastPathComponent()
            .appending(path: "Tools", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
    }
}

private extension Data {
    func bigEndianUInt32(at offset: Int) -> UInt32 {
        self[(startIndex + offset)..<(startIndex + offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
    }

    func bigEndianUInt64(at offset: Int) -> UInt64 {
        self[(startIndex + offset)..<(startIndex + offset + 8)].reduce(0) { $0 << 8 | UInt64($1) }
    }
}
