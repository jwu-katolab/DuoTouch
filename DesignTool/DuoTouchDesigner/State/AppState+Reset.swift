import Foundation

extension AppState {
    func resetToDefaults() {
        // S1
        samplingRateHz = 60
        // S2
        actuationSpeedMmPerSec = 130
        // S3
        interaction = .oneShotAction
        discreteCount = 4
        // Phase-shifted 用パラメタ（使われない場合も初期化）
        targetTravelMm = 150

        // 生成物は次のセットアップ画面で再計算されるため、ここでは触らない
        // generated / summary は SetupView.onAppear の recompute() で更新される想定
    }
}
