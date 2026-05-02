import Foundation

struct Exercise: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let bodyPart: BodyPart
    let description: String

    init(id: String = UUID().uuidString, name: String, bodyPart: BodyPart, description: String = "") {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
        self.description = description
    }
}
