import SwiftUI
import AppKit

extension InteractionType {
    var label: String {
        switch self {
        case .oneShotAction:         return "One-shot action"
        case .twoStateToggle:        return "Two-state toggle"
        case .directionalNavigation: return "Directional navigation"
        case .scalarAdjustment:      return "Scalar adjustment"
        case .cyclicAdjustment:      return "Cyclic adjustment"
        }
    }
}

struct SetupView: View {
    @EnvironmentObject var app: AppState

    @State private var devicePreset: String = "Smartphone 60Hz"
    @State private var snappedTravelPreview: Int? = nil   // 内部計算は残す（UIでは非表示）
    @State private var canProceed: Bool = true

    private let columnWidth: CGFloat = 520

    // 共通フォント
    private let headerFont: Font = .system(size: 18, weight: .semibold)
    private let bodyFont: Font   = .system(size: 14)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .trailing, spacing: 18) {

                    // ===== S1. Target device (Hz) =====
                    GroupBox {
                        VStack(alignment: .trailing, spacing: 8) {
                            Picker("", selection: $devicePreset) {
                                Text("60Hz (Smartphone)").tag("Smartphone 60Hz")
                                Text("90Hz (Touchpad)").tag("Touchpad 90Hz")
                                Text("Custom").tag("Custom")
                            }
                            .labelsHidden()
                            .frame(width: columnWidth, alignment: .trailing)
                            .onChange(of: devicePreset) { _, v in
                                switch v {
                                case "Smartphone 60Hz": app.samplingRateHz = 60
                                case "Touchpad 90Hz":   app.samplingRateHz = 90
                                default: break
                                }
                                recompute()
                            }

                            if devicePreset == "Custom" {
                                Stepper(value: $app.samplingRateHz, in: 30...180, step: 10) {
                                    Text("Sampling rate: \(app.samplingRateHz) Hz")
                                }
                                .frame(width: columnWidth, alignment: .trailing)
                                .onChange(of: app.samplingRateHz) { _, _ in recompute() }
                            } else {
                                Text("Sampling rate: \(app.samplingRateHz) Hz")
                                    .frame(width: columnWidth, alignment: .trailing)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .font(bodyFont)
                    } label: {
                        Text("S1. Target device").font(headerFont)
                    }

                    // ===== S2. User actuation speed =====
                    GroupBox {
                        VStack(alignment: .trailing, spacing: 8) {
                            Stepper(value: $app.actuationSpeedMmPerSec, in: 20...200, step: 10) {
                                Text("\(app.actuationSpeedMmPerSec) mm/s (default G2 = 130)")
                            }
                            .frame(width: columnWidth, alignment: .trailing)
                            .onChange(of: app.actuationSpeedMmPerSec) { _, _ in recompute() }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .font(bodyFont)
                    } label: {
                        Text("S2. User actuation speed").font(headerFont)
                    }

                    // ===== S3. Interaction =====
                    GroupBox {
                        VStack(alignment: .trailing, spacing: 10) {
                            Picker("", selection: $app.interaction) {
                                ForEach(InteractionType.allCases) { t in
                                    Text(t.label).tag(t)
                                }
                            }
                            .labelsHidden()
                            .frame(width: columnWidth, alignment: .trailing)
                            .onChange(of: app.interaction) { _, newType in
                                // Cyclic の範囲・既定値調整
                                switch newType {
                                case .cyclicAdjustment:
                                    if app.targetTravelMm < 100 || app.targetTravelMm > 300 { app.targetTravelMm = 150 }
                                case .scalarAdjustment:
                                    if app.targetTravelMm < 20 || app.targetTravelMm > 200 { app.targetTravelMm = 100 }
                                default:
                                    break
                                }
                                recompute()
                            }

                            if app.interaction.isAligned {
                                if app.interaction == .directionalNavigation {
                                    Text("Controls: 4 (Directional)")
                                        .frame(width: columnWidth, alignment: .trailing)
                                } else {
                                    Stepper(value: $app.discreteCount, in: 1...10) {
                                        Text("Controls: \(app.discreteCount)")
                                    }
                                    .frame(width: columnWidth, alignment: .trailing)
                                    .onChange(of: app.discreteCount) { _, _ in recompute() }
                                }
                            } else {
                                // Scalar / Cyclic は「Target travel (total): <数値> mm」だけ表示
                                let range: ClosedRange<Int> = (app.interaction == .cyclicAdjustment) ? 100...300 : 20...200
                                Stepper(value: $app.targetTravelMm, in: range, step: 10) {
                                    Text("Target travel (total): \(app.targetTravelMm) mm")
                                        .multilineTextAlignment(.trailing)
                                }
                                .frame(width: columnWidth, alignment: .trailing)
                                .onChange(of: app.targetTravelMm) { _, _ in recompute() }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .font(bodyFont)
                    } label: {
                        Text("S3. Interaction").font(headerFont)
                    }

                    // ===== Summary =====
                    GroupBox {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(String(format: "w: %.1f mm   spacing: %.1f mm",
                                        app.summary.wMm, app.summary.spacingMm))
                            .frame(width: columnWidth, alignment: .trailing)

                            if app.interaction.isAligned, let L = app.summary.bitLengthL {
                                Text("L (digits): \(L)")
                                    .frame(width: columnWidth, alignment: .trailing)
                            }

                            Text(app.summary.feasible ? "Feasible" : "Not feasible")
                                .foregroundStyle(app.summary.feasible ? .green : .red)
                                .frame(width: columnWidth, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .font(bodyFont)
                    } label: {
                        Text("Summary").font(headerFont)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            HStack {
                Spacer()
                Button("Open Preview") { proceedToPreview() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed || !app.summary.feasible)
            }
            .padding(16)
        }
        .frame(minWidth: 900, minHeight: 520)
        .onAppear {
            recompute()
            DispatchQueue.main.async { resizeWindow(toWidth: 900) }
        }
    }

    // MARK: - 設計再計算
    private func recompute() {
        let fs   = app.samplingRateHz
        let vmax = app.actuationSpeedMmPerSec

        if app.interaction.isAligned {
            let mode: AlignedGenerator.Mode = {
                switch app.interaction {
                case .oneShotAction:         return .unidirectional
                case .twoStateToggle:        return .reversiblePairs
                case .directionalNavigation: return .directional
                default:                     return .unidirectional
                }
            }()
            let controls = (app.interaction == .directionalNavigation) ? 4 : app.discreteCount
            let (pair, sum) = AlignedGenerator.generate(fs: fs, vmax: vmax, options: .init(controls: controls, mode: mode))
            app.generated = pair
            app.summary   = sum
            snappedTravelPreview = nil
        } else {
            let (pair, sum, snapped, _) = PhaseShiftGenerator.generate(
                fs: fs, vmax: vmax,
                options: .init(targetTravelMm: app.targetTravelMm,
                               bounded: app.interaction == .scalarAdjustment)
            )
            app.generated = pair
            app.summary   = sum
            snappedTravelPreview = snapped
        }
        canProceed = app.summary.feasible
    }

    private func proceedToPreview() {
        NSApp.keyWindow?.contentView = NSHostingView(
            rootView: PreviewView().environmentObject(app)
        )
    }

    private func resizeWindow(toWidth width: CGFloat) {
        guard let win = NSApp.keyWindow else { return }
        var f = win.frame
        let delta = width - f.size.width
        f.origin.x -= delta / 2 // 中央寄せで幅変更
        f.size.width = width
        win.setFrame(f, display: true, animate: false)
    }
}
