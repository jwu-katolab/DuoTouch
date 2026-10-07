import Foundation
import AppKit
import UniformTypeIdentifiers

enum FileExportController {

    // SVG: electrodes.svg / wires.svg / two_electrodes.svg
    static func exportSVG(_ pair: TracePair, summary: DesignSummary, interaction: InteractionType) {
        let panel = NSSavePanel()
        panel.title = "Export SVG"
        panel.allowedContentTypes = [UTType.svg]
        panel.nameFieldStringValue = "trace.svg"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let base = url.deletingPathExtension()
        let dir  = base.deletingLastPathComponent()
        let stem = base.lastPathComponent

        let parts = SVGExporter.makeSVGSeparated(pair)
        let two   = SVGExporter.makeTwoElectrodesPCB(pair)

        do {
            try parts.electrodes.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_electrodes.svg"))
            try parts.wires.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_wires.svg"))
            try two.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_electrodes_user-actuated_component.svg"))
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // DXF: electrodes.dxf / wires.dxf / two_electrodes.dxf
    static func exportDXF(_ pair: TracePair, summary: DesignSummary, interaction: InteractionType) {
        let panel = NSSavePanel()
        panel.title = "Export DXF (R12)"
        panel.allowedContentTypes = [UTType(filenameExtension: "dxf") ?? .data]
        panel.nameFieldStringValue = "trace.dxf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let base = url.deletingPathExtension()
        let dir  = base.deletingLastPathComponent()
        let stem = base.lastPathComponent

        let parts = DXFExporter.makeDXFSeparated(pair)
        let two   = DXFExporter.makeTwoElectrodesPCB(pair)

        do {
            try parts.electrodes.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_electrodes.dxf"))
            try parts.wires.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_wires.dxf"))
            try two.data(using: .utf8)?.write(to: dir.appendingPathComponent("\(stem)_electrodes_user-actuated_component.dxf"))
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
