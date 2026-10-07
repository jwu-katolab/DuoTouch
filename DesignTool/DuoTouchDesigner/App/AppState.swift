import Foundation

final class AppState: ObservableObject {
    // S1
    @Published var samplingRateHz: Int = 60          // 60/90/Custom(30-180)
    // S2
    @Published var actuationSpeedMmPerSec: Int = 130 // 20-200

    // S3
    @Published var interaction: InteractionType = .oneShotAction

    // Aligned only
    @Published var discreteCount: Int = 4            // 1...10

    // Phase only
    @Published var targetTravelMm: Int = 100         // 20...200 (mm)

    // 設計結果
    @Published var summary = DesignSummary()
    @Published var generated: TracePair = .empty
}

struct DesignSummary {
    var wMm: Double = 2.5
    var spacingMm: Double = 7.5
    var pitchMm: Double = 20.0
    var deltaDMm: Double = 10.0
    var feasible: Bool = true
    var bitLengthL: Int? = nil
}
