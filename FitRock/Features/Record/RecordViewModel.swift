import SwiftUI
import Combine

final class RecordViewModel: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var currentWorkout: Workout?
    @Published var workoutExercises: [WorkoutExerciseDisplay] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var pendingNewPRs: [PersonalRecordEvent] = []

    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository
    private let templateRepository: TemplateRepository
    private let prService: PRService
    private let workoutTimer: WorkoutTiming
    private let trainingPlanRepository: TrainingPlanRepository
    private let trainingPlanCompletionMatcher: TrainingPlanCompletionMatcher
    private let exerciseCatalogService: ExerciseCatalogProviding
    private let exerciseSearchScorer = ExerciseSearchScorer()
    private var expandedIds: Set<String> = []
    private var workoutStartTime: Date?

    init(
        workoutRepository: WorkoutRepository = DatabaseManager.shared,
        exerciseRepository: ExerciseRepository = DatabaseManager.shared,
        templateRepository: TemplateRepository = DatabaseManager.shared,
        prService: PRService = .shared,
        workoutTimer: WorkoutTiming = WorkoutTimer(),
        trainingPlanRepository: TrainingPlanRepository = UserDefaultsTrainingPlanRepository.shared,
        trainingPlanCompletionMatcher: TrainingPlanCompletionMatcher = TrainingPlanCompletionMatcher(),
        exerciseCatalogService: ExerciseCatalogProviding = ExerciseCatalogService()
    ) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.templateRepository = templateRepository
        self.prService = prService
        self.workoutTimer = workoutTimer
        self.trainingPlanRepository = trainingPlanRepository
        self.trainingPlanCompletionMatcher = trainingPlanCompletionMatcher
        self.exerciseCatalogService = exerciseCatalogService
        self.workoutTimer.onTick = { [weak self] elapsedTime in
            self?.elapsedTime = elapsedTime
        }
    }

    var totalSets: Int {
        workoutExercises.flatMap { $0.sets }.filter { $0.setType != .warmup }.count
    }

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startWorkout() {
        let workout = Workout()
        workoutStartTime = Date()
        currentWorkout = workout
        isWorkoutActive = true
        workoutExercises = []
        elapsedTime = 0

        startTimer()

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error starting workout: \(error)")
        }

        Haptic.medium.trigger()
    }

    func resumeWorkout(from workout: Workout) {
        workoutStartTime = workout.startTime
        currentWorkout = workout
        isWorkoutActive = true
        elapsedTime = Date().timeIntervalSince(workout.startTime)
        expandedIds = []

        do {
            try workoutRepository.connect()
            workoutExercises = try workout.exercises.map { we in
                let lastSets = try workoutRepository.getLastWorkoutSets(for: we.exerciseId)
                let exercise = try exerciseRepository.getExercise(by: we.exerciseId)
                return WorkoutExerciseDisplay(
                    from: we,
                    lastSets: lastSets.map { ExerciseSetDisplay(from: $0) },
                    unit: exercise?.unit ?? .weight
                )
            }
        } catch {
            print("Error resuming workout: \(error)")
            workoutExercises = workout.exercises.map { WorkoutExerciseDisplay(from: $0, lastSets: nil) }
        }

        for we in workoutExercises {
            expandedIds.insert(we.id)
        }

        startTimer()
        Haptic.success.trigger()
    }

    func finishWorkout() {
        stopTimer()

        guard var workout = currentWorkout else { return }

        workout.endTime = Date()
        workout.isCompleted = true
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
            pendingNewPRs = try prService.evaluateAndSave(workout: workout)
            try autoMatchTrainingPlan(for: workout)
        } catch {
            print("Error finishing workout: \(error)")
            pendingNewPRs = []
        }

        Haptic.success.trigger()
    }

    func dismissWorkoutSummary() {
        pendingNewPRs = []
        currentWorkout = nil
        isWorkoutActive = false
        workoutExercises = []
        expandedIds = []
        workoutStartTime = nil
    }

    func cancelWorkout() {
        stopTimer()

        if let workout = currentWorkout {
            try? workoutRepository.deleteWorkout(workout.id)
        }

        currentWorkout = nil
        isWorkoutActive = false
        workoutExercises = []
        expandedIds = []
        workoutStartTime = nil

        Haptic.medium.trigger()
    }

    func addExercise(_ exercise: Exercise) {
        let item = ExerciseCatalogItem(
            catalogId: exercise.isUserCreated ? "user:\(exercise.id)" : "db:\(exercise.id)",
            source: exercise.isUserCreated ? .user : .db,
            dbExerciseId: exercise.id,
            jsonExerciseId: nil,
            nameZh: exercise.name,
            nameEn: nil,
            bodyPart: exercise.bodyPart,
            unit: exercise.unit,
            equipmentId: nil,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: ExerciseMuscleMappingProvider.mapping(for: exercise.bodyPart).primaryMuscles,
            secondaryMuscles: ExerciseMuscleMappingProvider.mapping(for: exercise.bodyPart).secondaryMuscles,
            isUserCreated: exercise.isUserCreated,
            images: []
        )
        addExercise(item)
    }

    func addExercise(_ item: ExerciseCatalogItem) {
        guard var workout = currentWorkout else { return }
        guard let bodyPart = item.bodyPart else { return }
        let recordExerciseId = item.recordExerciseId
        guard !workout.exercises.contains(where: { $0.exerciseId == recordExerciseId }) else { return }

        let workoutExercise = WorkoutExercise(
            exerciseId: recordExerciseId,
            exerciseName: item.nameZh,
            bodyPart: bodyPart
        )

        workout.exercises.append(workoutExercise)
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error adding exercise: \(error)")
        }

        loadWorkoutExercises()
        Haptic.light.trigger()
    }

    func deleteExercise(_ workoutExercise: WorkoutExerciseDisplay) {
        guard var workout = currentWorkout else { return }

        workout.exercises.removeAll { $0.id == workoutExercise.id }
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error deleting exercise: \(error)")
        }

        loadWorkoutExercises()
    }

    func updateExerciseName(_ workoutExercise: WorkoutExerciseDisplay, newName: String) {
        guard var workout = currentWorkout,
              let index = workout.exercises.firstIndex(where: { $0.id == workoutExercise.id }) else { return }

        workout.exercises[index].exerciseName = newName
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error updating exercise name: \(error)")
        }

        loadWorkoutExercises()
    }

    func saveAsUserExercise(name: String, bodyPart: BodyPart) {
        do {
            try exerciseRepository.connect()
            try exerciseRepository.saveUserExercise(name: name, bodyPart: bodyPart)
            Haptic.success.trigger()
        } catch {
            print("Error saving user exercise: \(error)")
        }
    }

    func addSet(to workoutExercise: WorkoutExerciseDisplay, prefill: Bool) {
        guard var workout = currentWorkout,
              let index = workout.exercises.firstIndex(where: { $0.id == workoutExercise.id }) else { return }

        let lastSetNumber = workout.exercises[index].sets.count + 1

        // Pre-fill with last workout's values if enabled
        var defaultWeight: Double = 0
        var defaultReps: Int = 0
        if prefill, let lastSet = workoutExercise.lastSets?.last {
            defaultWeight = lastSet.weight
            defaultReps = lastSet.reps
        }

        let newSet = ExerciseSet(setNumber: lastSetNumber, weight: defaultWeight, reps: defaultReps)

        workout.exercises[index].sets.append(newSet)
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error adding set: \(error)")
        }

        loadWorkoutExercises()
        expandedIds.insert(workoutExercise.id)
        Haptic.light.trigger()
    }

    func deleteSet(_ setId: String, from workoutExercise: WorkoutExerciseDisplay) {
        guard var workout = currentWorkout,
              let index = workout.exercises.firstIndex(where: { $0.id == workoutExercise.id }) else { return }

        workout.exercises[index].sets.removeAll { $0.id == setId }

        for i in 0..<workout.exercises[index].sets.count {
            workout.exercises[index].sets[i].setNumber = i + 1
        }

        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error deleting set: \(error)")
        }

        loadWorkoutExercises()
    }

    func updateSet(_ setId: String, weight: Double, reps: Int, in workoutExercise: WorkoutExerciseDisplay) {
        guard var workout = currentWorkout,
              let weIndex = workout.exercises.firstIndex(where: { $0.id == workoutExercise.id }),
              let setIndex = workout.exercises[weIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        workout.exercises[weIndex].sets[setIndex].weight = weight
        workout.exercises[weIndex].sets[setIndex].reps = reps
        workout.exercises[weIndex].sets[setIndex].isCompleted = true
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error updating set: \(error)")
        }
    }

    func toggleWarmUp(_ setId: String, in workoutExercise: WorkoutExerciseDisplay) {
        guard var workout = currentWorkout,
              let weIndex = workout.exercises.firstIndex(where: { $0.id == workoutExercise.id }),
              let setIndex = workout.exercises[weIndex].sets.firstIndex(where: { $0.id == setId }) else { return }

        let currentType = workout.exercises[weIndex].sets[setIndex].setType
        workout.exercises[weIndex].sets[setIndex].setType = currentType == .warmup ? .normal : .warmup
        currentWorkout = workout

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error toggling warm up: \(error)")
        }

        loadWorkoutExercises()
        Haptic.light.trigger()
    }

    func toggleExpand(for id: String) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    func isExpanded(_ id: String) -> Bool {
        expandedIds.contains(id)
    }

    func startWorkoutFromTemplate(_ templateId: String) {
        do {
            try templateRepository.connect()
            guard let result = try templateRepository.createWorkoutFromTemplate(templateId) else { return }
            let (workout, exercisesDisplay) = result

            workoutStartTime = workout.startTime
            currentWorkout = workout
            isWorkoutActive = true
            workoutExercises = exercisesDisplay
            elapsedTime = 0
            expandedIds = Set(exercisesDisplay.map { $0.id })

            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
            startTimer()
            Haptic.success.trigger()
        } catch {
            print("Error starting workout from template: \(error)")
        }
    }

    func startWorkoutFromPlan(day: TrainingPlanDay, planId: String) {
        var workout = Workout(trainingPlanId: planId, plannedDayId: day.id)
        workoutStartTime = workout.startTime
        workout.exercises = plannedExercises(for: day)
        currentWorkout = workout
        isWorkoutActive = true
        elapsedTime = 0
        expandedIds = []

        do {
            try workoutRepository.connect()
            try workoutRepository.saveWorkout(workout)
        } catch {
            print("Error starting workout from plan: \(error)")
        }

        loadWorkoutExercises()
        expandedIds = Set(workoutExercises.map { $0.id })
        startTimer()
        Haptic.success.trigger()
    }

    private func loadWorkoutExercises() {
        guard let workout = currentWorkout else {
            workoutExercises = []
            return
        }

        do {
            try workoutRepository.connect()
            workoutExercises = try workout.exercises.map { we in
                let lastSets = try workoutRepository.getLastWorkoutSets(for: we.exerciseId)
                let exercise = try exerciseRepository.getExercise(by: we.exerciseId)
                return WorkoutExerciseDisplay(
                    from: we,
                    lastSets: lastSets.map { ExerciseSetDisplay(from: $0) },
                    unit: exercise?.unit ?? .weight
                )
            }
        } catch {
            print("Error loading workout exercises: \(error)")
            workoutExercises = workout.exercises.map { WorkoutExerciseDisplay(from: $0, lastSets: nil) }
        }
    }

    private func startTimer() {
        guard let workoutStartTime else {
            return
        }
        workoutTimer.start(from: workoutStartTime)
    }

    private func stopTimer() {
        workoutTimer.stop()
    }

    private func autoMatchTrainingPlan(for workout: Workout) throws {
        guard let plan = try trainingPlanRepository.getActivePlan(),
              let match = trainingPlanCompletionMatcher.matchCompletedWorkout(workout, in: plan) else {
            return
        }
        try trainingPlanRepository.updateDayStatus(
            planId: plan.id,
            dayId: match.dayId,
            status: match.status,
            matchedWorkoutId: workout.id
        )
    }

    private func plannedExercises(for day: TrainingPlanDay) -> [WorkoutExercise] {
        let fallbackBodyPart = day.targetBodyParts.first ?? .chest
        let catalogItems = (try? exerciseCatalogService.loadCatalogItems()) ?? []
        var usedExerciseIds: Set<String> = []

        return day.suggestedExerciseNames.compactMap { name in
            let matchedItem = bestCatalogItem(for: name, in: catalogItems)
            let exerciseId = matchedItem?.recordExerciseId ?? "plan:\(exerciseSearchScorer.normalize(name))"
            guard !usedExerciseIds.contains(exerciseId) else { return nil }
            usedExerciseIds.insert(exerciseId)

            return WorkoutExercise(
                exerciseId: exerciseId,
                exerciseName: matchedItem?.nameZh ?? name,
                bodyPart: matchedItem?.bodyPart ?? fallbackBodyPart
            )
        }
    }

    private func bestCatalogItem(for exerciseName: String, in items: [ExerciseCatalogItem]) -> ExerciseCatalogItem? {
        let query = exerciseSearchScorer.normalize(exerciseName)
        guard !query.isEmpty else { return nil }
        if let exact = items.first(where: {
            exerciseSearchScorer.normalize($0.nameZh) == query ||
            exerciseSearchScorer.normalize($0.nameEn ?? "") == query
        }) {
            return exact
        }
        return exerciseSearchScorer.sortedCatalogItems(items, query: exerciseName).first
    }
}
