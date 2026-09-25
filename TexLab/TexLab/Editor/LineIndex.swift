//
//  LineIndex.swift
//  TexLab
//

import Foundation

/// Maps between character offsets and line numbers.
///
/// The index is updated incrementally from text storage edits, so finding the line of the
/// insertion point or drawing line numbers never rescans the whole document.
final class LineIndex {
    /// The UTF-16 offset at which each line starts. Always begins with 0.
    private(set) var lineStarts: [Int] = [0]

    var lineCount: Int { lineStarts.count }

    func rebuild(from string: NSString) {
        lineStarts = [0] + Self.lineBreaks(in: string, range: NSRange(location: 0, length: string.length))
    }

    /// Updates the index after the characters in `editedRange` (in the new text) replaced
    /// text whose length differed by `delta`.
    func update(from string: NSString, editedRange: NSRange, changeInLength delta: Int) {
        let editStart = editedRange.location
        let oldEditEnd = NSMaxRange(editedRange) - delta
        // Line starts that followed a line break inside the replaced text are recomputed.
        let firstRemoved = firstIndex(after: editStart)
        let firstKept = max(firstRemoved, firstIndex(after: oldEditEnd))

        var updated = Array(lineStarts[..<firstRemoved])
        updated.append(contentsOf: Self.lineBreaks(in: string, range: editedRange))
        for start in lineStarts[firstKept...] {
            updated.append(start + delta)
        }
        lineStarts = updated
    }

    /// The 1-based line number containing `location`.
    func lineNumber(at location: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= location {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low + 1
    }

    /// The offset at which the 1-based `line` starts, clamped to the document.
    func startOfLine(_ line: Int) -> Int {
        lineStarts[min(max(line, 1), lineStarts.count) - 1]
    }

    /// The index of the first line start greater than `location`.
    private func firstIndex(after location: Int) -> Int {
        var low = 0
        var high = lineStarts.count
        while low < high {
            let middle = (low + high) / 2
            if lineStarts[middle] <= location {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    /// Offsets just after each line feed in `range`.
    nonisolated static func lineBreaks(in string: NSString, range: NSRange) -> [Int] {
        var breaks: [Int] = []
        let chunkSize = 4096
        var buffer = [unichar](repeating: 0, count: chunkSize)
        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            let count = min(chunkSize, end - location)
            string.getCharacters(&buffer, range: NSRange(location: location, length: count))
            for offset in 0..<count where buffer[offset] == 0x0A {
                breaks.append(location + offset + 1)
            }
            location += count
        }
        return breaks
    }
}
