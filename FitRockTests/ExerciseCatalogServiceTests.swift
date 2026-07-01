import XCTest
@testable import FitRock

final class ExerciseCatalogServiceTests: XCTestCase {
    func testBuildsStableIdsForDbUserAndJsonItems() throws {
        let repository = MockCatalogExerciseRepository()
        repository.exercises = [
            Exercise(id: "bench", name: "杠铃卧推", bodyPart: .chest, isUserCreated: false, unit: .weight),
            Exercise(id: "custom", name: "自定义动作", bodyPart: .core, isUserCreated: true, unit: .reps)
        ]
        let localData = MockCatalogLocalData(exercises: [
            ExerciseInfo(
                id: "seated-cable-row",
                nameEn: "Seated Cable Row",
                nameZh: "坐姿绳索划船",
                equipmentId: "cable-row",
                equipmentType: "machine",
                primaryMuscles: ["middle back"],
                primaryMusclesZh: ["中背"],
                secondaryMuscles: ["biceps"],
                secondaryMusclesZh: ["肱二头肌"],
                images: ["Seated_Cable_Rows/0.jpg"],
                stepsZh: [],
                commonMistakesZh: [],
                difficulty: "beginner"
            )
        ])
        let service = ExerciseCatalogService(exerciseRepository: repository, localExerciseDataService: localData)

        let items = try service.loadCatalogItems()

        XCTAssertTrue(items.contains { $0.catalogId == "db:bench" && $0.source == .db && $0.dbExerciseId == "bench" })
        XCTAssertTrue(items.contains { $0.catalogId == "user:custom" && $0.source == .user && $0.unit == .reps })
        XCTAssertTrue(items.contains { $0.catalogId == "json:seated-cable-row" && $0.source == .json && $0.equipmentId == "cable-row" && !$0.images.isEmpty })
    }

    func testSameNameDbAndJsonDoNotCollide() throws {
        let repository = MockCatalogExerciseRepository()
        repository.exercises = [Exercise(id: "row-db", name: "坐姿划船", bodyPart: .back)]
        let localData = MockCatalogLocalData(exercises: [
            ExerciseInfo(
                id: "row-json",
                nameEn: "Seated Cable Row",
                nameZh: "坐姿划船",
                equipmentId: nil,
                equipmentType: nil,
                primaryMuscles: ["middle back"],
                primaryMusclesZh: ["中背"],
                secondaryMuscles: [],
                secondaryMusclesZh: [],
                images: [],
                stepsZh: [],
                commonMistakesZh: [],
                difficulty: "beginner"
            )
        ])

        let items = try ExerciseCatalogService(exerciseRepository: repository, localExerciseDataService: localData).loadCatalogItems()

        XCTAssertEqual(Set(items.map(\.catalogId)), ["db:row-db", "json:row-json"])
    }
}

private final class MockCatalogExerciseRepository: ExerciseRepository {
    var exercises: [Exercise] = []

    func connect() throws {}
    func getAllExercises() throws -> [Exercise] { exercises }
    func getExercise(by id: String) throws -> Exercise? { exercises.first { $0.id == id } }
    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit) throws {}
    func deleteExercise(_ exerciseId: String) throws {}
    func seedExercises() throws {}
}

private struct MockCatalogLocalData: LocalExerciseDataProviding {
    var equipments: [Equipment] = []
    var exercises: [ExerciseInfo]
    var musclesZh: [String: String] = [:]

    func loadIfNeeded() {}
    func equipment(by id: String) -> Equipment? { nil }
    func exercise(by id: String) -> ExerciseInfo? { exercises.first { $0.id == id } }
    func exercises(for equipmentId: String) -> [ExerciseInfo] { exercises.filter { $0.equipmentId == equipmentId } }
    func equipmentExerciseCount(_ equipmentId: String) -> Int { exercises(for: equipmentId).count }
    func chineseName(for englishMuscle: String) -> String { musclesZh[englishMuscle] ?? englishMuscle }
}
