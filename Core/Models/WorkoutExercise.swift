import Foundation

struct WorkoutExercise: Identifiable, Codable {
    let id: String
    let exerciseId: String
    var exerciseName: String
    let bodyPart: BodyPart
    var sets: [ExerciseSet]

    init(id: String = UUID().uuidString, exerciseId: String, exerciseName: String, bodyPart: BodyPart, sets: [ExerciseSet] = []) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.bodyPart = bodyPart
        self.sets = sets
    }
}

struct WorkoutExerciseDisplay: Identifiable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    let bodyPart: BodyPart
    let unit: ExerciseUnit
    let sets: [ExerciseSetDisplay]
    let lastSets: [ExerciseSetDisplay]?

    init(from workoutExercise: WorkoutExercise, lastSets: [ExerciseSetDisplay]? = nil, unit: ExerciseUnit = .weight) {
        self.id = workoutExercise.id
        self.exerciseId = workoutExercise.exerciseId
        self.exerciseName = workoutExercise.exerciseName
        self.bodyPart = workoutExercise.bodyPart
        self.unit = unit
        self.sets = workoutExercise.sets.map { ExerciseSetDisplay(from: $0) }
        self.lastSets = lastSets
    }
}
