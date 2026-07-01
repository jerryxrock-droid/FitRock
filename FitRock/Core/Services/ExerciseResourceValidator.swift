import Foundation

struct ExerciseResourceValidationResult {
    let missingExerciseIds: [String]
    let missingImagePaths: [String]

    var isValid: Bool {
        missingExerciseIds.isEmpty && missingImagePaths.isEmpty
    }
}

struct ExerciseResourceValidator {
    func validate(equipments: [Equipment], exercises: [ExerciseInfo], imageExists: (String) -> Bool) -> ExerciseResourceValidationResult {
        let exerciseIds = Set(exercises.map(\.id))
        let missingExerciseIds = equipments
            .flatMap(\.exerciseIds)
            .filter { !exerciseIds.contains($0) }
            .sorted()

        let missingImagePaths = exercises
            .flatMap(\.images)
            .filter { !imageExists($0) }
            .sorted()

        return ExerciseResourceValidationResult(
            missingExerciseIds: Array(Set(missingExerciseIds)).sorted(),
            missingImagePaths: Array(Set(missingImagePaths)).sorted()
        )
    }
}
