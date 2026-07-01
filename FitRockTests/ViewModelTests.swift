import XCTest
@testable import FitRock

final class ViewModelTests: XCTestCase {
    func testExerciseLibraryFiltersDbExercisesAndEquipments() {
        let repository = MockExerciseWorkoutRepository()
        repository.exercises = [
            Exercise(id: "bench", name: "杠铃卧推", bodyPart: .chest),
            Exercise(id: "squat", name: "深蹲", bodyPart: .legs)
        ]
        let localData = MockLocalExerciseDataProvider(
            equipments: [
                Equipment(
                    id: "smith",
                    nameZh: "史密斯机",
                    nameEn: "Smith Machine",
                    category: "strength",
                    targetMusclesZh: ["胸部"],
                    secondaryMusclesZh: [],
                    imageName: nil,
                    descriptionZh: "",
                    adjustmentsZh: [],
                    safetyTipsZh: [],
                    exerciseIds: ["bench"],
                    difficulty: "beginner"
                )
            ]
        )
        let viewModel = ExerciseLibraryViewModel(
            exerciseRepository: repository,
            workoutRepository: repository,
            localExerciseDataService: localData
        )

        viewModel.loadExercises()
        viewModel.selectedBodyPart = .chest
        XCTAssertEqual(viewModel.filteredExercises.map(\.name), ["杠铃卧推"])

        viewModel.searchText = "Smith"
        XCTAssertEqual(viewModel.filteredEquipments.map(\.id), ["smith"])
    }

    func testEquipmentSearchMatchesMusclesAndSafetyTips() {
        let repository = MockExerciseWorkoutRepository()
        let localData = MockLocalExerciseDataProvider(
            equipments: [
                Equipment(
                    id: "cable-row",
                    nameZh: "坐姿划船机",
                    nameEn: "Seated Row",
                    category: "strength",
                    targetMusclesZh: ["背部"],
                    secondaryMusclesZh: ["肱二头肌"],
                    imageName: nil,
                    descriptionZh: "训练上背部",
                    adjustmentsZh: [],
                    safetyTipsZh: ["保持脊柱中立"],
                    exerciseIds: ["seated-cable-row"],
                    difficulty: "beginner"
                )
            ]
        )
        let viewModel = ExerciseLibraryViewModel(
            exerciseRepository: repository,
            workoutRepository: repository,
            localExerciseDataService: localData
        )

        viewModel.searchText = "二头"
        XCTAssertEqual(viewModel.filteredEquipments.map(\.id), ["cable-row"])

        viewModel.searchText = "脊柱"
        XCTAssertEqual(viewModel.filteredEquipments.map(\.id), ["cable-row"])
    }

    func testStatsViewModelFallsBackOnLoadError() {
        let repository = MockStatsRepository()
        repository.shouldThrow = true
        let viewModel = StatsViewModel(
            workoutRepository: repository,
            personalRecordRepository: repository,
            prService: PRService(personalRecordRepository: repository, exerciseRepository: repository, workoutRepository: repository)
        )

        viewModel.loadStats(for: .week)

        XCTAssertEqual(viewModel.workoutCount, 0)
        XCTAssertTrue(viewModel.workouts.isEmpty)
    }

    func testStatsViewModelCanLoadAllTimeSummary() {
        let repository = MockStatsRepository()
        repository.workouts = [
            makeWorkout(id: "recent", daysAgo: 1),
            makeWorkout(id: "older", daysAgo: 45)
        ]
        let viewModel = StatsViewModel(
            workoutRepository: repository,
            personalRecordRepository: repository,
            prService: PRService(personalRecordRepository: repository, exerciseRepository: repository, workoutRepository: repository)
        )

        viewModel.loadStats(for: .all)

        XCTAssertEqual(viewModel.workoutCount, 2)
        XCTAssertEqual(viewModel.workouts.map(\.id), ["recent", "older"])
    }

    func testHomeViewModelLoadsRecentThreeWorkouts() {
        let repository = MockStatsRepository()
        repository.workouts = [
            makeWorkout(id: "first", daysAgo: 0),
            makeWorkout(id: "second", daysAgo: 1),
            makeWorkout(id: "third", daysAgo: 2),
            makeWorkout(id: "fourth", daysAgo: 3)
        ]
        let viewModel = HomeViewModel(
            workoutRepository: repository,
            prService: PRService(personalRecordRepository: repository, exerciseRepository: repository, workoutRepository: repository)
        )

        viewModel.loadData(for: Date())

        XCTAssertEqual(viewModel.recentWorkouts.map(\.id), ["first", "second", "third"])
    }

    func testHomeViewModelDeleteWorkoutRefreshesRecentAndSelectedDate() {
        let selectedDate = Date()
        let repository = MockStatsRepository()
        repository.workouts = [
            makeWorkout(id: "delete-me", startTime: selectedDate),
            makeWorkout(id: "keep", daysAgo: 1)
        ]
        let viewModel = HomeViewModel(
            workoutRepository: repository,
            prService: PRService(personalRecordRepository: repository, exerciseRepository: repository, workoutRepository: repository)
        )

        viewModel.loadData(for: selectedDate)
        viewModel.selectDate(selectedDate)
        XCTAssertEqual(viewModel.selectedDateWorkouts.map(\.id), ["delete-me"])

        viewModel.deleteWorkout("delete-me", displayedMonth: selectedDate)

        XCTAssertEqual(viewModel.recentWorkouts.map(\.id), ["keep"])
        XCTAssertTrue(viewModel.selectedDateWorkouts.isEmpty)
        XCTAssertTrue(repository.didRebuildPersonalRecords)
    }
}

private final class MockExerciseWorkoutRepository: ExerciseRepository, WorkoutRepository {
    var exercises: [Exercise] = []
    var savedWorkout: Workout?

    func connect() throws {}
    func getAllExercises() throws -> [Exercise] { exercises }
    func getExercise(by id: String) throws -> Exercise? { exercises.first { $0.id == id } }
    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit) throws {
        exercises.append(Exercise(name: name, bodyPart: bodyPart, isUserCreated: true, unit: unit))
    }
    func deleteExercise(_ exerciseId: String) throws { exercises.removeAll { $0.id == exerciseId } }
    func seedExercises() throws {}
    func saveWorkout(_ workout: Workout) throws { savedWorkout = workout }
    func getWorkouts(for date: Date) throws -> [Workout] { [] }
    func getAllCompletedWorkouts() throws -> [Workout] { [] }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { savedWorkout?.isCompleted == false }
    func getUnfinishedWorkout() throws -> Workout? { savedWorkout }
    func deleteWorkout(_ workoutIdValue: String) throws { savedWorkout = nil }
}

private final class MockStatsRepository: WorkoutRepository, PersonalRecordRepository, ExerciseRepository {
    var shouldThrow = false
    var workouts: [Workout] = []
    var didRebuildPersonalRecords = false

    func connect() throws {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
    }
    func saveWorkout(_ workout: Workout) throws {}
    func getWorkouts(for date: Date) throws -> [Workout] {
        let calendar = Calendar.current
        return workouts.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    func getAllCompletedWorkouts() throws -> [Workout] {
        workouts.sorted { $0.startTime > $1.startTime }
    }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { false }
    func getUnfinishedWorkout() throws -> Workout? { nil }
    func deleteWorkout(_ workoutIdValue: String) throws {
        workouts.removeAll { $0.id == workoutIdValue }
    }
    func getPersonalRecords() throws -> [PersonalRecord] { [] }
    func getPersonalRecords(for exerciseId: String) throws -> [PersonalRecord] { [] }
    func savePersonalRecord(_ record: PersonalRecord) throws {}
    func clearAllPersonalRecords() throws { didRebuildPersonalRecords = true }
    func savePersonalRecordEvent(_ event: PersonalRecordEvent) throws {}
    func getPersonalRecordEvents(for workoutId: String) throws -> [PersonalRecordEvent] { [] }
    func getAllExercises() throws -> [Exercise] { [] }
    func getExercise(by id: String) throws -> Exercise? { nil }
    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit) throws {}
    func deleteExercise(_ exerciseId: String) throws {}
    func seedExercises() throws {}
}

private func makeWorkout(id: String, daysAgo: Int) -> Workout {
    let startTime = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    return makeWorkout(id: id, startTime: startTime)
}

private func makeWorkout(id: String, startTime: Date) -> Workout {
    Workout(
        id: id,
        startTime: startTime,
        endTime: startTime.addingTimeInterval(3600),
        exercises: [
            WorkoutExercise(
                exerciseId: "bench",
                exerciseName: "杠铃卧推",
                bodyPart: .chest,
                sets: [
                    ExerciseSet(setNumber: 1, weight: 80, reps: 8, isCompleted: true)
                ]
            )
        ],
        isCompleted: true
    )
}

private struct MockLocalExerciseDataProvider: LocalExerciseDataProviding {
    var equipments: [Equipment]
    var exercises: [ExerciseInfo] = []
    var musclesZh: [String: String] = [:]

    func loadIfNeeded() {}
    func equipment(by id: String) -> Equipment? { equipments.first { $0.id == id } }
    func exercise(by id: String) -> ExerciseInfo? { exercises.first { $0.id == id } }
    func exercises(for equipmentId: String) -> [ExerciseInfo] { exercises.filter { $0.equipmentId == equipmentId } }
    func equipmentExerciseCount(_ equipmentId: String) -> Int { exercises(for: equipmentId).count }
    func chineseName(for englishMuscle: String) -> String { musclesZh[englishMuscle] ?? englishMuscle }
}
