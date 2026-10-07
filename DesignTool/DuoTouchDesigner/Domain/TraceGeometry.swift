import Foundation
import CoreGraphics

/// 電極形状：軸平行矩形、または回転矩形（四角形頂点）
enum ElectrodeShape {
    case rect(CGRect)
    case quad(CGPoint, CGPoint, CGPoint, CGPoint)
}

struct Electrode: Identifiable {
    let id = UUID()
    var shape: ElectrodeShape
}

struct WireSegment {
    var pointsMm: [CGPoint]    // 3点以上は出力側で保証
}

struct Trace {
    var electrodes: [Electrode] = []
    var wires: [WireSegment] = []
}

struct TracePair {
    var reference: Trace
    var input: Trace
    static var empty: TracePair { .init(reference: .init(), input: .init()) }
}
