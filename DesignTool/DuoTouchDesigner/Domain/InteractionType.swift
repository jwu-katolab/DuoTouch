enum InteractionType: String, CaseIterable, Identifiable {
    case oneShotAction
    case twoStateToggle
    case directionalNavigation
    case scalarAdjustment
    case cyclicAdjustment
    var id: String { rawValue }

    var isAligned: Bool {
        switch self {
        case .oneShotAction, .twoStateToggle, .directionalNavigation: return true
        default: return false
        }
    }
    var isPhase: Bool { !isAligned }
}
