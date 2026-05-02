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
