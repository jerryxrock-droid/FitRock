import Foundation

struct Workout: Identifiable, Codable {
    let id: String
    var startTime: Date
    var endTime: Date?
    var exercises: [WorkoutExercise]
    var isCompleted: Bool

    init(id: String = UUID().uuidString, startTime: Date = Date(), endTime: Date? = nil, exercises: [WorkoutExercise] = [], isCompleted: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.exercises = exercises
        self.isCompleted = isCompleted
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: startTime)
    }

    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var totalSets: Int {
        exercises.flatMap { $0.sets }.filter { $0.setType != .warmup }.count
    }
}
