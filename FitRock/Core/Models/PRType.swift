import Foundation

enum PRType: String, Codable, CaseIterable {
    case maxWeight = "max_weight"
    case exerciseVolume = "exercise_volume"
    case duration = "duration"

    var displayName: String {
        switch self {
        case .maxWeight: return "最大重量"
        case .exerciseVolume: return "最高容量"
        case .duration: return "最长时长"
        }
    }

    var icon: String {
        switch self {
        case .maxWeight: return "arrow.up.circle.fill"
        case .exerciseVolume: return "chart.bar.fill"
        case .duration: return "clock.fill"
        }
    }

    var priority: Int {
        switch self {
        case .maxWeight: return 0
        case .exerciseVolume: return 1
        case .duration: return 2
        }
    }
}
