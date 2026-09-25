//
//  SyncTeX.swift
//  TexLab
//

import Foundation

/// A place in the PDF that corresponds to a source line.
nonisolated struct SyncTeXLocation: Sendable {
    /// The 0-based page index.
    var pageIndex: Int
    /// The area to highlight, in PDF points measured from the page's top-left corner.
    var rect: CGRect
}

/// A source line that corresponds to a place in the PDF.
nonisolated struct SyncTeXSourcePoint: Sendable {
    /// The canonical path of the source file.
    var path: String
    var line: Int
}

/// SyncTeX data for a typeset document, linking source lines and PDF positions in both
/// directions.
///
/// TexLab asks TeX for uncompressed SyncTeX output (`-synctex=-1`) and reads it with a
/// small byte-level parser, so navigation doesn't depend on the `synctex` tool.
nonisolated struct SyncTeXData: Sendable {
    nonisolated enum NodeKind: UInt8, Sendable {
        case vbox, hbox, voidVBox, voidHBox, current, glue, kern, math, rule

        /// Records that mark a position inside a line rather than a box.
        var isPositionRecord: Bool {
            switch self {
            case .current, .glue, .kern, .math, .rule: true
            default: false
            }
        }
    }

    nonisolated struct Node: Sendable {
        var kind: NodeKind
        var tag: Int32
        var line: Int32
        var h: Float
        var v: Float
        var width: Float
        var height: Float
        var depth: Float
        var parent: Int32
        var page: Int32

        /// The node's box, in PDF points from the page's top-left corner.
        var rect: CGRect {
            CGRect(x: CGFloat(h), y: CGFloat(v - height), width: CGFloat(width), height: CGFloat(height + depth))
        }
    }

    /// Canonical paths of the input files, by SyncTeX tag.
    private(set) var inputs: [Int32: String]
    private(set) var nodes: [Node]
    /// Node indices for each 1-based page.
    private(set) var pages: [Int32: Range<Int>]
    /// Node indices sorted by tag and line, for forward search.
    private let lineOrder: [Int32]
    /// Tags of files the user edits, excluding generated files such as `.bbl`.
    private let editableTags: Set<Int32>

    // MARK: - Loading

    /// Loads `job.synctex`, or `job.synctex.gz` if a configuration compressed it.
    static func load(buildDirectory: URL, jobName: String, workingDirectory: URL? = nil) -> SyncTeXData? {
        let plain = buildDirectory.appending(path: "\(jobName).synctex")
        if let data = try? Data(contentsOf: plain) {
            return SyncTeXData(data: data, workingDirectory: workingDirectory)
        }
        let compressed = buildDirectory.appending(path: "\(jobName).synctex.gz")
        if let data = try? Data(contentsOf: compressed), let inflated = Gzip.decompress(data) {
            return SyncTeXData(data: inflated, workingDirectory: workingDirectory)
        }
        return nil
    }

    init?(data: Data, workingDirectory: URL?) {
        var parser = SyncTeXParser()
        data.withUnsafeBytes { raw in
            parser.parse(raw.bindMemory(to: UInt8.self))
        }
        guard !parser.nodes.isEmpty else { return nil }

        var inputs: [Int32: String] = [:]
        for (tag, path) in parser.inputs {
            let url = path.hasPrefix("/") || workingDirectory == nil
                ? URL(filePath: path)
                : workingDirectory!.appending(path: path)
            inputs[tag] = SourceMap.canonicalPath(url)
        }
        self.inputs = inputs
        nodes = parser.nodes
        pages = parser.pages

        let generatedExtensions: Set<String> = ["aux", "bbl", "gls", "glo", "ind", "idx", "lof", "lot", "nav", "out", "snm", "toc"]
        editableTags = Set(inputs.compactMap { tag, path in
            generatedExtensions.contains((path as NSString).pathExtension.lowercased()) ? nil : tag
        })

        let allNodes = parser.nodes
        lineOrder = allNodes.indices
            .filter { allNodes[$0].page > 0 && allNodes[$0].line > 0 }
            .sorted { lhs, rhs in
                let a = allNodes[lhs]
                let b = allNodes[rhs]
                return (a.tag, a.line, a.page) < (b.tag, b.line, b.page)
            }
            .map { Int32($0) }
    }

    // MARK: - Forward search

    /// The place in the PDF produced by `line` of the file at one of `paths`. When a line
    /// produced nothing (a blank line or a comment) the nearest line that did is used.
    func location(forLine line: Int, inFileAt paths: [String]) -> SyncTeXLocation? {
        let tags = inputs.filter { paths.contains($0.value) }.map { $0.key }
        guard !tags.isEmpty else { return nil }
        for offset in [0, 1, 2, 3, 4, 5, 6, 7, 8, -1, -2, -3, -4, -5] {
            let target = line + offset
            guard target > 0 else { continue }
            var matches: [Int] = []
            for tag in tags {
                matches += nodeIndices(tag: tag, line: Int32(target))
            }
            if let location = location(covering: matches) {
                return location
            }
        }
        return nil
    }

    private func nodeIndices(tag: Int32, line: Int32) -> [Int] {
        var low = 0
        var high = lineOrder.count
        while low < high {
            let middle = (low + high) / 2
            let node = nodes[Int(lineOrder[middle])]
            if (node.tag, node.line) < (tag, line) {
                low = middle + 1
            } else {
                high = middle
            }
        }
        var result: [Int] = []
        var index = low
        while index < lineOrder.count {
            let node = nodes[Int(lineOrder[index])]
            guard node.tag == tag && node.line == line else { break }
            result.append(Int(lineOrder[index]))
            index += 1
        }
        return result
    }

    /// The union of the lines containing `matches` on the first page they appear.
    private func location(covering matches: [Int]) -> SyncTeXLocation? {
        guard let page = matches.map({ nodes[$0].page }).min() else { return nil }
        var rects: [CGRect] = []
        for index in matches where nodes[index].page == page && nodes[index].kind.isPositionRecord {
            let parent = Int(nodes[index].parent)
            if parent >= 0 && nodes[parent].kind == .hbox {
                rects.append(nodes[parent].rect)
            } else {
                let node = nodes[index]
                rects.append(CGRect(x: CGFloat(node.h), y: CGFloat(node.v) - 10, width: 1, height: 12))
            }
        }
        if rects.isEmpty {
            // Box records name the line a paragraph ended on, so only use them as a fallback.
            rects = matches.filter { nodes[$0].page == page }.map { nodes[$0].rect }
        }
        guard var union = rects.first else { return nil }
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        return SyncTeXLocation(pageIndex: Int(page) - 1, rect: union)
    }

    // MARK: - Inverse search

    /// The source line that produced the text at `point` (PDF points from the page's
    /// top-left corner) on the 0-based `pageIndex`.
    func sourcePoint(pageIndex: Int, point: CGPoint) -> SyncTeXSourcePoint? {
        guard let range = pages[Int32(pageIndex + 1)] else { return nil }

        var leavesByBox: [Int: [Int]] = [:]
        var boxes: [Int] = []
        for index in range {
            let node = nodes[index]
            if node.kind == .hbox {
                boxes.append(index)
            } else if node.kind.isPositionRecord, node.parent >= 0, editableTags.contains(node.tag) {
                leavesByBox[Int(node.parent), default: []].append(index)
            }
        }
        let candidates = boxes.filter { leavesByBox[$0] != nil || editableTags.contains(nodes[$0].tag) }
        guard !candidates.isEmpty else { return nil }

        let containing = candidates.filter { nodes[$0].rect.insetBy(dx: -1, dy: -1).contains(point) }
        let box: Int
        if let smallest = containing.min(by: { area(of: $0) < area(of: $1) }) {
            box = smallest
        } else {
            box = candidates.min { distance(from: point, to: $0) < distance(from: point, to: $1) } ?? candidates[0]
        }

        var node = nodes[box]
        if let leaves = leavesByBox[box],
           let nearest = leaves.min(by: { abs(CGFloat(nodes[$0].h) - point.x) < abs(CGFloat(nodes[$1].h) - point.x) }) {
            node = nodes[nearest]
        }
        guard let path = inputs[node.tag], node.line > 0 else { return nil }
        return SyncTeXSourcePoint(path: path, line: Int(node.line))
    }

    private func area(of index: Int) -> CGFloat {
        let rect = nodes[index].rect
        return rect.width * rect.height
    }

    /// Vertical distance first, then horizontal, so the nearest line wins.
    private func distance(from point: CGPoint, to index: Int) -> (CGFloat, CGFloat) {
        let rect = nodes[index].rect
        let dy = point.y < rect.minY ? rect.minY - point.y : max(point.y - rect.maxY, 0)
        let dx = point.x < rect.minX ? rect.minX - point.x : max(point.x - rect.maxX, 0)
        return (dy, dx)
    }
}

/// Reads the SyncTeX text format a byte at a time.
nonisolated private struct SyncTeXParser {
    var inputs: [Int32: String] = [:]
    var nodes: [SyncTeXData.Node] = []
    var pages: [Int32: Range<Int>] = [:]

    private var unit = 1.0
    private var magnification = 1000.0
    private var xOffset = 0.0
    private var yOffset = 0.0
    private var inContent = false
    private var page: Int32 = 0
    private var pageStart = 0
    private var boxStack: [Int32] = []

    /// Scaled points per PostScript point: 65536 × 72.27 / 72.
    private static let scaledPointsPerPoint = 65781.76

    mutating func parse(_ bytes: UnsafeBufferPointer<UInt8>) {
        var start = 0
        let count = bytes.count
        while start < count {
            var end = start
            while end < count && bytes[end] != 0x0A {
                end += 1
            }
            if end > start, !parseLine(bytes, start, end) {
                break
            }
            start = end + 1
        }
        closePage()
    }

    /// Returns false at the end of the content.
    private mutating func parseLine(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> Bool {
        if matches(bytes, start, end, "Input:") {
            var position = start + 6
            let tag = Int32(truncatingIfNeeded: readInteger(bytes, &position, end) ?? 0)
            if position < end && bytes[position] == UInt8(ascii: ":") {
                position += 1
                inputs[tag] = String(decoding: UnsafeBufferPointer(rebasing: bytes[position..<end]), as: UTF8.self)
            }
            return true
        }
        guard inContent else {
            if matches(bytes, start, end, "Content:") {
                inContent = true
            } else if matches(bytes, start, end, "Unit:") {
                unit = headerValue(bytes, start + 5, end) ?? 1
            } else if matches(bytes, start, end, "Magnification:") {
                magnification = headerValue(bytes, start + 14, end) ?? 1000
            } else if matches(bytes, start, end, "X Offset:") {
                xOffset = headerValue(bytes, start + 9, end) ?? 0
            } else if matches(bytes, start, end, "Y Offset:") {
                yOffset = headerValue(bytes, start + 9, end) ?? 0
            }
            return true
        }
        if matches(bytes, start, end, "Postamble:") {
            return false
        }

        switch bytes[start] {
        case UInt8(ascii: "{"):
            closePage()
            var position = start + 1
            page = Int32(truncatingIfNeeded: readInteger(bytes, &position, end) ?? 0)
            pageStart = nodes.count
            boxStack.removeAll(keepingCapacity: true)
        case UInt8(ascii: "}"):
            closePage()
        case UInt8(ascii: "]"), UInt8(ascii: ")"):
            _ = boxStack.popLast()
        case UInt8(ascii: "["):
            addNode(.vbox, bytes, start, end, opensBox: true)
        case UInt8(ascii: "("):
            addNode(.hbox, bytes, start, end, opensBox: true)
        case UInt8(ascii: "v"):
            addNode(.voidVBox, bytes, start, end, opensBox: false)
        case UInt8(ascii: "h"):
            addNode(.voidHBox, bytes, start, end, opensBox: false)
        case UInt8(ascii: "x"):
            addNode(.current, bytes, start, end, opensBox: false)
        case UInt8(ascii: "g"):
            addNode(.glue, bytes, start, end, opensBox: false)
        case UInt8(ascii: "k"):
            addNode(.kern, bytes, start, end, opensBox: false)
        case UInt8(ascii: "$"):
            addNode(.math, bytes, start, end, opensBox: false)
        case UInt8(ascii: "r"):
            addNode(.rule, bytes, start, end, opensBox: false)
        default:
            break
        }
        return true
    }

    private mutating func closePage() {
        if page > 0 {
            pages[page] = pageStart..<nodes.count
        }
        page = 0
    }

    /// Parses `tag,line[,column]:h,v[:width[,height,depth]]`.
    private mutating func addNode(_ kind: SyncTeXData.NodeKind, _ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int, opensBox: Bool) {
        guard page > 0 else { return }
        var position = start + 1
        guard let tag = readInteger(bytes, &position, end), skip(",", bytes, &position, end),
              let line = readInteger(bytes, &position, end) else { return }
        if position < end && bytes[position] == UInt8(ascii: ",") {
            position += 1
            _ = readInteger(bytes, &position, end)
        }
        guard skip(":", bytes, &position, end), let h = readInteger(bytes, &position, end),
              skip(",", bytes, &position, end), let v = readInteger(bytes, &position, end) else { return }

        var width = 0
        var height = 0
        var depth = 0
        if skip(":", bytes, &position, end), let value = readInteger(bytes, &position, end) {
            width = value
            if skip(",", bytes, &position, end), let value = readInteger(bytes, &position, end) {
                height = value
                if skip(",", bytes, &position, end), let value = readInteger(bytes, &position, end) {
                    depth = value
                }
            }
        }

        let scale = unit * magnification / 1000 / Self.scaledPointsPerPoint
        nodes.append(SyncTeXData.Node(
            kind: kind,
            tag: Int32(truncatingIfNeeded: tag),
            line: Int32(truncatingIfNeeded: line),
            h: Float((Double(h) + xOffset) * scale),
            v: Float((Double(v) + yOffset) * scale),
            width: Float(Double(width) * scale),
            height: Float(Double(height) * scale),
            depth: Float(Double(depth) * scale),
            parent: boxStack.last ?? -1,
            page: page
        ))
        if opensBox {
            boxStack.append(Int32(nodes.count - 1))
        }
    }

    // MARK: - Byte helpers

    private func matches(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int, _ prefix: StaticString) -> Bool {
        let length = prefix.utf8CodeUnitCount
        guard end - start >= length else { return false }
        let pointer = prefix.utf8Start
        for offset in 0..<length where bytes[start + offset] != pointer[offset] {
            return false
        }
        return true
    }

    private func headerValue(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> Double? {
        Double(String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self).trimmingCharacters(in: .whitespaces))
    }

    private func skip(_ character: Unicode.Scalar, _ bytes: UnsafeBufferPointer<UInt8>, _ position: inout Int, _ end: Int) -> Bool {
        guard position < end, bytes[position] == UInt8(ascii: character) else { return false }
        position += 1
        return true
    }

    private func readInteger(_ bytes: UnsafeBufferPointer<UInt8>, _ position: inout Int, _ end: Int) -> Int? {
        var negative = false
        if position < end && bytes[position] == UInt8(ascii: "-") {
            negative = true
            position += 1
        }
        let digitsStart = position
        var value = 0
        while position < end {
            let byte = bytes[position]
            guard byte >= 0x30 && byte <= 0x39 else { break }
            value = value &* 10 &+ Int(byte - 0x30)
            position += 1
        }
        guard position > digitsStart else { return nil }
        return negative ? -value : value
    }
}

/// Minimal gzip support for SyncTeX files compressed by a user's configuration.
nonisolated enum Gzip {
    static func decompress(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 else { return nil }
        let flags = bytes[3]
        var position = 10
        if flags & 0x04 != 0 {
            guard position + 2 <= bytes.count else { return nil }
            position += 2 + Int(bytes[position]) + Int(bytes[position + 1]) << 8
        }
        if flags & 0x08 != 0 {
            while position < bytes.count && bytes[position] != 0 { position += 1 }
            position += 1
        }
        if flags & 0x10 != 0 {
            while position < bytes.count && bytes[position] != 0 { position += 1 }
            position += 1
        }
        if flags & 0x02 != 0 {
            position += 2
        }
        guard position < bytes.count - 8 else { return nil }
        let deflated = Data(bytes[position..<(bytes.count - 8)])
        return try? (deflated as NSData).decompressed(using: .zlib) as Data
    }
}
