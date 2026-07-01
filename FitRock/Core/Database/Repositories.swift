import Foundation

protocol DatabaseConnecting {
    func connect() throws
}

protocol WorkoutRepository: DatabaseConnecting {
    func saveWorkout(_ workout: Workout) throws
    func getWorkouts(for date: Date) throws -> [Workout]
    func getAllCompletedWorkouts() throws -> [Workout]
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet]
    func hasUnfinishedWorkout() throws -> Bool
    func getUnfinishedWorkout() throws -> Workout?
    func deleteWorkout(_ workoutIdValue: String) throws
}

protocol ExerciseRepository: DatabaseConnecting {
    func getAllExercises() throws -> [Exercise]
    func getExercise(by id: String) throws -> Exercise?
    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit) throws
    func deleteExercise(_ exerciseId: String) throws
    func seedExercises() throws
}

extension ExerciseRepository {
    func saveUserExercise(name: String, bodyPart: BodyPart) throws {
        try saveUserExercise(name: name, bodyPart: bodyPart, unit: .weight)
    }
}

protocol TemplateRepository: DatabaseConnecting {
    func saveWorkoutTemplate(_ template: WorkoutTemplate, exercises: [WorkoutTemplateExercise], sets: [WorkoutTemplateSet]) throws
    func getWorkoutTemplates() throws -> [WorkoutTemplate]
    func getWorkoutTemplateDetail(templateId: String) throws -> (WorkoutTemplate, [WorkoutTemplateExercise], [WorkoutTemplateSet])?
    func deleteWorkoutTemplate(_ templateId: String) throws
    func createWorkoutFromTemplate(_ templateId: String) throws -> (Workout, [WorkoutExerciseDisplay])?
}

protocol PersonalRecordRepository: DatabaseConnecting {
    func getPersonalRecords() throws -> [PersonalRecord]
    func getPersonalRecords(for exerciseId: String) throws -> [PersonalRecord]
    func savePersonalRecord(_ record: PersonalRecord) throws
    func clearAllPersonalRecords() throws
    func savePersonalRecordEvent(_ event: PersonalRecordEvent) throws
    func getPersonalRecordEvents(for workoutId: String) throws -> [PersonalRecordEvent]
}

typealias FitRockRepository = WorkoutRepository & ExerciseRepository & TemplateRepository & PersonalRecordRepository
