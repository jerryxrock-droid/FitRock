import SwiftUI
import Combine

final class StatsViewModel: ObservableObject {
    @Published var workoutCount = 0
    @Published var totalVolume: Double = 0
    @Published var totalSets = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var bodyPartData: [BodyPartStat] = []
    @Published var exerciseRanking: [ExerciseRankItem] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var workouts: [Workout] = []
    @Published var heatmapPeriod: HeatmapPeriod = .month
    @Published var muscleHeatmapSummary = MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:])
    @Published var activeTrainingPlan: TrainingPlan?
    @Published var planCompletion = TrainingPlanCompletion(completed: 0, skipped: 0, planned: 0, rest: 0)
    @Published var healthSnapshot = HealthMetricsSnapshot.empty

    private let workoutRepository: WorkoutRepository
    private let personalRecordRepository: PersonalRecordRepository
    private let prService: PRService
    private let statsCalculator: StatsCalculator
    private let heatmapCalculator: MuscleHeatmapCalculator
    private let planRepository: TrainingPlanRepository
    private let planEngine: TrainingPlanRecommendationEngine
    private let completionMatcher: TrainingPlanCompletionMatcher
    private let healthProvider: HealthMetricsProviding
    private let exerciseCatalogService: ExerciseCatalogProviding
    private var allCompletedWorkouts: [Workout] = []
    private var catalogItems: [ExerciseCatalogItem] = []

    init(
        workoutRepository: WorkoutRepository = DatabaseManager.shared,
        personalRecordRepository: PersonalRecordRepository = DatabaseManager.shared,
        prService: PRService = .shared,
        statsCalculator: StatsCalculator = StatsCalculator(),
        heatmapCalculator: MuscleHeatmapCalculator = MuscleHeatmapCalculator(),
        planRepository: TrainingPlanRepository = UserDefaultsTrainingPlanRepository.shared,
        planEngine: TrainingPlanRecommendationEngine = TrainingPlanRecommendationEngine(),
        completionMatcher: TrainingPlanCompletionMatcher = TrainingPlanCompletionMatcher(),
        healthProvider: HealthMetricsProviding = HealthKitService.shared,
        exerciseCatalogService: ExerciseCatalogProviding? = nil
    ) {
        self.workoutRepository = workoutRepository
        self.personalRecordRepository = personalRecordRepository
        self.prService = prService
        self.statsCalculator = statsCalculator
        self.heatmapCalculator = heatmapCalculator
        self.planRepository = planRepository
        self.planEngine = planEngine
        self.completionMatcher = completionMatcher
        self.healthProvider = healthProvider
        self.exerciseCatalogService = exerciseCatalogService ?? ExerciseCatalogService()
    }

    var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }

    func loadStats(for period: StatsPeriod) {
        do {
            try workoutRepository.connect()
            let allWorkouts = try workoutRepository.getAllCompletedWorkouts()
            allCompletedWorkouts = allWorkouts
            apply(statsCalculator.calculate(from: allWorkouts, period: period))
            loadCatalogItems()
            refreshHeatmap()
            loadActivePlan()
            loadPersonalRecords()
        } catch {
            print("Error loading stats: \(error)")
            resetStats()
        }
    }

    func setHeatmapPeriod(_ period: HeatmapPeriod) {
        heatmapPeriod = period
        refreshHeatmap()
    }

    func generatePlan(goal: TrainingPlanGoal = .hypertrophy) {
        generatePlan(preferences: TrainingPlanPreferences(goal: goal))
    }

    func generatePlan(preferences: TrainingPlanPreferences) {
        healthProvider.fetchSnapshot { [weak self] snapshot in
            guard let self else { return }
            self.healthSnapshot = snapshot
            let plan = self.planEngine.recommend(
                workouts: self.allCompletedWorkouts,
                heatmapSummary: self.muscleHeatmapSummary,
                preferences: preferences,
                healthSnapshot: snapshot,
                catalogItems: self.catalogItems
            )
            do {
                try self.planRepository.savePlan(plan)
                self.activeTrainingPlan = plan
                self.planCompletion = self.completionMatcher.completion(plan: plan)
            } catch {
                print("Error saving training plan: \(error)")
            }
        }
    }

    func updatePlanDay(_ day: TrainingPlanDay, status: TrainingPlanDayStatus) {
        guard let plan = activeTrainingPlan else { return }
        do {
            try planRepository.updateDayStatus(planId: plan.id, dayId: day.id, status: status, matchedWorkoutId: day.matchedWorkoutId)
            loadActivePlan()
        } catch {
            print("Error updating plan day: \(error)")
        }
    }

    private func apply(_ summary: StatsSummary) {
        workoutCount = summary.workoutCount
        totalVolume = summary.totalVolume
        totalSets = summary.totalSets
        totalDuration = summary.totalDuration
        bodyPartData = summary.bodyPartData
        exerciseRanking = summary.exerciseRanking
        workouts = summary.recentWorkouts
    }

    private func loadPersonalRecords() {
        do {
            var records = try personalRecordRepository.getPersonalRecords()
            if records.isEmpty {
                try prService.rebuildAllPersonalRecords()
                records = try personalRecordRepository.getPersonalRecords()
            }
            personalRecords = records
        } catch {
            print("Error loading personal records: \(error)")
            personalRecords = []
        }
    }

    private func refreshHeatmap() {
        muscleHeatmapSummary = heatmapCalculator.calculate(workouts: allCompletedWorkouts, period: heatmapPeriod)
    }

    private func loadActivePlan() {
        do {
            activeTrainingPlan = try planRepository.getActivePlan()
            if let activeTrainingPlan {
                planCompletion = completionMatcher.completion(plan: activeTrainingPlan)
            } else {
                planCompletion = TrainingPlanCompletion(completed: 0, skipped: 0, planned: 0, rest: 0)
            }
        } catch {
            print("Error loading training plan: \(error)")
        }
    }

    private func loadCatalogItems() {
        do {
            catalogItems = try exerciseCatalogService.loadCatalogItems()
        } catch {
            print("Error loading exercise catalog: \(error)")
            catalogItems = []
        }
    }

    private func resetStats() {
        workoutCount = 0
        totalVolume = 0
        totalSets = 0
        totalDuration = 0
        bodyPartData = []
        exerciseRanking = []
        personalRecords = []
        workouts = []
    }
}
