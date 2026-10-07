import Foundation
import CoreGraphics

enum DXFExporter {

    static func makeDXFSeparated(_ pair: TracePair) -> (electrodes: String, wires: String) {
        let allPts = collectAllPoints(pair)
        let (minX, minY, maxX, maxY) = boundsXY(of: allPts)
        let offX = -minX, offY = -minY
        let width = maxX - minX, height = maxY - minY

        func header(_ w: CGFloat, _ h: CGFloat) -> String {
            var d = ""
            d += "  0\nSECTION\n  2\nHEADER\n"
            d += "  9\n$ACADVER\n  1\nAC1009\n"
            d += "  9\n$INSUNITS\n 70\n4\n"
            d += "  9\n$MEASUREMENT\n 70\n1\n"
            d += "  9\n$EXTMIN\n 10\n0.0\n 20\n0.0\n"
            d += "  9\n$EXTMAX\n 10\n\(fmt(w))\n 20\n\(fmt(h))\n"
            d += "  9\n$LIMMIN\n 10\n0.0\n 20\n0.0\n"
            d += "  9\n$LIMMAX\n 10\n\(fmt(w))\n 20\n\(fmt(h))\n"
            d += "  0\nENDSEC\n"
            d += "  0\nSECTION\n  2\nTABLES\n"
            d += "  0\nTABLE\n  2\nLAYER\n 70\n2\n"
            d += "  0\nLAYER\n  2\nElectrodes\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n"
            d += "  0\nLAYER\n  2\nWires\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n"
            d += "  0\nENDTAB\n"
            d += "  0\nENDSEC\n"
            return d
        }
        func footer() -> String { "  0\nENDSEC\n  0\nEOF\n" }

        func polylineR12(_ ptsIn: [CGPoint], layer: String, closed: Bool) -> String {
            let pts = ensure3(ptsIn)
            var d = ""
            d += "  0\nPOLYLINE\n"
            d += "  8\n\(layer)\n"
            d += " 66\n1\n"
            d += " 70\n\(closed ? 1 : 0)\n"
            d += " 10\n0.0\n 20\n0.0\n 30\n0.0\n"
            for p in pts {
                let q = CGPoint(x: p.x + offX, y: p.y + offY)
                d += "  0\nVERTEX\n"
                d += "  8\n\(layer)\n"
                d += " 10\n\(fmt(q.x))\n 20\n\(fmt(q.y))\n 30\n0.0\n"
            }
            d += "  0\nSEQEND\n"
            return d
        }

        var e = header(width, height)
        e += "  0\nSECTION\n  2\nENTITIES\n"
        for el in pair.reference.electrodes + pair.input.electrodes {
            switch el.shape {
            case .rect(let r):
                let poly = [
                    CGPoint(x: r.minX, y: r.minY),
                    CGPoint(x: r.maxX, y: r.minY),
                    CGPoint(x: r.maxX, y: r.maxY),
                    CGPoint(x: r.minX, y: r.maxY),
                    CGPoint(x: r.minX, y: r.minY)
                ]
                e += polylineR12(poly, layer: "Electrodes", closed: true)
            case .quad(let a, let b, let c, let d0):
                e += polylineR12([a,b,c,d0,a], layer: "Electrodes", closed: true)
            }
        }
        e += footer()

        var wDoc = header(width, height)
        wDoc += "  0\nSECTION\n  2\nENTITIES\n"
        for wi in pair.reference.wires + pair.input.wires {
            wDoc += polylineR12(wi.pointsMm, layer: "Wires", closed: false)
        }
        wDoc += footer()

        return (e, wDoc)
    }

    // circular: 半径不変・角度のみ調整して中心線角度を一致
    // linear/scalar: 従来の上下配置
    static func makeTwoElectrodesPCB(_ pair: TracePair) -> String {
        let refPoly0 = firstElectrodePolygon(from: pair.reference.electrodes)
        let inpPoly0 = firstElectrodePolygon(from: pair.input.electrodes)
        guard let refPoly = refPoly0, let inpPoly = inpPoly0 else {
            return fallbackTwoRectsDXF(width: 20, h: 8, gap: 1)
        }

        let isCircular = containsQuad(in: pair.reference.electrodes) || containsQuad(in: pair.input.electrodes)
        if !isCircular {
            let gapY: CGFloat = 1.0
            let topBox = boundsRect(of: refPoly)
            let botBox = boundsRect(of: inpPoly)
            var top = refPoly.map { CGPoint(x: $0.x - topBox.minX, y: $0.y - topBox.minY) }
            var bot = inpPoly.map { CGPoint(x: $0.x - botBox.minX, y: $0.y - botBox.minY + topBox.height + gapY) }
            let outW = max(boundsRect(of: top).width, boundsRect(of: bot).width)
            let dxTop = (outW - boundsRect(of: top).width)/2 - boundsRect(of: top).minX
            let dxBot = (outW - boundsRect(of: bot).width)/2 - boundsRect(of: bot).minX
            top = top.map { CGPoint(x: $0.x + dxTop, y: $0.y) }
            bot = bot.map { CGPoint(x: $0.x + dxBot, y: $0.y) }
            let all = top + bot
            let B = boundsRect(of: all)
            let off = CGPoint(x: -B.minX, y: -B.minY)
            let topF = top.map { CGPoint(x: $0.x + off.x, y: $0.y + off.y) }
            let botF = bot.map { CGPoint(x: $0.x + off.x, y: $0.y + off.y) }

            var d = ""
            d += "  0\nSECTION\n  2\nHEADER\n"
            d += "  9\n$ACADVER\n  1\nAC1009\n"
            d += "  9\n$INSUNITS\n 70\n4\n"
            d += "  9\n$MEASUREMENT\n 70\n1\n"
            d += "  9\n$EXTMIN\n 10\n0.0\n 20\n0.0\n"
            d += "  9\n$EXTMAX\n 10\n\(fmt(B.width))\n 20\n\(fmt(B.height))\n"
            d += "  9\n$LIMMIN\n 10\n0.0\n 20\n0.0\n"
            d += "  9\n$LIMMAX\n 10\n\(fmt(B.width))\n 20\n\(fmt(B.height))\n"
            d += "  0\nENDSEC\n"
            d += "  0\nSECTION\n  2\nTABLES\n"
            d += "  0\nTABLE\n  2\nLAYER\n 70\n1\n"
            d += "  0\nLAYER\n  2\nElectrodes\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n"
            d += "  0\nENDTAB\n"
            d += "  0\nENDSEC\n"
            d += "  0\nSECTION\n  2\nENTITIES\n"
            d += polylineR12NoOff(closedPoly(topF), layer: "Electrodes", closed: true)
            d += polylineR12NoOff(closedPoly(botF), layer: "Electrodes", closed: true)
            d += "  0\nENDSEC\n  0\nEOF\n"
            return d
        }

        guard let axisRef = axisFromQuad(refPoly), let axisInp = axisFromQuad(inpPoly) else {
            return fallbackTwoRectsDXF(width: 20, h: 8, gap: 1)
        }

        let O = lineIntersection(p: axisRef.top, v: axisRef.v, q: axisInp.top, w: axisInp.v) ?? {
            let m1 = mid(axisRef.top, axisRef.bottom)
            let m2 = mid(axisInp.top, axisInp.bottom)
            return CGPoint(x: (m1.x + m2.x)/2, y: (m1.y + m2.y)/2)
        }()

        let thRef = atan2(axisRef.v.y, axisRef.v.x)
        let thInp = atan2(axisInp.v.y, axisInp.v.x)
        let thTarget = averageAngle(thRef, thInp)
        let dRef = thTarget - thRef
        let dInp = thTarget - thInp

        let refRot = rotate(refPoly, around: O, by: dRef)
        let inpRot = rotate(inpPoly, around: O, by: dInp)

        let all = refRot + inpRot
        let B = boundsRect(of: all)
        let off = CGPoint(x: -B.minX, y: -B.minY)
        let refF = refRot.map { CGPoint(x: $0.x + off.x, y: $0.y + off.y) }
        let inpF = inpRot.map { CGPoint(x: $0.x + off.x, y: $0.y + off.y) }

        var d = ""
        d += "  0\nSECTION\n  2\nHEADER\n"
        d += "  9\n$ACADVER\n  1\nAC1009\n"
        d += "  9\n$INSUNITS\n 70\n4\n"
        d += "  9\n$MEASUREMENT\n 70\n1\n"
        d += "  9\n$EXTMIN\n 10\n0.0\n 20\n0.0\n"
        d += "  9\n$EXTMAX\n 10\n\(fmt(B.width))\n 20\n\(fmt(B.height))\n"
        d += "  9\n$LIMMIN\n 10\n0.0\n 20\n0.0\n"
        d += "  9\n$LIMMAX\n 10\n\(fmt(B.width))\n 20\n\(fmt(B.height))\n"
        d += "  0\nENDSEC\n"
        d += "  0\nSECTION\n  2\nTABLES\n"
        d += "  0\nTABLE\n  2\nLAYER\n 70\n1\n"
        d += "  0\nLAYER\n  2\nElectrodes\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n"
        d += "  0\nENDTAB\n"
        d += "  0\nENDSEC\n"

        d += "  0\nSECTION\n  2\nENTITIES\n"
        d += polylineR12NoOff(closedPoly(refF), layer: "Electrodes", closed: true)
        d += polylineR12NoOff(closedPoly(inpF), layer: "Electrodes", closed: true)
        d += "  0\nENDSEC\n  0\nEOF\n"
        return d
    }

    // helpers

    private static func polylineR12NoOff(_ ptsIn: [CGPoint], layer: String, closed: Bool) -> String {
        let pts = ensure3(ptsIn)
        var d = ""
        d += "  0\nPOLYLINE\n"
        d += "  8\n\(layer)\n"
        d += " 66\n1\n"
        d += " 70\n\(closed ? 1 : 0)\n"
        d += " 10\n0.0\n 20\n0.0\n 30\n0.0\n"
        for p in pts {
            d += "  0\nVERTEX\n"
            d += "  8\n\(layer)\n"
            d += " 10\n\(fmt(p.x))\n 20\n\(fmt(p.y))\n 30\n0.0\n"
        }
        d += "  0\nSEQEND\n"
        return d
    }

    private static func closedPoly(_ pts: [CGPoint]) -> [CGPoint] {
        guard !pts.isEmpty else { return pts }
        return pts + [pts[0]]
    }

    private static func fallbackTwoRectsDXF(width w: CGFloat, h: CGFloat, gap: CGFloat) -> String {
        let outW = w
        let outH = 2*h + gap
        let rectTop = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: w, y: 0),
            CGPoint(x: w, y: h),
            CGPoint(x: 0, y: h),
            CGPoint(x: 0, y: 0)
        ]
        let rectBot = rectTop.map { CGPoint(x: $0.x, y: $0.y + h + gap) }

        var d = ""
        d += "  0\nSECTION\n  2\nHEADER\n"
        d += "  9\n$ACADVER\n  1\nAC1009\n"
        d += "  9\n$INSUNITS\n 70\n4\n"
        d += "  9\n$MEASUREMENT\n 70\n1\n"
        d += "  9\n$EXTMIN\n 10\n0.0\n 20\n0.0\n"
        d += "  9\n$EXTMAX\n 10\n\(fmt(outW))\n 20\n\(fmt(outH))\n"
        d += "  9\n$LIMMIN\n 10\n0.0\n 20\n0.0\n"
        d += "  9\n$LIMMAX\n 10\n\(fmt(outW))\n 20\n\(fmt(outH))\n"
        d += "  0\nENDSEC\n"
        d += "  0\nSECTION\n  2\nTABLES\n"
        d += "  0\nTABLE\n  2\nLAYER\n 70\n1\n"
        d += "  0\nLAYER\n  2\nElectrodes\n 70\n0\n 62\n7\n  6\nCONTINUOUS\n"
        d += "  0\nENDTAB\n"
        d += "  0\nENDSEC\n"

        d += "  0\nSECTION\n  2\nENTITIES\n"
        d += polylineR12NoOff(rectTop, layer: "Electrodes", closed: true)
        d += polylineR12NoOff(rectBot, layer: "Electrodes", closed: true)
        d += "  0\nENDSEC\n  0\nEOF\n"
        return d
    }

    private static func firstElectrodePolygon(from es: [Electrode]) -> [CGPoint]? {
        for e in es {
            switch e.shape {
            case .rect(let r):
                return [
                    CGPoint(x: r.minX, y: r.minY),
                    CGPoint(x: r.maxX, y: r.minY),
                    CGPoint(x: r.maxX, y: r.maxY),
                    CGPoint(x: r.minX, y: r.maxY)
                ]
            case .quad(let a, let b, let c, let d):
                return [a,b,c,d]
            }
        }
        return nil
    }

    private static func containsQuad(in es: [Electrode]) -> Bool {
        for e in es { if case .quad = e.shape { return true } }
        return false
    }

    private static func axisFromQuad(_ poly: [CGPoint]) -> (top: CGPoint, bottom: CGPoint, v: CGPoint)? {
        guard poly.count >= 4 else { return nil }
        let a = poly[0], b = poly[1], c = poly[2], d = poly[3]
        let e0 = (a,b), e1 = (b,c), e2 = (c,d), e3 = (d,a)

        func dir(_ e:(CGPoint,CGPoint)) -> CGPoint {
            let vx = e.1.x - e.0.x, vy = e.1.y - e.0.y
            let L = max(hypot(vx, vy), 1e-6)
            return CGPoint(x: vx/L, y: vy/L)
        }
        func sim(_ u:CGPoint, _ v:CGPoint) -> CGFloat { abs(u.x*v.x + u.y*v.y) }

        let s0 = sim(dir(e0), dir(e2))
        let s1 = sim(dir(e1), dir(e3))
        let bases:(CGPoint,CGPoint,CGPoint,CGPoint) = (s0 >= s1) ? (e0.0,e0.1,e2.0,e2.1) : (e1.0,e1.1,e3.0,e3.1)

        let mA = mid(bases.0, bases.1)
        let mB = mid(bases.2, bases.3)
        let lenA = hypot(bases.1.x - bases.0.x, bases.1.y - bases.0.y)
        let lenB = hypot(bases.3.x - bases.2.x, bases.3.y - bases.2.y)

        let top = (lenA <= lenB) ? mA : mB
        let bottom = (lenA <= lenB) ? mB : mA
        return (top, bottom, CGPoint(x: bottom.x - top.x, y: bottom.y - top.y))
    }

    private static func lineIntersection(p: CGPoint, v: CGPoint, q: CGPoint, w: CGPoint) -> CGPoint? {
        let den = v.x * w.y - v.y * w.x
        if abs(den) < 1e-9 { return nil }
        let t = ((q.x - p.x) * w.y - (q.y - p.y) * w.x) / den
        return CGPoint(x: p.x + t * v.x, y: p.y + t * v.y)
    }

    private static func rotate(_ pts: [CGPoint], around o: CGPoint, by ang: CGFloat) -> [CGPoint] {
        let ca = cos(ang), sa = sin(ang)
        return pts.map { p in
            let x = p.x - o.x, y = p.y - o.y
            return CGPoint(x: o.x + ca*x - sa*y, y: o.y + sa*x + ca*y)
        }
    }

    private static func averageAngle(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let x = cos(a) + cos(b), y = sin(a) + sin(b)
        return atan2(y, x)
    }

    private static func mid(_ p: CGPoint, _ q: CGPoint) -> CGPoint {
        CGPoint(x: (p.x + q.x)/2, y: (p.y + q.y)/2)
    }

    private static func collectAllPoints(_ pair: TracePair) -> [CGPoint] {
        var pts: [CGPoint] = []
        for e in pair.reference.electrodes + pair.input.electrodes {
            switch e.shape {
            case .rect(let r): pts += [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY)]
            case .quad(let a, let b, let c, let d): pts += [a,b,c,d]
            }
        }
        for p in (pair.reference.wires + pair.input.wires).flatMap(\.pointsMm) { pts.append(p) }
        if pts.isEmpty { pts = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)] }
        return pts
    }

    private static func boundsXY(of pts: [CGPoint]) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for p in pts {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return (minX, minY, maxX, maxY)
    }

    private static func boundsRect(of pts: [CGPoint]) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for p in pts {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func fmt(_ v: CGFloat) -> String { String(format: "%.3f", Double(v)) }

    private static func ensure3(_ pts: [CGPoint]) -> [CGPoint] {
        if pts.count >= 3 { return pts }
        if pts.count == 2 {
            let a = pts[0], b = pts[1]
            let m = CGPoint(x: (a.x + b.x)/2, y: (a.y + b.y)/2)
            return [a, m, b]
        }
        if let p = pts.first { return [p, p, p] }
        return [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)]
    }
}
