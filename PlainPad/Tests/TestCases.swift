import Foundation
#if XCODE_TESTS
@testable import PlainPad
#endif

struct TestFailure: Error, CustomStringConvertible { let description: String }
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}
func rejects(_ block: () throws -> Void) throws {
    do { try block() } catch { return }
    throw TestFailure(description: "Expected operation to reject invalid data")
}
let coreTests: [(String, () throws -> Void)] = [
    ("Unicode and BOM round trips", {
        let text = "Hello 👩🏽‍💻 e\u{301} မြန်မာ 日本語\t \r\nend  "
        for encoding in TextEncoding.allCases where encoding != .windows1252 {
            let data = try TextFile(text: text, encoding: encoding).data()
            let decoded = try TextFile.decode(data)
            try expect(decoded.text == text, "Text roundtrip: \(encoding)")
            try expect(decoded.encoding == encoding, "Encoding roundtrip: \(encoding)")
            try expect(tryData(decoded) == data, "Bytes roundtrip")
        }
    }),
    ("Strict invalid Unicode and binary rejection", {
        for bytes: [UInt8] in [[0xC0,0xAF],[0xEF,0xBB,0xBF,0xFF],[0xFF,0xFE,0x00],[0xFF,0xFE,0x00,0xD8],[0xFE,0xFF,0xDC,0x00],[0x00,0x01]] {
            try rejects { _ = try TextFile.decode(Data(bytes)) }
        }
    }),
    ("Windows-1252 exact bytes and unsupported characters", {
        let bytes = Data((1...255).map(UInt8.init))
        let decoded = try TextFile.decode(bytes, legacy: true)
        try expect(tryData(decoded) == bytes, "All legacy bytes preserved")
        try expect(decoded.text.contains("€"), "Euro decoded")
        try rejects { _ = try TextFile(text: "hello 😀",encoding: .windows1252).data() }
    }),
    ("Line endings and exact whitespace preservation", {
        for (text,ending) in [("a\nb\n",LineEnding.lf),("a\r\nb\r\n",.crlf),("a\rb\r",.cr),("a\r\nb\nc\r",.mixed),("",.lf),("a  \t",.lf)] {
            try expect(LineEnding.detect(text) == ending,"Detect \(ending)")
            let decoded = try TextFile.decode(TextFile(text: text,encoding: .utf8).data())
            try expect(decoded.text.utf8.elementsEqual(text.utf8), "Preserve exact bytes")
        }
        try expect(LineEnding.crlf.normalize("a\rb\nc\r\n") == "a\r\nb\r\nc\r\n", "Normalize")
        try expect(LineEnding.mixed.normalize("a\rb\n") == "a\rb\n", "Mixed preserved")
    }),
    ("Literal find and replace boundaries", {
        try expect(TextSearch.matches(in: "A.a.a",query: ".",matchCase: true).count == 2,"Literal period")
        try expect(TextSearch.matches(in: "AaA",query: "a",matchCase: false).count == 3,"Ignore case")
        try expect(TextSearch.matches(in: "AaA",query: "a",matchCase: true).count == 1,"Match case")
        try expect(TextSearch.matches(in: "abc",query: "",matchCase: false).isEmpty,"Empty search")
        try expect(TextSearch.matches(in: "abc",query: "z",matchCase: false).isEmpty,"No matches")
        let (text,count) = TextSearch.replaceAll(in: "aaa",query: "a",replacement: "aa",matchCase: true)
        try expect(text == "aaaaaa" && count == 3,"Replacement not searched again")
        try expect(TextSearch.replaceAll(in: "abc",query: "",replacement: "x",matchCase: true).0 == "abc","Empty replace")
        try expect(TextSearch.replaceAll(in: "😀a😀",query: "😀",replacement: "",matchCase: true).0 == "a","Unicode replace")
    }),
    ("Go to Line boundaries and Unicode offsets", {
        let index = LineIndex("😀\r\nb\rc\n")
        try expect(index.starts == [0,4,6,8],"Logical line starts")
        try expect(index.offset(forLine: 0) == nil && index.offset(forLine: 5) == nil,"Invalid lines")
        try expect(index.offset(forLine: 4) == 8,"Final empty line")
        try expect(index.line(at: 2) == 0 && index.line(at: 4) == 1,"Wrapped-independent position")
        try expect(LineIndex().offset(forLine: 1) == 0,"Empty document")
    }),
    ("Incremental line index randomized edits", {
        var text = "a\r\nb\nc\rd😀\n" as NSString
        var index = LineIndex(text as String)
        var seed: UInt64 = 42
        func next(_ limit: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1; return Int(seed >> 32) % limit }
        // ASCII replacements on arbitrary UTF-16 boundaries exercise CRLF splitting/merging.
        text = "a\r\nb\nc\rd\n" as NSString; index = LineIndex(text as String)
        for _ in 0..<3000 {
            let start = next(text.length+1), length = next(text.length-start+1)
            let replacement = ["", "x", "\r", "\n", "\r\n", "a\nb\r"][next(6)]
            text = text.replacingCharacters(in: NSRange(location: start,length: length),with: replacement) as NSString
            index.update(newText: text,editedRange: NSRange(location: start,length: replacement.utf16.count),delta: replacement.utf16.count-length)
            try expect(index.starts == LineIndex(text as String).starts,"Incremental index mismatch: \(index.starts)")
        }
    }),
    ("LOG exact first line and append", {
        try expect(LogEntry.appendOnOpen(".LOG",timestamp: "STAMP") == ".LOG\nSTAMP\n","Empty LOG")
        try expect(LogEntry.appendOnOpen(".LOG\r\nold",timestamp: "STAMP") == ".LOG\r\nold\r\nSTAMP\r\n","CRLF LOG")
        for text in [".LOG x", ".log", "x\n.LOG", ".LOG "] { try expect(LogEntry.appendOnOpen(text,timestamp: "STAMP") == nil,"Exact LOG first line") }
    }),
    ("10 MB model and incremental edit", {
        let text = String(repeating: "0123456789 plain text\n", count: 500_000)
        let data = try TextFile(text: text,encoding: .utf8).data()
        try expect(data.count >= 10_000_000,"Fixture size")
        let decoded = try TextFile.decode(data)
        var index = LineIndex(decoded.text)
        let edited = (text as NSString).replacingCharacters(in: NSRange(location: 0,length: 0),with: "x") as NSString
        index.update(newText: edited,editedRange: NSRange(location: 0,length: 1),delta: 1)
        try expect(index.starts.count == 500_001,"Large index")
        try expect(index.starts[1] == 23,"Large edit")
    })
]
func tryData(_ file: TextFile) -> Data? { try? file.data() }
