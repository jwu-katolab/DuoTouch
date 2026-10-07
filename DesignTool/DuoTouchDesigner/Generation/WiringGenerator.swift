import CoreGraphics

enum WiringGenerator {

    // 垂直（矩形中心の真上/真下に 3 点）
    static func vertical(from rect: CGRect, lengthMm: CGFloat, upwards: Bool) -> [CGPoint] {
        let cx = rect.midX
        let y0 = upwards ? rect.minY : rect.maxY
        let y1 = upwards ? (y0 - abs(lengthMm)) : (y0 + abs(lengthMm))
        let a = CGPoint(x: cx, y: y0)
        let c = CGPoint(x: cx, y: y1)
        let b = CGPoint(x: cx, y: (y0 + y1) / 2)
        return [a, b, c]
    }

    // 放射（円環系、3点）
    static func radial(from center: CGPoint, start: CGPoint, outward: Bool, lengthMm: CGFloat) -> [CGPoint] {
        let vx = start.x - center.x
        let vy = start.y - center.y
        let r = CGFloat(hypot(Double(vx), Double(vy)))
        guard r > 0 else { return [start, start, start] }
        let ux = vx / r, uy = vy / r
        let dir: CGFloat = outward ? 1.0 : -1.0
        let a = start
        let c = CGPoint(x: start.x + dir * ux * abs(lengthMm),
                        y: start.y + dir * uy * abs(lengthMm))
        let b = CGPoint(x: (a.x + c.x) / 2, y: (a.y + c.y) / 2)
        return [a, b, c]
    }

    // 水平バス（端点 x1-x2 を y で結ぶ 3点）
    static func horizontalBus(x1: CGFloat, x2: CGFloat, y: CGFloat) -> [CGPoint] {
        let xa = min(x1, x2)
        let xc = max(x1, x2)
        let xb = (xa + xc) / 2
        return [CGPoint(x: xa, y: y), CGPoint(x: xb, y: y), CGPoint(x: xc, y: y)]
    }

    // 水平バス（複数 x を y で一直線に結ぶ）
    static func horizontalBus(xPositions xs: [CGFloat], y: CGFloat) -> [CGPoint]? {
        let xsSorted = xs.sorted()
        switch xsSorted.count {
        case 0: return nil
        case 1:
            let p = CGPoint(x: xsSorted[0], y: y)
            return [p, p, p]
        case 2:
            let a = xsSorted[0], c = xsSorted[1], b = (a + c)/2
            return [CGPoint(x: a, y: y), CGPoint(x: b, y: y), CGPoint(x: c, y: y)]
        default:
            return xsSorted.map { CGPoint(x: $0, y: y) }
        }
    }
}
