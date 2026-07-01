import XCTest
@testable import FitRock

final class RecordViewModelCatalogTests: XCTestCase {
    func testAddingDbCatalogItemStoresOriginalDbId() {
        let repository = MockRecordCatalogRepository()
        let viewModel = RecordViewModel(
            workoutRepository: repository,
            exerciseRepository: repository,
            templateRepository: repository,
            workoutTimer: MockCatalogWorkoutTimer()
        )

        viewModel.startWorkout()
        viewModel.addExercise(catalogItem(source: .db, dbId: "bench", jsonId: nil, name: "杠铃卧推", bodyPart: .chest))

        XCTAssertEqual(viewModel.currentWorkout?.exercises.first?.exerciseId, "bench")
    }

    func testAddingJsonCatalogItemStoresJsonPrefixedId() {
        let repository = MockRecordCatalogRepository()
        let viewModel = RecordViewModel(
            workoutRepository: repository,
            exerciseRepository: repository,
            templateRepository: repository,
            workoutTimer: MockCatalogWorkoutTimer()
        )

        viewModel.startWorkout()
        viewModel.addExercise(catalogItem(source: .json, dbId: nil, jsonId: "seated-cable-row", name: "坐姿绳索划船", bodyPart: .back))

        XCTAssertEqual(viewModel.currentWorkout?.exercises.first?.exerciseId, "json:seated-cable-row")
        XCTAssertEqual(viewModel.currentWorkout?.exercises.first?.exerciseName, "坐姿绳索划船")
    }

    func testDuplicateCatalogItemIsIgnoredByRecordExerciseId() {
        let repository = MockRecordCatalogRepository()
        let viewModel = RecordViewModel(
            workoutRepository: repository,
            exerciseRepository: repository,
            templateRepository: repository,
            workoutTimer: MockCatalogWorkoutTimer()
        )
        let item = catalogItem(source: .json, dbId: nil, jsonId: "row", name: "坐姿绳索划船", bodyPart: .back)

        viewModel.startWorkout()
        viewModel.addExercise(item)
        viewModel.addExercise(item)

        XCTAssertEqual(viewModel.currentWorkout?.exercises.count, 1)
    }

    func testStartingWorkoutFromPlanStoresPlanSourceAndAddsSuggestedExercises() {
        let repository = MockRecordCatalogRepository()
        let catalogService = MockPlanCatalogService(items: [
            catalogItem(source: .db, dbId: "bench", jsonId: nil, name: "杠铃卧推", bodyPart: .chest)
        ])
        let viewModel = RecordViewModel(
            workoutRepository: repository,
            exerciseRepository: repository,
            templateRepository: repository,
            workoutTimer: MockCatalogWorkoutTimer(),
            exerciseCatalogService: catalogService
        )
        let day = TrainingPlanDay(
            id: "day-1",
            date: Date(),
            title: "Push",
            targetBodyParts: [.chest],
            suggestedExerciseNames: ["杠铃卧推"]
        )

        viewModel.startWorkoutFromPlan(day: day, planId: "plan-1")

        XCTAssertTrue(viewModel.isWorkoutActive)
        XCTAssertEqual(viewModel.currentWorkout?.trainingPlanId, "plan-1")
        XCTAssertEqual(viewModel.currentWorkout?.plannedDayId, "day-1")
        XCTAssertEqual(viewModel.currentWorkout?.exercises.first?.exerciseId, "bench")
        XCTAssertEqual(repository.savedWorkout?.trainingPlanId, "plan-1")
    }

    private func catalogItem(
        source: ExerciseCatalogSource,
        dbId: String?,
        jsonId: String?,
        name: String,
        bodyPart: BodyPart?
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogId: "\(source.rawValue):\(dbId ?? jsonId ?? name)",
            source: source,
            dbExerciseId: dbId,
            jsonExerciseId: jsonId,
            nameZh: name,
            nameEn: nil,
            bodyPart: bodyPart,
            unit: .weight,
            equipmentId: nil,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            isUserCreated: source == .user,
            images: []
        )
    }
}

private final class MockRecordCatalogRepository: WorkoutRepository, ExerciseRepository, TemplateRepository {
    var savedWorkout: Workout?

    func connect() throws {}
    func saveWorkout(_ workout: Workout) throws { savedWorkout = workout }
    func getWorkouts(for date: Date) throws -> [Workout] { [] }
    func getAllCompletedWorkouts() throws -> [Workout] { [] }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { false }
    func getUnfinishedWorkout() throws -> Workout? { nil }
    func deleteWorkout(_ workoutIdValue: String) throws {}
    func getAllExercises() throws -> [Exercise] { [] }
    func getExercise(by id: String) throws -> Exercise? { nil }
    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit) throws {}
    func deleteExercise(_ exerciseId: String) throws {}
    func seedExercises() throws {}
    func saveWorkoutTemplate(_ template: WorkoutTemplate, exercises: [WorkoutTemplateExercise], sets: [WorkoutTemplateSet]) throws {}
    func getWorkoutTemplates() throws -> [WorkoutTemplate] { [] }
    func getWorkoutTemplateDetail(templateId: String) throws -> (WorkoutTemplate, [WorkoutTemplateExercise], [WorkoutTemplateSet])? { nil }
    func deleteWorkoutTemplate(_ templateId: String) throws {}
    func createWorkoutFromTemplate(_ templateId: String) throws -> (Workout, [WorkoutExerciseDisplay])? { nil }
}

private final class MockCatalogWorkoutTimer: WorkoutTiming {
    var onTick: ((TimeInterval) -> Void)?
    func start(from startDate: Date) {}
    func stop() {}
}

private struct MockPlanCatalogService: ExerciseCatalogProviding {
    let items: [ExerciseCatalogItem]

    func loadCatalogItems() throws -> [ExerciseCatalogItem] {
        items
    }
}
