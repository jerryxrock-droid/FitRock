import Foundation

enum BodyPart: String, CaseIterable, Codable {
    case chest = "chest"
    case back = "back"
    case shoulders = "shoulders"
    case arms = "arms"
    case legs = "legs"
    case core = "core"
    case cardio = "cardio"
}

enum ExerciseSetType: String, Codable {
    case normal
    case warmup
    case dropSet
}

enum ExerciseUnit: String, Codable, CaseIterable {
    case weight  // kg
    case reps    // 次数
    case duration // 分钟

    var displayName: String {
        switch self {
        case .weight: return "kg"
        case .reps: return "次"
        case .duration: return "分钟"
        }
    }
}
