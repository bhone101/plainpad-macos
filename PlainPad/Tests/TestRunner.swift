import Foundation
@main struct TestRunner {
    static func main() {
        var failures = 0
        for (name, test) in coreTests {
            let start = Date()
            do { try test(); print("PASS: \(name) (\(String(format: "%.3f",Date().timeIntervalSince(start)))s)") }
            catch { failures += 1; print("FAIL: \(name): \(error)") }
        }
        print("\(coreTests.count-failures)/\(coreTests.count) test groups passed")
        if failures > 0 { exit(1) }
    }
}
