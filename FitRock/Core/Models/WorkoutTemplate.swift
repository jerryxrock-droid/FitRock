import Foundation

struct WorkoutTemplate: Identifiable, Codable {
    let id: String
    var name: String
    var note: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, name: String, note: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct WorkoutTemplateExercise: Identifiable, Codable {
    let id: String
    let templateId: String
    let exerciseId: String
    var exerciseName: String
    let bodyPart: BodyPart
    var sortOrder: Int
    let unit: ExerciseUnit

    init(id: String = UUID().uuidString, templateId: String, exerciseId: String, exerciseName: String, bodyPart: BodyPart, sortOrder: Int, unit: ExerciseUnit = .weight) {
        self.id = id
        self.templateId = templateId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.bodyPart = bodyPart
        self.sortOrder = sortOrder
        self.unit = unit
    }
}

struct WorkoutTemplateSet: Identifiable, Codable {
    let id: String
    let templateExerciseId: String
    var setNumber: Int
    var weight: Double
    var reps: Int
    var setType: ExerciseSetType
    var restSeconds: Int?

    init(id: String = UUID().uuidString, templateExerciseId: String, setNumber: Int, weight: Double = 0, reps: Int = 10, setType: ExerciseSetType = .normal, restSeconds: Int? = nil) {
        self.id = id
        self.templateExerciseId = templateExerciseId
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.setType = setType
        self.restSeconds = restSeconds
    }
}