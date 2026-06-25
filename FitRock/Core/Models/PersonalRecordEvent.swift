import Foundation

struct PersonalRecordEvent: Identifiable, Codable {
    let id: Int64
    let exerciseId: String
    let exerciseName: String
    let bodyPart: BodyPart
    let prType: PRType
    let oldValue: Double?
    let newValue: Double
    let weight: Double?
    let reps: Int?
    let volume: Double?
    let workoutId: String?
    let workoutExerciseId: String?
    let setId: String?
    let achievedAt: Date
    let createdAt: Date

    var isNewRecord: Bool {
        oldValue == nil
    }

    var improvement: Double {
        if let old = oldValue, old > 0 {
            return ((newValue - old) / old) * 100
        }
        return 0
    }

    var formattedNewValue: String {
        switch prType {
        case .maxWeight:
            return String(format: "%.1f kg", newValue)
        case .exerciseVolume:
            return String(format: "%.0f kg", newValue)
        case .duration:
            let totalSeconds = Int(newValue)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if minutes > 0 {
                return "\(minutes)分\(seconds)秒"
            }
            return "\(seconds)秒"
        }
    }

    var formattedImprovement: String {
        guard let old = oldValue, old > 0, newValue > old else { return "" }
        let pct = ((newValue - old) / old) * 100
        return String(format: "提高 %.1f%%", pct)
    }
}
