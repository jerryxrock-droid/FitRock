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
            selectedDateWorkouts = try db.getWorkoutsForDay(date)
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
            let stats = try db.getMonthStats(for: date)
            monthWorkoutCount = stats.count
            monthVolume = stats.volume
            streakDays = stats.streakDays
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
            let workouts = try db.getWorkoutsForMonth(date)

            let calendar = Calendar.current
            datesWithWorkouts = Set(workouts.compactMap { workout in
                return calendar.startOfDay(for: workout.startTime)
            })
        } catch {
            print("Error loading dates with workouts: \(error)")
            datesWithWorkouts = []
        }
    }
}
