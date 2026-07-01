import Foundation

enum TrainingPlanGoal: String, Codable, CaseIterable {
    case ppl
    case fullBody
    case hypertrophy
    case fatLoss

    var displayName: String {
        switch self {
        case .ppl: return "Push/Pull/Legs"
        case .fullBody: return "全身训练"
        case .hypertrophy: return "增肌"
        case .fatLoss: return "减脂"
        }
    }
}

enum TrainingPlanDayStatus: String, Codable, CaseIterable {
    case planned
    case completed
    case skipped
    case moved
    case rest

    var displayName: String {
        switch self {
        case .planned: return "计划中"
        case .completed: return "已完成"
        case .skipped: return "已跳过"
        case .moved: return "已调整"
        case .rest: return "休息"
        }
    }
}

struct TrainingPlan: Identifiable, Codable {
    let id: String
    var name: String
    var goal: TrainingPlanGoal
    var trainingDaysPerWeek: Int
    var recommendationReason: String
    var startDate: Date
    var endDate: Date
    var weeks: [TrainingPlanWeek]
    var healthSnapshot: HealthMetricsSnapshot?
    var recommendedSessionMinutes: Int?
    var equipmentPreference: TrainingEquipmentPreference?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        goal: TrainingPlanGoal,
        trainingDaysPerWeek: Int,
        recommendationReason: String,
        startDate: Date,
        endDate: Date,
        weeks: [TrainingPlanWeek],
        healthSnapshot: HealthMetricsSnapshot? = nil,
        recommendedSessionMinutes: Int? = nil,
        equipmentPreference: TrainingEquipmentPreference? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.recommendationReason = recommendationReason
        self.startDate = startDate
        self.endDate = endDate
        self.weeks = weeks
        self.healthSnapshot = healthSnapshot
        self.recommendedSessionMinutes = recommendedSessionMinutes
        self.equipmentPreference = equipmentPreference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TrainingPlanWeek: Identifiable, Codable {
    let id: String
    var weekIndex: Int
    var days: [TrainingPlanDay]

    init(id: String = UUID().uuidString, weekIndex: Int, days: [TrainingPlanDay]) {
        self.id = id
        self.weekIndex = weekIndex
        self.days = days
    }
}

struct TrainingPlanDay: Identifiable, Codable {
    let id: String
    var date: Date
    var sequenceIndex: Int?
    var availableFrom: Date?
    var availableUntil: Date?
    var title: String
    var targetBodyParts: [BodyPart]
    var suggestedExerciseNames: [String]
    var status: TrainingPlanDayStatus
    var matchedWorkoutId: String?
    var completedAt: Date?
    var note: String?

    init(
        id: String = UUID().uuidString,
        date: Date,
        sequenceIndex: Int? = nil,
        availableFrom: Date? = nil,
        availableUntil: Date? = nil,
        title: String,
        targetBodyParts: [BodyPart],
        suggestedExerciseNames: [String],
        status: TrainingPlanDayStatus = .planned,
        matchedWorkoutId: String? = nil,
        completedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sequenceIndex = sequenceIndex
        self.availableFrom = availableFrom
        self.availableUntil = availableUntil
        self.title = title
        self.targetBodyParts = targetBodyParts
        self.suggestedExerciseNames = suggestedExerciseNames
        self.status = status
        self.matchedWorkoutId = matchedWorkoutId
        self.completedAt = completedAt
        self.note = note
    }

    var isTrainingSession: Bool {
        status != .rest
    }
}

struct TrainingPlanCompletion {
    let completed: Int
    let skipped: Int
    let planned: Int
    let rest: Int

    var completionRate: Double {
        let total = completed + skipped + planned
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

struct HealthMetricsSnapshot: Codable, Equatable {
    var bodyMassKg: Double?
    var averageHeartRate: Double?
    var restingHeartRate: Double?
    var activeEnergyKcal30d: Double?
    var capturedAt: Date

    static let empty = HealthMetricsSnapshot(
        bodyMassKg: nil,
        averageHeartRate: nil,
        restingHeartRate: nil,
        activeEnergyKcal30d: nil,
        capturedAt: Date()
    )
}
