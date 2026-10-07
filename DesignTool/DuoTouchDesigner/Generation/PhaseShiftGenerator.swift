import CoreGraphics

struct PhaseShiftGenerator {
    struct Options { let targetTravelMm: Int; let bounded: Bool }

    static func generate(fs: Int, vmax: Int, options: Options)
    -> (TracePair, DesignSummary, Int, Int) {

        // 寸法（論文準拠）
        let w = DesignRules.decideWidthMm(vmax: vmax, fs: fs, scheme: .phase)
        let spacing = DesignRules.spacingMm(for: w)   // 3w
        let pitch   = DesignRules.seqPitchMm(for: w)  // ≈8w
        let deltaD  = DesignRules.deltaDMm(for: w)    // ≈4w
        let feasible = DesignRules.feasible(vmax: vmax, fs: fs, scheme: .phase, w: w)

        // Δd にスナップ（自動丸め）
        let raw = max(20, options.targetTravelMm)
        let k = max(1, Int(round(Double(raw) / deltaD)))
        let snapped = Int(Double(k) * deltaD)

        if options.bounded {
            let pair = generateLinearPair(w: w, travelMm: snapped)
            let sum = DesignSummary(wMm: w, spacingMm: spacing, pitchMm: pitch,
                                    deltaDMm: deltaD, feasible: feasible, bitLengthL: nil)
            return (pair, sum, snapped, k)
        } else {
            let pair = generateCircularPair(w: w, travelMm: snapped)
            let sum = DesignSummary(wMm: w, spacingMm: spacing, pitchMm: pitch,
                                    deltaDMm: deltaD, feasible: feasible, bitLengthL: nil)
            return (pair, sum, snapped, k)
        }
    }

    // MARK: Linear（上下1:1＋水平バス＝縦線端点同士）
    private static func generateLinearPair(w: Double, travelMm: Int) -> TracePair {
        var ref = Trace(), inp = Trace()

        let h: CGFloat = 8.0
        let gapY: CGFloat = 1.0
        let wireLen: CGFloat = 4.0

        let on = CGFloat(w)
        let off = CGFloat(3*w)
        let slot = on + off
        let T = CGFloat(travelMm)

        // (n-1)*slot + on <= T
        let nRef = max(1, Int(floor((T - on) / slot)) + 1)
        let lastRight = CGFloat(nRef - 1) * slot + on
        let phi = max(0, T - lastRight)

        let yRef: CGFloat = 0
        let yInp: CGFloat = h + gapY

        // Ref（黒）矩形＋上向き縦線
        var x: CGFloat = 0
        var xsRef: [CGFloat] = []
        for _ in 0..<nRef {
            let r = CGRect(x: x, y: yRef, width: on, height: h)
            ref.electrodes.append(.init(shape: .rect(r)))
            ref.wires.append(.init(pointsMm: WiringGenerator.vertical(from: r, lengthMm: wireLen, upwards: true)))
            xsRef.append(r.midX)
            x += slot
        }
        if xsRef.count >= 2 {
            let yBusRef = yRef - wireLen
            let busRef = WiringGenerator.horizontalBus(x1: xsRef.min()!, x2: xsRef.max()!, y: yBusRef)
            ref.wires.append(.init(pointsMm: busRef))
        }

        // Input（赤）矩形＋下向き縦線（φシフト）
        x = phi
        var xsInp: [CGFloat] = []
        for _ in 0..<nRef {
            let r = CGRect(x: x, y: yInp, width: on, height: h)
            inp.electrodes.append(.init(shape: .rect(r)))
            inp.wires.append(.init(pointsMm: WiringGenerator.vertical(from: r, lengthMm: wireLen, upwards: false)))
            xsInp.append(r.midX)
            x += slot
        }
        if xsInp.count >= 2 {
            let yBusInp = yInp + h + wireLen     // ← 縦線の「端点」を横接続（中央ではない）
            let busInp = WiringGenerator.horizontalBus(x1: xsInp.min()!, x2: xsInp.max()!, y: yBusInp)
            inp.wires.append(.init(pointsMm: busInp))
        }

        return TracePair(reference: ref, input: inp)
    }

    // MARK: Circular
    // 仕様：
    // - 円周 = target travel（Δd スナップ後）
    // - 赤(Input)：外側リング。外径側の接線長 = w、内径側は半径比で縮小（台形）
    // - 黒(Ref)：内側リング。外径/内径とも同様に比率縮小（台形）
    // - 位相オフセット = 1/4 スロット
    // - 配線：各電極の「短い幅側（= 内側）2頂点」を、隣の電極の短辺頂点へと**順に結ぶ**環状バス
    //          （＝ p1_i → p0_{i+1} を 3点ポリラインで接続、最後は p1_{n-1} → p0_0）
    private static func generateCircularPair(w: Double, travelMm: Int) -> TracePair {
        var ref = Trace(), inp = Trace()

        let C = CGFloat(travelMm)
        let rCenter = C / (2 * .pi)

        let h: CGFloat = 8.0
        let gapY: CGFloat = 1.0

        // 赤：外側リング（Input）
        let R_out_red = rCenter + (h + gapY)/2
        let R_in_red  = R_out_red - h
        // 黒：内側リング（Ref）
        let R_out_ref = rCenter - (h + gapY)/2
        let R_in_ref  = R_out_ref - h

        // 接線長：外径側を w、内側は半径比で縮小
        let wRedOuter = CGFloat(w)
        let wRedInner = wRedOuter * (R_in_red / R_out_red)
        let wRefOuter = wRedOuter * (R_out_ref / R_out_red)
        let wRefInner = wRedOuter * (R_in_ref  / R_out_red)

        // スロット 4w 基準
        let slotLen = CGFloat(4 * w)
        let n = max(1, Int(round(C / slotLen)))
        let step = 2 * .pi / CGFloat(n)
        let phase = step * 0.25               // 1/4 スロット

        // 参照（黒）電極の追加と短辺頂点の記録
        var innerEndsRef: [(CGPoint, CGPoint)] = [] // (p0, p1) for each electrode
        for i in 0..<n {
            let th = CGFloat(i) * step
            let quad = makeTrapezoid(tAngle: th, Rin: R_in_ref, Rout: R_out_ref, Lin: wRefInner, Lout: wRefOuter)
            ref.electrodes.append(.init(shape: .quad(quad.p0, quad.p1, quad.p2, quad.p3)))
            innerEndsRef.append((quad.p0, quad.p1)) // 短辺（内側）2頂点
        }

        // 入力（赤）電極の追加と短辺頂点の記録（位相オフセット）
        var innerEndsInp: [(CGPoint, CGPoint)] = []
        for i in 0..<n {
            let th = CGFloat(i) * step + phase
            let quad = makeTrapezoid(tAngle: th, Rin: R_in_red, Rout: R_out_red, Lin: wRedInner, Lout: wRedOuter)
            inp.electrodes.append(.init(shape: .quad(quad.p0, quad.p1, quad.p2, quad.p3)))
            innerEndsInp.append((quad.p0, quad.p1))
        }

        // —— 環状バス（Ref / Input ともに）——
        // それぞれ p1_i → p0_{i+1} を 3点ポリラインで接続（最後は i=n-1 → 0）
        func ringBus(from ends: [(CGPoint, CGPoint)], into trace: inout Trace) {
            guard !ends.isEmpty else { return }
            let m = ends.count
            for i in 0..<m {
                let a = ends[i].1
                let b = ends[(i + 1) % m].0
                let mid = CGPoint(x: (a.x + b.x)/2, y: (a.y + b.y)/2)
                trace.wires.append(.init(pointsMm: [a, mid, b]))
            }
        }
        ringBus(from: innerEndsRef, into: &ref)
        ringBus(from: innerEndsInp, into: &inp)

        return TracePair(reference: ref, input: inp)
    }

    // 台形の4頂点（p0,p1=内側短辺／p2,p3=外側長辺）を返す
    private static func makeTrapezoid(tAngle: CGFloat, Rin: CGFloat, Rout: CGFloat,
                                      Lin: CGFloat, Lout: CGFloat)
    -> (p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) {
        let tx = -sin(tAngle), ty = cos(tAngle) // 接線
        let nx =  cos(tAngle), ny = sin(tAngle) // 法線

        let cin  = CGPoint(x: Rin  * nx, y: Rin  * ny)
        let cout = CGPoint(x: Rout * nx, y: Rout * ny)

        let hi = Lin  / 2
        let ho = Lout / 2

        let p0 = CGPoint(x: cin.x  + tx * (-hi), y: cin.y  + ty * (-hi)) // 内-左（短辺1）
        let p1 = CGPoint(x: cin.x  + tx * ( hi), y: cin.y  + ty * ( hi)) // 内-右（短辺2）
        let p2 = CGPoint(x: cout.x + tx * ( ho), y: cout.y + ty * ( ho)) // 外-右
        let p3 = CGPoint(x: cout.x + tx * (-ho), y: cout.y + ty * (-ho)) // 外-左
        return (p0,p1,p2,p3)
    }
}
