import Foundation

final class ExerciseLibraryViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var searchText = ""
    @Published var selectedBodyPart: BodyPart?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addToWorkoutResult: AddToWorkoutResult?

    private let db = DatabaseManager.shared

    enum AddToWorkoutResult {
        case addedToExisting
        case startedNewWorkout
    }

    var filteredExercises: [Exercise] {
        var result = exercises

        if let bp = selectedBodyPart {
            result = result.filter { $0.bodyPart == bp }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    // MARK: - Equipment Mode

    var filteredEquipments: [Equipment] {
        let dataService = LocalExerciseDataService.shared
        if searchText.isEmpty {
            return dataService.equipments
        }
        return dataService.equipments.filter {
            $0.nameZh.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEn.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadExercises() {
        isLoading = true
        errorMessage = nil

        do {
            try db.connect()
            exercises = try db.getAllExercises()
        } catch {
            errorMessage = "加载动作失败：\(error.localizedDescription)"
            exercises = []
        }

        isLoading = false
    }

    // MARK: - Add to Workout

    func addExerciseToWorkout(_ exercise: Exercise) throws {
        try db.connect()

        if try db.hasUnfinishedWorkout() {
            // Add to existing workout
            guard var workout = try db.getUnfinishedWorkout() else {
                throw ExerciseLibraryError.noWorkoutFound
            }

            let workoutExercise = WorkoutExercise(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart
            )
            workout.exercises.append(workoutExercise)
            try db.saveWorkout(workout)

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
            try db.saveWorkout(workout)

            addToWorkoutResult = .startedNewWorkout
        }
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
