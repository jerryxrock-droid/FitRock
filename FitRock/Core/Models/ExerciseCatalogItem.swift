import Foundation

enum ExerciseCatalogSource: String, Codable, CaseIterable {
    case db
    case json
    case user
}

struct ExerciseCatalogItem: Identifiable, Codable, Equatable {
    let catalogId: String
    let source: ExerciseCatalogSource
    let dbExerciseId: String?
    let jsonExerciseId: String?
    let nameZh: String
    let nameEn: String?
    let bodyPart: BodyPart?
    let unit: ExerciseUnit
    let equipmentId: String?
    let equipmentNameZh: String?
    let equipmentNameEn: String?
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]
    let isUserCreated: Bool
    let images: [String]

    var id: String { catalogId }

    var recordExerciseId: String {
        switch source {
        case .db, .user:
            return dbExerciseId ?? catalogId
        case .json:
            return "json:\(jsonExerciseId ?? catalogId)"
        }
    }
}
