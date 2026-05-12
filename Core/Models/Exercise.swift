import Foundation

struct Exercise: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let bodyPart: BodyPart
    let description: String
    var isUserCreated: Bool
    var unit: ExerciseUnit

    init(id: String = UUID().uuidString, name: String, bodyPart: BodyPart, description: String = "", isUserCreated: Bool = false, unit: ExerciseUnit = .weight) {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
        self.description = description
        self.isUserCreated = isUserCreated
        self.unit = unit
    }
}
