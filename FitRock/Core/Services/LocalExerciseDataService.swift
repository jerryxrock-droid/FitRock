import Foundation

final class LocalExerciseDataService {
    static let shared = LocalExerciseDataService()

    private(set) var equipments: [Equipment] = []
    private(set) var exercises: [ExerciseInfo] = []
    private(set) var musclesZh: [String: String] = [:]

    private var equipmentDict: [String: Equipment] = [:]
    private var exerciseDict: [String: ExerciseInfo] = [:]
    private var exercisesByEquipment: [String: [ExerciseInfo]] = [:]
    private var isLoaded = false

    private init() {}

    func loadIfNeeded() {
        guard !isLoaded else { return }
        loadAll()
        isLoaded = true
    }

    func equipment(by id: String) -> Equipment? {
        loadIfNeeded()
        return equipmentDict[id]
    }

    func exercise(by id: String) -> ExerciseInfo? {
        loadIfNeeded()
        return exerciseDict[id]
    }

    func exercises(for equipmentId: String) -> [ExerciseInfo] {
        loadIfNeeded()
        return exercisesByEquipment[equipmentId] ?? []
    }

    func equipmentExerciseCount(_ equipmentId: String) -> Int {
        exercises(for: equipmentId).count
    }

    func chineseName(for englishMuscle: String) -> String {
        loadIfNeeded()
        return musclesZh[englishMuscle.lowercased()] ?? englishMuscle
    }

    // MARK: - Loading

    private func loadAll() {
        if let loaded: [Equipment] = loadJSON("equipments") {
            equipments = loaded
        }
        if let loaded: [ExerciseInfo] = loadJSON("exercises") {
            exercises = loaded
        }
        if let loaded: [String: String] = loadJSON("muscle_zh_map") {
            musclesZh = loaded
        }

        buildIndex()
    }

    private func loadJSON<T: Decodable>(_ filename: String) -> T? {
        // Bundle (flat, for Xcode group members — JSON is at bundle root)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
            return decode(from: url)
        }
        // Bundle subdirectory (for folder references)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Data") {
            return decode(from: url)
        }
        return nil
    }

    private func decode<T: Decodable>(from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[LocalExerciseDataService] Failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func buildIndex() {
        equipmentDict.removeAll()
        for eq in equipments {
            equipmentDict[eq.id] = eq
        }

        exerciseDict.removeAll()
        for ex in exercises {
            exerciseDict[ex.id] = ex
        }

        exercisesByEquipment.removeAll()
        for ex in exercises {
            guard let eid = ex.equipmentId else { continue }
            var list = exercisesByEquipment[eid] ?? []
            list.append(ex)
            exercisesByEquipment[eid] = list
        }
    }
}
