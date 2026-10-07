import CoreGraphics

// 設計スキーム
enum Scheme {
    case aligned
    case phaseShifted
    case phase // 互換用エイリアス（phase == phaseShifted）
}

struct DesignRules {
    // G1: 正規化速度閾値 α（論文値）
    static let alphaAligned: CGFloat = 0.73
    static let alphaPhase:   CGFloat = 0.72

    // 互換用（他所が参照しても壊れないように残す）
    static let testedWidthsMm: [CGFloat] =
        Array(stride(from: 2.0, through: 8.0, by: 0.5)).map { CGFloat($0) }


    private static func testedWidths(fs: Int, scheme: Scheme) -> [CGFloat] {
        let isPhase = (scheme == .phase || scheme == .phaseShifted)
        switch (fs, isPhase, scheme) {
        // 60 Hz
        case (60, false, .aligned):
            return Array(stride(from: 3.0, through: 8.0, by: 0.5)).map { CGFloat($0) }
        case (60, true, _): // phase-shifted
            return Array(stride(from: 3.0, through: 8.0, by: 0.5)).map { CGFloat($0) }
        // 90 Hz
        case (90, false, .aligned):
            return Array(stride(from: 2.0, through: 8.0, by: 0.5)).map { CGFloat($0) }
        case (90, true, _): // phase-shifted
            return Array(stride(from: 2.5, through: 8.0, by: 0.5)).map { CGFloat($0) }
        // その他（フォールバック）
        default:
            return Array(stride(from: 2.0, through: 8.0, by: 0.5)).map { CGFloat($0) }
        }
    }

    private static func trunc2(_ x: CGFloat) -> CGFloat {
        floor(x * 100.0) / 100.0
    }

    static func feasible(vmax: Int, fs: Int, scheme: Scheme, w: CGFloat) -> Bool {
        let a: CGFloat = (scheme == .aligned) ? alphaAligned : alphaPhase
        let s = CGFloat(vmax) / (w * CGFloat(fs))
        let sTrunc = trunc2(s)
        return sTrunc <= a
    }

    static func decideWidthMm(vmax: Int, fs: Int, scheme: Scheme) -> CGFloat {
        let candidates = testedWidths(fs: fs, scheme: scheme)
        for w in candidates {
            if feasible(vmax: vmax, fs: fs, scheme: scheme, w: w) { return w }
        }
        return candidates.last ?? 3.0
    }

    // spacing = 3w（□の幅）。交互参照ピッチ ≈ 2*(w+spacing) = 8w
    static func spacingMm(for w: CGFloat) -> CGFloat { 3.0 * w }
    static func seqPitchMm(for w: CGFloat) -> CGFloat { 2.0 * (w + spacingMm(for: w)) } // = 8w
    static func deltaDMm(for w: CGFloat) -> CGFloat { 0.25 * w }
}
