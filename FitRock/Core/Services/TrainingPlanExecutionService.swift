import Foundation

struct WeeklyTrainingPlan {
    let plan: TrainingPlan
    let week: TrainingPlanWeek
    let sessions: [TrainingPlanDay]
    let recommendedSession: TrainingPlanDay?

    var completedCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    var totalCount: Int {
        sessions.filter(\.isTrainingSession).count
    }

    var remainingCount: Int {
        sessions.filter { $0.status == .planned || $0.status == .moved }.count
    }

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

struct WeeklyPlanResolver {
    func resolve(plan: TrainingPlan?, date: Date = Date(), calendar: Calendar = .current) -> WeeklyTrainingPlan? {
        guard let plan else { return nil }
        let week = currentWeek(in: plan, date: date, calendar: calendar)
        let sessions = week?.days.filter(\.isTrainingSession).sorted(by: sessionSort) ?? []
        let recommended = sessions.first { $0.status == .planned || $0.status == .moved }
        guard let week else { return nil }
        return WeeklyTrainingPlan(plan: plan, week: week, sessions: sessions, recommendedSession: recommended)
    }

    private func currentWeek(in plan: TrainingPlan, date: Date, calendar: Calendar) -> TrainingPlanWeek? {
        if let week = plan.weeks.first(where: { weekContains($0, date: date, calendar: calendar) }) {
            return week
        }

        let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: plan.startDate), to: calendar.startOfDay(for: date)).day ?? 0
        let weekIndex = min(max(dayOffset / 7, 0), max(plan.weeks.count - 1, 0)) + 1
        return plan.weeks.first { $0.weekIndex == weekIndex }
    }

    private func weekContains(_ week: TrainingPlanWeek, date: Date, calendar: Calendar) -> Bool {
        week.days.contains { day in
            let start = calendar.startOfDay(for: day.availableFrom ?? day.date)
            let end = calendar.startOfDay(for: day.availableUntil ?? day.date)
            let current = calendar.startOfDay(for: date)
            return current >= start && current <= end
        }
    }

    private func sessionSort(_ lhs: TrainingPlanDay, _ rhs: TrainingPlanDay) -> Bool {
        let lhsIndex = lhs.sequenceIndex ?? Int.max
        let rhsIndex = rhs.sequenceIndex ?? Int.max
        if lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        return lhs.date < rhs.date
    }
}

final class TrainingPlanGenerationService {
    private let workoutRepository: WorkoutRepository
    private let heatmapCalculator: MuscleHeatmapCalculator
    private let planRepository: TrainingPlanRepository
    private let planEngine: TrainingPlanRecommendationEngine
    private let healthProvider: HealthMetricsProviding
    private let exerciseCatalogService: ExerciseCatalogProviding

    init(
        workoutRepository: WorkoutRepository = DatabaseManager.shared,
        heatmapCalculator: MuscleHeatmapCalculator = MuscleHeatmapCalculator(),
        planRepository: TrainingPlanRepository = UserDefaultsTrainingPlanRepository.shared,
        planEngine: TrainingPlanRecommendationEngine = TrainingPlanRecommendationEngine(),
        healthProvider: HealthMetricsProviding = HealthKitService.shared,
        exerciseCatalogService: ExerciseCatalogProviding = ExerciseCatalogService()
    ) {
        self.workoutRepository = workoutRepository
        self.heatmapCalculator = heatmapCalculator
        self.planRepository = planRepository
        self.planEngine = planEngine
        self.healthProvider = healthProvider
        self.exerciseCatalogService = exerciseCatalogService
    }

    func generate(preferences: TrainingPlanPreferences, completion: @escaping (Result<TrainingPlan, Error>) -> Void) {
        do {
            try workoutRepository.connect()
            let workouts = try workoutRepository.getAllCompletedWorkouts()
            let heatmapSummary = heatmapCalculator.calculate(workouts: workouts, period: .month)
            let catalogItems = (try? exerciseCatalogService.loadCatalogItems()) ?? []

            healthProvider.fetchSnapshot { [planEngine, planRepository] snapshot in
                let plan = planEngine.recommend(
                    workouts: workouts,
                    heatmapSummary: heatmapSummary,
                    preferences: preferences,
                    healthSnapshot: snapshot,
                    catalogItems: catalogItems
                )
                do {
                    try planRepository.savePlan(plan)
                    completion(.success(plan))
                } catch {
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
