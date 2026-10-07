import CoreGraphics

struct AlignedGenerator {
    enum Mode { case unidirectional, reversiblePairs, directional }
    struct Options { let controls: Int; let mode: Mode }

    private enum Digit { case electrode, gap }

    static func generate(fs: Int, vmax: Int, options: Options) -> (TracePair, DesignSummary) {
        let w = DesignRules.decideWidthMm(vmax: vmax, fs: fs, scheme: .aligned)
        let spacing = DesignRules.spacingMm(for: w)
        let pitch   = DesignRules.seqPitchMm(for: w)
        let deltaD  = DesignRules.deltaDMm(for: w)
        let feasible = DesignRules.feasible(vmax: vmax, fs: fs, scheme: .aligned, w: w)

        let h: CGFloat = 8.0
        let gapY: CGFloat = 1.0

        let on  = CGFloat(w)
        let off = CGFloat(3*w)

        let L: Int
        let words: [CodeWord]
        let pairCount: Int
        switch options.mode {
        case .unidirectional:
            let lmin = CodebookGenerator.minimalLengthForUnidirectional(N: options.controls)
            L = max(2, lmin)
            words = CodebookGenerator.make(kind: .unidirectional, L: L, count: options.controls)
            pairCount = options.controls
        case .reversiblePairs:
            L = CodebookGenerator.minimalLengthForReversible(N: options.controls)
            words = CodebookGenerator.make(kind: .reversiblePairs, L: L, count: options.controls)
            pairCount = options.controls
        case .directional:
            L = CodebookGenerator.minimalLengthForUnidirectional(N: 4)
            words = CodebookGenerator.make(kind: .unidirectional, L: L, count: 4)
            pairCount = 4
        }

        let digits: [Digit] = (0..<L).map { ($0 % 2 == 0) ? .electrode : .gap }

        let nElec = (L + 1) / 2
        let nGap  =  L      / 2
        let pairWidth = CGFloat(nElec) * on + CGFloat(nGap) * off
        let gapX: CGFloat = LayoutConstants.controlGapMm

        func digitSpan(baseX: CGFloat, j: Int) -> (x: CGFloat, w: CGFloat) {
            let e = j / 2
            if j % 2 == 0 { return (baseX + CGFloat(e) * (on + off), on) }
            else          { return (baseX + CGFloat(e) * (on + off) + on, off) }
        }

        var ref = Trace(), inp = Trace()
        let yRef: CGFloat = 0
        let yInp: CGFloat = h + gapY

        var xBase: CGFloat = 0
        for i in 0..<pairCount {
            let word = words[i]
            var xsRef: [CGFloat] = []
            var xsInp: [CGFloat] = []

            for j in 0..<L where j % 2 == 0 {
                let s = digitSpan(baseX: xBase, j: j)
                let r = CGRect(x: s.x, y: yRef, width: on, height: h)
                ref.electrodes.append(.init(shape: .rect(r)))
                ref.wires.append(.init(pointsMm: WiringGenerator.vertical(from: r, lengthMm: 4.0, upwards: true)))
                xsRef.append(r.midX)
            }

            for j in 0..<L where word.bits[j] == 1 {
                let s = digitSpan(baseX: xBase, j: j)
                let rx = s.x + (s.w - on) / 2
                let r = CGRect(x: rx, y: yInp, width: on, height: h)
                inp.electrodes.append(.init(shape: .rect(r)))
                inp.wires.append(.init(pointsMm: WiringGenerator.vertical(from: r, lengthMm: 4.0, upwards: false)))
                xsInp.append(r.midX)
            }

            if xsRef.count >= 2 {
                let busRef = WiringGenerator.horizontalBus(x1: xsRef.min()!, x2: xsRef.max()!, y: yRef - 4.0)
                ref.wires.append(.init(pointsMm: busRef))
            }
            if xsInp.count >= 2 {
                let busInp = WiringGenerator.horizontalBus(x1: xsInp.min()!, x2: xsInp.max()!, y: yInp + h + 4.0)
                inp.wires.append(.init(pointsMm: busInp))
            }

            xBase += pairWidth + gapX
        }

        var summary = DesignSummary(wMm: w, spacingMm: spacing, pitchMm: pitch,
                                    deltaDMm: deltaD, feasible: feasible)
        summary.bitLengthL = L
        return (TracePair(reference: ref, input: inp), summary)
    }
}
