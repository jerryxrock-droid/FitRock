import Foundation

final class ExerciseLibraryViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var searchText = ""
    @Published var selectedBodyPart: BodyPart?
    @Published var selectedMuscle: Muscle?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addToWorkoutResult: AddToWorkoutResult?
    @Published var catalogItems: [ExerciseCatalogItem] = []

    private let exerciseRepository: ExerciseRepository
    private let workoutRepository: WorkoutRepository
    private let localExerciseDataService: LocalExerciseDataProviding
    private let exerciseCatalogService: ExerciseCatalogProviding
    private let catalogFilter = ExerciseCatalogSearchFilter()
    private let searchScorer = ExerciseSearchScorer()

    init(
        exerciseRepository: ExerciseRepository = DatabaseManager.shared,
        workoutRepository: WorkoutRepository = DatabaseManager.shared,
        localExerciseDataService: LocalExerciseDataProviding = LocalExerciseDataService.shared,
        exerciseCatalogService: ExerciseCatalogProviding? = nil
    ) {
        self.exerciseRepository = exerciseRepository
        self.workoutRepository = workoutRepository
        self.localExerciseDataService = localExerciseDataService
        self.exerciseCatalogService = exerciseCatalogService ?? ExerciseCatalogService(
            exerciseRepository: exerciseRepository,
            localExerciseDataService: localExerciseDataService
        )
    }

    enum AddToWorkoutResult {
        case addedToExisting
        case startedNewWorkout
    }

    var filteredExercises: [Exercise] {
        if !catalogItems.isEmpty {
            return catalogFilter
                .filter(
                    catalogItems,
                    searchText: searchText,
                    selectedBodyPart: selectedBodyPart,
                    selectedMuscle: selectedMuscle
                )
                .compactMap(exerciseForCatalogItem)
        }

        var result = exercises
        if let bp = selectedBodyPart {
            result = result.filter { $0.bodyPart == bp }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var filteredCatalogItems: [ExerciseCatalogItem] {
        catalogFilter.filter(
            catalogItems,
            searchText: searchText,
            selectedBodyPart: selectedBodyPart,
            selectedMuscle: selectedMuscle
        )
    }

    func clearMuscleFilters() {
        selectedBodyPart = nil
        selectedMuscle = nil
    }

    // MARK: - Equipment Mode

    var filteredEquipments: [Equipment] {
        searchScorer.sortedEquipments(localExerciseDataService.equipments, query: searchText)
    }

    func loadExercises() {
        isLoading = true
        errorMessage = nil

        do {
            try exerciseRepository.connect()
            exercises = try exerciseRepository.getAllExercises()
            catalogItems = try exerciseCatalogService.loadCatalogItems()
        } catch {
            errorMessage = "加载动作失败：\(error.localizedDescription)"
            exercises = []
            catalogItems = []
        }

        isLoading = false
    }

    // MARK: - Add to Workout

    func addExerciseToWorkout(_ exercise: Exercise) throws {
        try workoutRepository.connect()

        if try workoutRepository.hasUnfinishedWorkout() {
            // Add to existing workout
            guard var workout = try workoutRepository.getUnfinishedWorkout() else {
                throw ExerciseLibraryError.noWorkoutFound
            }

            let workoutExercise = WorkoutExercise(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart
            )
            workout.exercises.append(workoutExercise)
            try workoutRepository.saveWorkout(workout)

            addToWorkoutResult = .addedToExisting
        } else {
            // Start a new workout
            var workout = Workout(startTime: Date())
            let workoutExercise = WorkoutExercise(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart
            )
            workout.exercises.append(workoutExercise)
            try workoutRepository.saveWorkout(workout)

            addToWorkoutResult = .startedNewWorkout
        }
    }

    private func exerciseForCatalogItem(_ item: ExerciseCatalogItem) -> Exercise? {
        guard let bodyPart = item.bodyPart else { return nil }
        return Exercise(
            id: item.recordExerciseId,
            name: item.nameZh,
            bodyPart: bodyPart,
            isUserCreated: item.isUserCreated,
            unit: item.unit
        )
    }
}

enum ExerciseLibraryError: LocalizedError {
    case noWorkoutFound

    var errorDescription: String? {
        switch self {
        case .noWorkoutFound:
            return "找不到进行中的训练"
        }
    }
}
