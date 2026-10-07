import SwiftUI
import AppKit

struct PreviewView: View {
    @EnvironmentObject var app: AppState

    // 表示倍率（出力寸法には影響しない）
    private let pxPerMm: CGFloat = 3.0 

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Back to Setup") {
                    app.resetToDefaults()
                    NSApp.keyWindow?.contentView = NSHostingView(
                        rootView: SetupView().environmentObject(app)
                    )
                }
                Spacer()
                Button("Save as SVG") {
                    FileExportController.exportSVG(
                        app.generated,
                        summary: app.summary,
                        interaction: app.interaction
                    )
                }
                Button("Save as DXF") {
                    FileExportController.exportDXF(
                        app.generated,
                        summary: app.summary,
                        interaction: app.interaction
                    )
                }
            }
            .padding(.horizontal, 8)

            GeometryReader { _ in
                Canvas { ctx, size in
                    // 実ジオメトリの bbox（mm）
                    var bbox = mmBounding(pair: app.generated)

                    // Aligned の点線枠も中央配置に反映するため bbox を拡張
                    if app.interaction.isAligned,
                       let L = app.summary.bitLengthL {
                        let w = CGFloat(app.summary.wMm)
                        let on = w, off = 3*w
                        let nElec = (L + 1) / 2
                        let nGap  =  L      / 2
                        let pairWidth = CGFloat(nElec)*on + CGFloat(nGap)*off
                        let gapX = LayoutConstants.controlGapMm

                        // 縦線端点の上下（内容の実範囲）
                        let h: CGFloat = 8.0, gapY: CGFloat = 1.0, wireLen: CGFloat = 4.0
                        let yTopContent: CGFloat = 0 - wireLen
                        let yBotContent: CGFloat = (h + gapY) + h + wireLen

                        let controls = (app.interaction == .directionalNavigation) ? 4 : app.discreteCount
                        if controls > 0 {
                            // 枠は左右・上下とも w のマージン
                            let left  = 0 - w
                            let right = CGFloat(controls - 1) * (pairWidth + gapX) + pairWidth + w
                            let top   = yTopContent - w
                            let bot   = yBotContent + w
                            let framesRect = CGRect(x: left, y: top, width: right - left, height: bot - top)
                            bbox = bbox.union(framesRect)
                        }
                    }

                    let scale = pxPerMm
                    let contentW = bbox.width * scale
                    let contentH = bbox.height * scale
                    let offX = (size.width  - contentW)/2 - bbox.minX * scale
                    let offY = (size.height - contentH)/2 - bbox.minY * scale

                    // 本体描画（mm -> px）
                    draw(trace: app.generated.reference, in: ctx,
                         offset: CGSize(width: offX, height: offY), color: .black)
                    draw(trace: app.generated.input, in: ctx,
                         offset: CGSize(width: offX, height: offY), color: .red)

                    // 点線枠（Aligned で control > 1）
                    if app.interaction.isAligned,
                       let L = app.summary.bitLengthL {
                        let controls = (app.interaction == .directionalNavigation) ? 4 : app.discreteCount
                        if controls > 1 {
                            let w = CGFloat(app.summary.wMm)
                            let on = w, off = 3*w
                            let nElec = (L + 1) / 2
                            let nGap  =  L      / 2
                            let pairWidth = CGFloat(nElec)*on + CGFloat(nGap)*off
                            let gapX = LayoutConstants.controlGapMm

                            let h: CGFloat = 8.0, gapY: CGFloat = 1.0, wireLen: CGFloat = 4.0
                            let yTopContent: CGFloat = 0 - wireLen
                            let yBotContent: CGFloat = (h + gapY) + h + wireLen

                            // マージン＝電極幅 w
                            let marginX = w
                            let marginY = w

                            let frameTop    = yTopContent - marginY
                            let frameBottom = yBotContent + marginY
                            let frameHeight = frameBottom - frameTop

                            let dashStyle = StrokeStyle(
                                lineWidth: 1.0,
                                lineCap: .butt,
                                lineJoin: .miter,
                                miterLimit: 10,
                                dash: [6, 4],
                                dashPhase: 0
                            )

                            for i in 0..<controls {
                                let xBase = CGFloat(i) * (pairWidth + gapX)
                                let rectMm = CGRect(
                                    x: xBase - marginX,
                                    y: frameTop,
                                    width: pairWidth + 2*marginX,
                                    height: frameHeight
                                )
                                let rectPx = CGRect(
                                    x: rectMm.minX * scale + offX,
                                    y: rectMm.minY * scale + offY,
                                    width: rectMm.width * scale,
                                    height: rectMm.height * scale
                                )
                                ctx.stroke(Path(rectPx), with: .color(Color.gray.opacity(0.45)), style: dashStyle)
                            }
                        }
                    }
                }
                .background(Color.white)
                .border(.gray.opacity(0.4))
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 520)
    }

    // MARK: - Drawing
    private func draw(trace: Trace, in ctx: GraphicsContext, offset: CGSize, color: Color) {
        for e in trace.electrodes {
            switch e.shape {
            case .rect(let r):
                let rect = CGRect(
                    x: r.minX * pxPerMm + offset.width,
                    y: r.minY * pxPerMm + offset.height,
                    width: r.width * pxPerMm,
                    height: r.height * pxPerMm
                )
                ctx.fill(Path(rect), with: .color(color))

            case .quad(let a, let b, let c, let d0):
                let pts = [a, b, c, d0]
                var path = Path()
                let p0 = CGPoint(x: pts[0].x * pxPerMm + offset.width,
                                 y: pts[0].y * pxPerMm + offset.height)
                path.move(to: p0)
                for i in 1..<pts.count {
                    let p = CGPoint(x: pts[i].x * pxPerMm + offset.width,
                                    y: pts[i].y * pxPerMm + offset.height)
                    path.addLine(to: p)
                }
                path.closeSubpath()
                ctx.fill(path, with: .color(color))
            }
        }

        for w in trace.wires {
            var path = Path()
            let pts = w.pointsMm.map {
                CGPoint(x: $0.x * pxPerMm + offset.width, y: $0.y * pxPerMm + offset.height)
            }
            if let first = pts.first {
                path.move(to: first)
                for p in pts.dropFirst() { path.addLine(to: p) }
                ctx.stroke(path, with: .color(color), lineWidth: 1.0)
            }
        }
    }

    // MARK: - Bounding box (mm 座標)
    private func mmBounding(pair: TracePair) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        func acc(_ p: CGPoint) {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }

        for e in (pair.reference.electrodes + pair.input.electrodes) {
            switch e.shape {
            case .rect(let r):
                acc(CGPoint(x: r.minX, y: r.minY))
                acc(CGPoint(x: r.maxX, y: r.maxY))
            case .quad(let a, let b, let c, let d0):
                [a, b, c, d0].forEach(acc)
            }
        }
        for p in (pair.reference.wires + pair.input.wires).flatMap(\.pointsMm) { acc(p) }

        if !minX.isFinite { return CGRect(x: 0, y: 0, width: 100, height: 100) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
