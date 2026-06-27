import Foundation

struct ExerciseInfo: Identifiable, Codable {
    let id: String
    let nameEn: String
    let nameZh: String
    let equipmentId: String?
    let equipmentType: String?
    let primaryMuscles: [String]
    let primaryMusclesZh: [String]
    let secondaryMuscles: [String]
    let secondaryMusclesZh: [String]
    let images: [String]
    let stepsZh: [String]
    let commonMistakesZh: [String]
    let difficulty: String
}
