import Foundation

enum TextEncoding: String, CaseIterable {
    case utf8 = "UTF-8", utf8BOM = "UTF-8 with BOM"
    case utf16LE = "UTF-16 LE with BOM", utf16BE = "UTF-16 BE with BOM"
    case windows1252 = "Windows-1252"
}

enum TextError: LocalizedError {
    case invalidEncoding, unrepresentable, binary
    var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "The file is not valid Unicode in the detected encoding. Choose Windows-1252 only if this is a legacy text file."
        case .unrepresentable: return "Windows-1252 cannot represent all these characters. Choose UTF-8 in Format → Encoding and save again. Your text has not been changed."
        case .binary: return "This file contains null characters and appears to contain unsupported binary content."
        }
    }
}

struct TextFile {
    var text: String
    var encoding: TextEncoding
    // The explicit table avoids Foundation's platform-dependent legacy codec behavior.
    static let cp1252: [UInt32] = [0x20AC,0x81,0x201A,0x192,0x201E,0x2026,0x2020,0x2021,0x2C6,0x2030,0x160,0x2039,0x152,0x8D,0x17D,0x8F,0x90,0x2018,0x2019,0x201C,0x201D,0x2022,0x2013,0x2014,0x2DC,0x2122,0x161,0x203A,0x153,0x9D,0x17E,0x178]
    static func decode(_ data: Data, legacy: Bool = false) throws -> TextFile {
        let bytes = [UInt8](data)
        var encoding: TextEncoding = .utf8
        var payload = data
        if bytes.starts(with: [0xEF,0xBB,0xBF]) { encoding = .utf8BOM; payload = data.dropFirst(3) }
        else if bytes.starts(with: [0xFF,0xFE]) { encoding = .utf16LE; payload = data.dropFirst(2) }
        else if bytes.starts(with: [0xFE,0xFF]) { encoding = .utf16BE; payload = data.dropFirst(2) }
        else if legacy { encoding = .windows1252 }
        let text: String
        switch encoding {
        case .utf8, .utf8BOM:
            guard let value = String(data: payload, encoding: .utf8) else { throw TextError.invalidEncoding }; text = value
        case .utf16LE, .utf16BE:
            let b = [UInt8](payload)
            guard b.count % 2 == 0 else { throw TextError.invalidEncoding }
            var units: [UInt16] = []
            for i in stride(from: 0, to: b.count, by: 2) {
                units.append(encoding == .utf16LE ? UInt16(b[i]) | UInt16(b[i+1]) << 8 : UInt16(b[i]) << 8 | UInt16(b[i+1]))
            }
            var i = 0
            while i < units.count {
                let u = units[i]
                if (0xD800...0xDBFF).contains(u) {
                    guard i+1 < units.count, (0xDC00...0xDFFF).contains(units[i+1]) else { throw TextError.invalidEncoding }; i += 2
                } else {
                    guard !(0xDC00...0xDFFF).contains(u) else { throw TextError.invalidEncoding }; i += 1
                }
            }
            text = String(decoding: units, as: UTF16.self)
        case .windows1252:
            text = String(String.UnicodeScalarView(bytes.map { UnicodeScalar((0x80...0x9F).contains($0) ? cp1252[Int($0)-0x80] : UInt32($0))! }))
        }
        guard !text.unicodeScalars.contains(where: { $0.value == 0 }) else { throw TextError.binary }
        return TextFile(text: text, encoding: encoding)
    }
    func data() throws -> Data {
        switch encoding {
        case .utf8: return Data(text.utf8)
        case .utf8BOM: return Data([0xEF,0xBB,0xBF]) + Data(text.utf8)
        case .utf16LE, .utf16BE:
            var data = Data(encoding == .utf16LE ? [0xFF,0xFE] : [0xFE,0xFF])
            for u in text.utf16 {
                let lo = UInt8(u & 255), hi = UInt8(u >> 8)
                data.append(contentsOf: encoding == .utf16LE ? [lo,hi] : [hi,lo])
            }; return data
        case .windows1252:
            var data = Data()
            for scalar in text.unicodeScalars {
                let v = scalar.value
                if v < 0x80 || (0xA0...0xFF).contains(v) { data.append(UInt8(v)) }
                else if let i = Self.cp1252.firstIndex(of: v) { data.append(UInt8(i + 0x80)) }
                else { throw TextError.unrepresentable }
            }; return data
        }
    }
}

enum LineEnding: String, CaseIterable {
    case lf = "LF", crlf = "CRLF", cr = "CR", mixed = "Mixed"
    var separator: String { switch self { case .crlf: return "\r\n"; case .cr: return "\r"; default: return "\n" } }
    static func detect(_ text: String) -> LineEnding {
        let units = Array(text.utf16)
        var kinds = Set<String>(); var i = 0
        while i < units.count {
            if units[i] == 13 {
                if i+1 < units.count && units[i+1] == 10 { kinds.insert("CRLF"); i += 1 }
                else { kinds.insert("CR") }
            } else if units[i] == 10 { kinds.insert("LF") }; i += 1
        }
        return kinds.count > 1 ? .mixed : LineEnding(rawValue: kinds.first ?? "LF")!
    }
    func normalize(_ text: String) -> String {
        guard self != .mixed else { return text }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: separator)
    }
}

struct TextSearch {
    static func matches(in text: String, query: String, matchCase: Bool) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let s = text as NSString; var result: [NSRange] = []; var start = 0
        let options: NSString.CompareOptions = matchCase ? [.literal] : [.literal, .caseInsensitive]
        while start < s.length {
            let range = s.range(of: query, options: options, range: NSRange(location: start, length: s.length-start))
            if range.location == NSNotFound || range.length == 0 { break }
            result.append(range); start = NSMaxRange(range)
        }; return result
    }
    static func replaceAll(in text: String, query: String, replacement: String, matchCase: Bool) -> (String, Int) {
        let ranges = matches(in: text, query: query, matchCase: matchCase)
        let s = NSMutableString(string: text)
        for range in ranges.reversed() { s.replaceCharacters(in: range, with: replacement) }
        return (s as String, ranges.count)
    }
}

// UTF-16 offsets match NSTextView. Updates rescan only the edited logical lines.
struct LineIndex {
    private(set) var starts: [Int] = [0]
    init(_ text: String = "") { starts = Self.scan(text as NSString, base: 0) }
    private static func scan(_ s: NSString, base: Int) -> [Int] {
        var result = [base]; var i = 0
        while i < s.length {
            let u = s.character(at: i)
            if u == 13 {
                if i+1 < s.length && s.character(at: i+1) == 10 { i += 1 }
                result.append(base+i+1)
            } else if u == 10 { result.append(base+i+1) }; i += 1
        }; return result
    }
    func line(at offset: Int) -> Int {
        var lo = 0, hi = starts.count
        while lo < hi { let mid = (lo+hi)/2; if starts[mid] <= offset { lo = mid+1 } else { hi = mid } }
        return max(0,lo-1)
    }
    func offset(forLine number: Int) -> Int? { number > 0 && number <= starts.count ? starts[number-1] : nil }
    mutating func update(newText: NSString, editedRange: NSRange, delta: Int) {
        let oldEnd = NSMaxRange(editedRange)-delta
        let first = max(0,line(at: max(0,editedRange.location-1)))
        let after = min(starts.count,line(at: oldEnd)+2)
        let begin = starts[first]
        let end = after < starts.count ? starts[after]+delta : newText.length
        var middle = Self.scan(newText.substring(with: NSRange(location: begin, length: max(0,end-begin))) as NSString, base: begin)
        if after < starts.count && middle.last == end { middle.removeLast() }
        starts = Array(starts[..<first]) + middle + starts[after...].map { $0+delta }
    }
}

enum LogEntry {
    static func timestamp(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }
    static func appendOnOpen(_ text: String, timestamp: String) -> String? {
        let first = text.prefix { $0 != "\r" && $0 != "\n" && $0 != "\r\n" }
        guard first == ".LOG" else { return nil }
        let sep = LineEnding.detect(text).separator
        return text + sep + timestamp + sep
    }
}
