import Foundation
import CoreGraphics

enum SVGExporter {

    static func makeSVGSeparated(_ pair: TracePair) -> (electrodes: String, wires: String) {
        let allPts = collectAllPoints(pair)
        let (minX, minY, maxX, maxY) = boundsXY(of: allPts)
        let offX = -minX, offY = -minY
        let width = maxX - minX, height = maxY - minY

        var e = svgHeader(widthMm: width, heightMm: height, viewBox: CGRect(x: 0, y: 0, width: width, height: height))
        e += "<g id=\"Electrodes\" fill=\"#000000\" stroke=\"none\">\n"
        for el in pair.reference.electrodes { e += electrodeElement(el, offX: offX, offY: offY) }
        for el in pair.input.electrodes     { e += electrodeElement(el, offX: offX, offY: offY) }
        e += "</g>\n</svg>\n"

        var w = svgHeader(widthMm: width, heightMm: height, viewBox: CGRect(x: 0, y: 0, width: width, height: height))
        w += "<g id=\"Wires\" fill=\"none\" stroke=\"#000000\" stroke-width=\"0.20mm\" vector-effect=\"non-scaling-stroke\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\">\n"
        for wi in pair.reference.wires { w += polyline(wi.pointsMm, offX: offX, offY: offY) }
        for wi in pair.input.wires     { w += polyline(wi.pointsMm, offX: offX, offY: offY) }
        w += "</g>\n</svg>\n"

        return (e, w)
    }

    // circular: 任意の黒赤1枚ずつを選び、放射中心を基準に半径不変・角度のみ調整して中心線角度を一致させる
    // linear/scalar: 従来の上下配置のまま
    static func makeTwoElectrodesPCB(_ pair: TracePair) -> String {
        let refPoly0 = firstElectrodePolygon(from: pair.reference.electrodes)
        let inpPoly0 = firstElectrodePolygon(from: pair.input.electrodes)
        guard let refPoly = refPoly0, let inpPoly = inpPoly0 else {
            return fallbackTwoRectsSVG(width: 20, h: 8, gap: 1)
        }

        let isCircular = containsQuad(in: pair.reference.electrodes) || containsQuad(in: pair.input.electrodes)
        if !isCircular {
            // 直線系は上下センタ（既存仕様）
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
            var s = svgHeader(widthMm: B.width, heightMm: B.height, viewBox: CGRect(x: 0, y: 0, width: B.width, height: B.height))
            s += "<g id=\"TwoElectrodes\" fill=\"#000000\" stroke=\"none\">\n"
            s += polygon(topF)
            s += polygon(botF)
            s += "</g>\n</svg>\n"
            return s
        }

        // circular: 半径不変・角度合わせ
        guard let axisRef = axisFromQuad(refPoly), let axisInp = axisFromQuad(inpPoly) else {
            return fallbackTwoRectsSVG(width: 20, h: 8, gap: 1)
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

        var s = svgHeader(widthMm: B.width, heightMm: B.height, viewBox: CGRect(x: 0, y: 0, width: B.width, height: B.height))
        s += "<g id=\"TwoElectrodes\" fill=\"#000000\" stroke=\"none\">\n"
        s += polygon(refF)
        s += polygon(inpF)
        s += "</g>\n</svg>\n"
        return s
    }

    private static func svgHeader(widthMm: CGFloat, heightMm: CGFloat, viewBox: CGRect) -> String {
        let w = fmt(widthMm), h = fmt(heightMm)
        let vb = "0 0 \(fmt(viewBox.width)) \(fmt(viewBox.height))"
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(w)mm\" height=\"\(h)mm\" viewBox=\"\(vb)\">\n"
    }

    private static func electrodeElement(_ e: Electrode, offX: CGFloat, offY: CGFloat) -> String {
        switch e.shape {
        case .rect(let r):
            let x = fmt(r.minX + offX), y = fmt(r.minY + offY)
            let w = fmt(r.width), h = fmt(r.height)
            return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\"/>\n"
        case .quad(let a, let b, let c, let d):
            let pts = [a,b,c,d].map { "\(fmt($0.x + offX)),\(fmt($0.y + offY))" }.joined(separator: " ")
            return "<polygon points=\"\(pts)\"/>\n"
        }
    }

    private static func polyline(_ pts: [CGPoint], offX: CGFloat, offY: CGFloat) -> String {
        let s = pts.map { "\(fmt($0.x + offX)),\(fmt($0.y + offY))" }.joined(separator: " ")
        return "<polyline points=\"\(s)\"/>\n"
    }

    private static func polygon(_ pts: [CGPoint]) -> String {
        let s = pts.map { "\(fmt($0.x)),\(fmt($0.y))" }.joined(separator: " ")
        return "<polygon points=\"\(s)\"/>\n"
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

    // 短辺と長辺の midpoint を返す（bases=より平行な対辺）。v は短辺→長辺ベクトル
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
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
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

    private static func fallbackTwoRectsSVG(width w: CGFloat, h: CGFloat, gap: CGFloat) -> String {
        let outWidth = w
        let outHeight = h*2 + gap
        var s = svgHeader(widthMm: outWidth, heightMm: outHeight, viewBox: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
        s += "<g fill=\"#000000\" stroke=\"none\">\n"
        s += "<rect x=\"0\" y=\"0\" width=\"\(fmt(w))\" height=\"\(fmt(h))\"/>\n"
        s += "<rect x=\"0\" y=\"\(fmt(h+gap))\" width=\"\(fmt(w))\" height=\"\(fmt(h))\"/>\n"
        s += "</g>\n</svg>\n"
        return s
    }
}
