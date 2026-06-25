import Foundation

struct PersonalRecord: Identifiable, Codable {
    let id: Int64
    let exerciseId: String
    let exerciseName: String
    let bodyPart: BodyPart
    let prType: PRType
    let value: Double
    let weight: Double?
    let reps: Int?
    let volume: Double?
    let workoutId: String?
    let workoutExerciseId: String?
    let setId: String?
    let achievedAt: Date
    let createdAt: Date
    let updatedAt: Date

    var formattedValue: String {
        switch prType {
        case .maxWeight:
            return String(format: "%.1f kg", value)
        case .exerciseVolume:
            return String(format: "%.0f kg", value)
        case .duration:
            let totalSeconds = Int(value)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if minutes > 0 {
                return "\(minutes)分\(seconds)秒"
            }
            return "\(seconds)秒"
        }
    }

    var detailText: String {
        switch prType {
        case .maxWeight:
            if let w = weight, let r = reps {
                return String(format: "%.1f kg × %d 次", w, r)
            }
            return ""
        case .exerciseVolume:
            if let v = volume {
                return String(format: "总容量 %.0f kg", v)
            }
            return ""
        case .duration:
            return ""
        }
    }
}
