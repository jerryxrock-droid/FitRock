import Foundation

struct Equipment: Identifiable, Codable {
    let id: String
    let nameZh: String
    let nameEn: String
    let category: String
    let targetMusclesZh: [String]
    let secondaryMusclesZh: [String]
    let imageName: String?
    let descriptionZh: String
    let adjustmentsZh: [String]
    let safetyTipsZh: [String]
    let exerciseIds: [String]
    let difficulty: String
}
