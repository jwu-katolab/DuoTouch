import Foundation

struct CodeWord { let bits: [Int] }
enum CodebookKind { case unidirectional, reversiblePairs }

enum CodebookGenerator {
    private static func allWords(L: Int) -> [[Int]] {
        (0..<(1 << L)).map { v in (0..<L).reversed().map { ((v >> $0) & 1) } }
    }
    private static func isPalindrome(_ b: [Int]) -> Bool { b == Array(b.reversed()) }
    static func reverse(bits: [Int]) -> [Int] { Array(bits.reversed()) }

    static func minimalLengthForUnidirectional(N: Int) -> Int {
        var L = 1; while (1 << L) < N { L += 1 }; return L
    }
    static func minimalLengthForReversible(N: Int) -> Int {
        var L = 2
        while true {
            let pal = 1 << ((L + 1) / 2)
            let pairs = ((1 << L) - pal) / 2
            if pairs >= N { return L }
            L += 1
        }
    }
    static func make(kind: CodebookKind, L: Int, count N: Int) -> [CodeWord] {
        var result: [CodeWord] = []; var seen = Set<String>()
        func key(_ b: [Int]) -> String { b.map(String.init).joined() }
        for bits in allWords(L: L) {
            switch kind {
            case .unidirectional:
                result.append(.init(bits: bits))
                if result.count == N { return result }
            case .reversiblePairs:
                if isPalindrome(bits) { continue }
                let a = lexMin(bits, reverse(bits: bits))
                let k = key(a)
                if seen.contains(k) { continue }
                seen.insert(k)
                result.append(.init(bits: a))    // 幾何は 1:1 のみ出力
                if result.count == N { return result }
            }
        }
        return result
    }
    private static func lexMin(_ a: [Int], _ b: [Int]) -> [Int] {
        let n = Swift.min(a.count, b.count)
        for i in 0..<n where a[i] != b[i] { return a[i] < b[i] ? a : b }
        return a.count <= b.count ? a : b
    }
}
