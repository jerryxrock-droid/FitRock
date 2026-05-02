import Foundation

struct ExerciseSet: Identifiable, Codable, Equatable {
    let id: String
    var setNumber: Int
    var weight: Double
    var reps: Int
    var setType: ExerciseSetType
    var isCompleted: Bool

    init(id: String = UUID().uuidString, setNumber: Int, weight: Double = 0, reps: Int = 0, setType: ExerciseSetType = .normal, isCompleted: Bool = false) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.setType = setType
        self.isCompleted = isCompleted
    }
}

struct ExerciseSetDisplay: Identifiable {
    let id: String
    let setNumber: Int
    let weight: Double
    let reps: Int
    let setType: ExerciseSetType

    init(from set: ExerciseSet) {
        self.id = set.id
        self.setNumber = set.setNumber
        self.weight = set.weight
        self.reps = set.reps
        self.setType = set.setType
    }
}
