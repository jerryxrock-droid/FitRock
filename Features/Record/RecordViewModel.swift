import SwiftUI
import Combine

final class RecordViewModel: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var currentWorkout: Workout?
    @Published var workoutExercises: [WorkoutExerciseDisplay] = []
    @Published var elapsedTime: TimeInterval = 0

    private let db = DatabaseManager.shared
    private var timer: Timer?
    private var expandedIds: Set<String> = []
    private var workoutStartTime: Date?
    private var isAppPaused = false
    private var pausedElapsedTime: TimeInterval = 0

    var totalSets: Int {
        workoutExercises.flatMap { $0.sets }.count
    }

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        if isWorkoutActive {
            isAppPaused = true
            pausedElapsedTime = elapsedTime
            stopTimer()
        }
    }

    @objc private func appDidBecomeActive() {
        if isAppPaused && isWorkoutActive, let startTime = workoutStartTime {
            isAppPaused = false
            elapsedTime = Date().timeIntervalSince(startTime)
            startTimer()
        }
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
            try db.connect()
            try db.saveWorkout(workout)
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
        isAppPaused = false

        do {
            try db.connect()

            // Batch load last sets and exercises to avoid N+1 queries
            let exerciseIds = workout.exercises.map { $0.exerciseId }
            let lastSetsMap = try db.getLastWorkoutSetsBatch(for: exerciseIds)
            let exercisesMap = try db.getExercisesBatch(by: exerciseIds)

            workoutExercises = try workout.exercises.map { we in
                let lastSets = lastSetsMap[we.exerciseId] ?? []
                let exercise = exercisesMap[we.exerciseId]
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

        do {
            try db.connect()
            try db.saveWorkout(workout)
        } catch {
            print("Error finishing workout: \(error)")
        }

        currentWorkout = nil
        isWorkoutActive = false
        workoutExercises = []
        expandedIds = []
        workoutStartTime = nil

        Haptic.success.trigger()
    }

    func cancelWorkout() {
        stopTimer()

        if let workout = currentWorkout {
            try? db.deleteWorkout(workout.id)
        }

        currentWorkout = nil
        isWorkoutActive = false
        workoutExercises = []
        expandedIds = []
        workoutStartTime = nil

        Haptic.medium.trigger()
    }

    func addExercise(_ exercise: Exercise) {
        guard var workout = currentWorkout else { return }

        let workoutExercise = WorkoutExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            bodyPart: exercise.bodyPart
        )

        workout.exercises.append(workoutExercise)
        currentWorkout = workout

        do {
            try db.connect()
            try db.saveWorkout(workout)
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
            try db.connect()
            try db.saveWorkout(workout)
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
            try db.connect()
            try db.saveWorkout(workout)
        } catch {
            print("Error updating exercise name: \(error)")
        }

        loadWorkoutExercises()
    }

    func saveAsUserExercise(name: String, bodyPart: BodyPart) {
        do {
            try db.connect()
            try db.saveUserExercise(name: name, bodyPart: bodyPart)
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
            try db.connect()
            try db.saveWorkout(workout)
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
            try db.connect()
            try db.saveWorkout(workout)
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
            try db.connect()
            try db.saveWorkout(workout)
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
            try db.connect()
            try db.saveWorkout(workout)
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

    private func loadWorkoutExercises() {
        guard let workout = currentWorkout else {
            workoutExercises = []
            return
        }

        do {
            try db.connect()

            // Batch load to avoid N+1 queries
            let exerciseIds = workout.exercises.map { $0.exerciseId }
            let lastSetsMap = try db.getLastWorkoutSetsBatch(for: exerciseIds)
            let exercisesMap = try db.getExercisesBatch(by: exerciseIds)

            workoutExercises = try workout.exercises.map { we in
                let lastSets = lastSetsMap[we.exerciseId] ?? []
                let exercise = exercisesMap[we.exerciseId]
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
        // Use Date-based timing for accuracy even when app is backgrounded
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
