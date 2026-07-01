import SwiftUI

final class HomeViewModel: ObservableObject {
    @Published var monthWorkoutCount = 0
    @Published var streakDays = 0
    @Published var monthVolume: Double = 0
    @Published var selectedDateWorkouts: [Workout] = []
    @Published var recentWorkouts: [Workout] = []
    @Published var datesWithWorkouts: Set<Date> = []
    @Published var dateBodyParts: [Date: [BodyPart]] = [:]

    private let workoutRepository: WorkoutRepository
    private let prService: PRService
    private var selectedDate: Date?

    init(
        workoutRepository: WorkoutRepository = DatabaseManager.shared,
        prService: PRService = .shared
    ) {
        self.workoutRepository = workoutRepository
        self.prService = prService
    }

    func loadData(for date: Date) {
        loadMonthStats(for: date)
        loadDatesWithWorkouts(for: date)
        loadRecentWorkouts()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        do {
            try workoutRepository.connect()
            selectedDateWorkouts = try workoutRepository.getWorkouts(for: date)
        } catch {
            print("Error loading workouts for date: \(error)")
            selectedDateWorkouts = []
        }
    }

    func clearSelectedDate() {
        selectedDate = nil
        selectedDateWorkouts = []
    }

    func deleteWorkout(_ workoutId: String, displayedMonth: Date) {
        do {
            try workoutRepository.connect()
            try workoutRepository.deleteWorkout(workoutId)
            try prService.rebuildAllPersonalRecords()
            loadData(for: displayedMonth)
            if let selectedDate {
                selectDate(selectedDate)
            }
            Haptic.medium.trigger()
        } catch {
            print("Error deleting workout: \(error)")
        }
    }

    func hasWorkout(on date: Date) -> Bool {
        let calendar = Calendar.current
        return datesWithWorkouts.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func workoutBodyParts(on date: Date) -> [BodyPart] {
        let calendar = Calendar.current
        return dateBodyParts.first(where: { calendar.isDate($0.key, inSameDayAs: date) })?.value ?? []
    }

    func workoutBodyPart(on date: Date) -> BodyPart? {
        return workoutBodyParts(on: date).first
    }

    private func loadMonthStats(for date: Date) {
        do {
            try workoutRepository.connect()
            let workouts = try workoutRepository.getAllCompletedWorkouts()

            let calendar = Calendar.current
            let monthWorkouts = workouts.filter { calendar.isDate($0.startTime, equalTo: date, toGranularity: .month) }

            monthWorkoutCount = monthWorkouts.count
            monthVolume = monthWorkouts.reduce(0) { $0 + $1.totalVolume }

            streakDays = calculateStreak(from: workouts)
        } catch {
            print("Error loading month stats: \(error)")
            monthWorkoutCount = 0
            streakDays = 0
            monthVolume = 0
        }
    }

    private func loadDatesWithWorkouts(for date: Date) {
        do {
            try workoutRepository.connect()
            let workouts = try workoutRepository.getAllCompletedWorkouts()

            let calendar = Calendar.current
            var bodyParts: [Date: [BodyPart]] = [:]
            let monthWorkouts = workouts.filter { calendar.isDate($0.startTime, equalTo: date, toGranularity: .month) }

            datesWithWorkouts = Set(monthWorkouts.compactMap { workout in
                let day = calendar.startOfDay(for: workout.startTime)
                bodyParts[day, default: []] += workout.exercises.map { $0.bodyPart }
                return day
            })

            dateBodyParts = bodyParts
        } catch {
            print("Error loading dates with workouts: \(error)")
            datesWithWorkouts = []
            dateBodyParts = [:]
        }
    }

    private func loadRecentWorkouts() {
        do {
            try workoutRepository.connect()
            recentWorkouts = Array(try workoutRepository.getAllCompletedWorkouts().prefix(3))
        } catch {
            print("Error loading recent workouts: \(error)")
            recentWorkouts = []
        }
    }

    private func calculateStreak(from workouts: [Workout]) -> Int {
        let calendar = Calendar.current
        let sortedDates = workouts
            .map { calendar.startOfDay(for: $0.startTime) }
            .sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                break
            }
        }

        return streak
    }
}
