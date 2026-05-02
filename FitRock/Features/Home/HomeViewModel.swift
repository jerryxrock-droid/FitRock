import SwiftUI

final class HomeViewModel: ObservableObject {
    @Published var monthWorkoutCount = 0
    @Published var streakDays = 0
    @Published var monthVolume: Double = 0
    @Published var selectedDateWorkouts: [Workout] = []
    @Published var datesWithWorkouts: Set<Date> = []

    private let db = DatabaseManager.shared

    func loadData(for date: Date) {
        loadMonthStats(for: date)
        loadDatesWithWorkouts(for: date)
    }

    func selectDate(_ date: Date) {
        do {
            try db.connect()
            selectedDateWorkouts = try db.getWorkouts(for: date)
        } catch {
            print("Error loading workouts for date: \(error)")
            selectedDateWorkouts = []
        }
    }

    func hasWorkout(on date: Date) -> Bool {
        let calendar = Calendar.current
        return datesWithWorkouts.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func workoutBodyParts(on date: Date) -> [BodyPart] {
        guard let workout = selectedDateWorkouts.first(where: {
            Calendar.current.isDate($0.startTime, inSameDayAs: date)
        }) else { return [] }

        return workout.exercises.map { $0.bodyPart }
    }

    func workoutBodyPart(on date: Date) -> BodyPart? {
        return workoutBodyParts(on: date).first
    }

    private func loadMonthStats(for date: Date) {
        do {
            try db.connect()
            let workouts = try db.getAllCompletedWorkouts()

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
            try db.connect()
            let workouts = try db.getAllCompletedWorkouts()

            let calendar = Calendar.current
            datesWithWorkouts = Set(workouts.compactMap { workout in
                guard calendar.isDate(workout.startTime, equalTo: date, toGranularity: .month) else {
                    return nil
                }
                return calendar.startOfDay(for: workout.startTime)
            })
        } catch {
            print("Error loading dates with workouts: \(error)")
            datesWithWorkouts = []
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
