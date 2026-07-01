import XCTest
@testable import FitRock

final class TrainingPlanRecommendationEngineTests: XCTestCase {
    func testGeneratesFourWeekHypertrophyPlanWithoutHealthKit() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60, avoidedBodyParts: []),
            healthSnapshot: nil,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(plan.weeks.count, 4)
        XCTAssertEqual(plan.trainingDaysPerWeek, 4)
        XCTAssertEqual(plan.weeks.first?.days.count, 4)
        XCTAssertFalse(plan.weeks.flatMap(\.days).contains { $0.status == .rest })
        XCTAssertEqual(plan.goal, .hypertrophy)
        XCTAssertTrue(plan.recommendationReason.contains("健康数据未接入"))
    }

    func testPplAndFullBodyProduceDifferentStructures() {
        let engine = TrainingPlanRecommendationEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let ppl = engine.recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .ppl, preferredDaysPerWeek: 5, maxSessionMinutes: nil, avoidedBodyParts: [], splitStyle: .ppl),
            startDate: start
        )
        let fullBody = engine.recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .fullBody, preferredDaysPerWeek: 3, maxSessionMinutes: nil, avoidedBodyParts: [], splitStyle: .fullBody),
            startDate: start
        )

        XCTAssertNotEqual(ppl.weeks.first?.days.first?.title, fullBody.weeks.first?.days.first?.title)
    }

    func testHealthSnapshotIsStoredWhenProvided() {
        let snapshot = HealthMetricsSnapshot(bodyMassKg: 72, averageHeartRate: 80, restingHeartRate: 60, activeEnergyKcal30d: 12000, capturedAt: Date())

        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            healthSnapshot: snapshot
        )

        XCTAssertEqual(plan.healthSnapshot?.bodyMassKg, 72)
        XCTAssertTrue(plan.recommendationReason.contains("活动能量"))
    }

    func testConfiguredTrainingDaysPerWeekAreRespected() {
        let engine = TrainingPlanRecommendationEngine()

        for days in [2, 3, 4, 5, 6] {
            let plan = engine.recommend(
                workouts: [],
                heatmapSummary: emptyHeatmap(),
                preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: days, maxSessionMinutes: 60),
                startDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
            XCTAssertEqual(plan.weeks.first?.days.count, days)
            XCTAssertEqual(plan.weeks.first?.days.map(\.sequenceIndex), Array(1...days))
            XCTAssertTrue(plan.weeks.first?.days.allSatisfy { $0.availableFrom != nil && $0.availableUntil != nil } == true)
        }
    }

    func testSessionLengthControlsSuggestedExerciseCount() {
        let engine = TrainingPlanRecommendationEngine()
        let counts = [30: 3, 45: 4, 60: 5, 75: 6]

        for (minutes, expectedWeekOneCount) in counts {
            let plan = engine.recommend(
                workouts: [],
                heatmapSummary: emptyHeatmap(),
                preferences: TrainingPlanPreferences(goal: .fullBody, preferredDaysPerWeek: 3, maxSessionMinutes: minutes),
                startDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
            let firstTrainingDay = plan.weeks.first?.days.first { $0.status != .rest }
            XCTAssertEqual(firstTrainingDay?.suggestedExerciseNames.count, expectedWeekOneCount)
            XCTAssertEqual(plan.recommendedSessionMinutes, minutes)
        }
    }

    func testAvoidedBodyPartsAreRemovedFromPlanTargets() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60, avoidedBodyParts: [.legs]),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let targets = plan.weeks.flatMap { $0.days.flatMap(\.targetBodyParts) }
        XCTAssertFalse(targets.contains(.legs))
    }

    func testEquipmentPreferenceChangesSuggestionPriority() {
        let items = [
            catalogItem(id: "db:bench", source: .db, name: "杠铃卧推", bodyPart: .chest),
            catalogItem(id: "json:chest-press", source: .json, name: "坐姿推胸机", bodyPart: .chest, equipmentId: "chest-press")
        ]
        let engine = TrainingPlanRecommendationEngine()
        let machinePlan = engine.recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60, equipmentPreference: .machine),
            catalogItems: items,
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let freeWeightPlan = engine.recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60, equipmentPreference: .freeWeight),
            catalogItems: items,
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(machinePlan.weeks.first?.days.first?.suggestedExerciseNames.first, "坐姿推胸机")
        XCTAssertEqual(freeWeightPlan.weeks.first?.days.first?.suggestedExerciseNames.first, "杠铃卧推")
        XCTAssertEqual(machinePlan.equipmentPreference, .machine)
    }

    func testFourthWeekContainsDeloadNotes() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let notes = plan.weeks[3].days.compactMap(\.note)
        XCTAssertTrue(notes.contains { $0.contains("deload") || $0.contains("降低总量") })
    }

    func testFourWeeksRotateExercisesForSameSessionTheme() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let firstSessionLists = plan.weeks.compactMap { $0.days.first?.suggestedExerciseNames }
        XCTAssertEqual(firstSessionLists.count, 4)
        XCTAssertGreaterThan(Set(firstSessionLists.map { $0.joined(separator: "|") }).count, 1)
    }

    func testWeeksContainExplicitPeriodizationNotes() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 60),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(plan.weeks[0].days.allSatisfy { $0.note?.contains("适应周") == true })
        XCTAssertTrue(plan.weeks[1].days.allSatisfy { $0.note?.contains("容量周") == true })
        XCTAssertTrue(plan.weeks[2].days.allSatisfy { $0.note?.contains("强度周") == true })
        XCTAssertTrue(plan.weeks[3].days.allSatisfy { $0.note?.contains("Deload") == true })
    }

    func testRecentSevenDayExercisesAreDeprioritized() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let recentWorkout = Workout(
            startTime: start.addingTimeInterval(-86_400),
            endTime: start.addingTimeInterval(-84_000),
            exercises: [WorkoutExercise(exerciseId: "bench", exerciseName: "杠铃卧推", bodyPart: .chest)],
            isCompleted: true
        )

        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [recentWorkout],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 2, maxSessionMinutes: 60, equipmentPreference: .freeWeight),
            startDate: start
        )

        XCTAssertNotEqual(plan.weeks.first?.days.first?.suggestedExerciseNames.first, "杠铃卧推")
    }

    func testMissingMusclesCreateWeakPointTargetsAndReason() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [.hamstring], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 3, maxSessionMinutes: 60),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(plan.weeks.first?.days.first?.targetBodyParts.contains(.legs) == true)
        XCTAssertTrue(plan.recommendationReason.contains("腿部偏少"))
        XCTAssertTrue(plan.weeks.flatMap(\.days).contains { $0.note?.contains("弱项补强") == true })
    }

    func testSuggestedExercisesAreUniqueWithinEachSessionAndWeek() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: emptyHeatmap(),
            preferences: TrainingPlanPreferences(goal: .hypertrophy, preferredDaysPerWeek: 4, maxSessionMinutes: 75),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        for week in plan.weeks {
            var namesInWeek: Set<String> = []
            for day in week.days {
                XCTAssertEqual(day.suggestedExerciseNames.count, Set(day.suggestedExerciseNames).count)
                for name in day.suggestedExerciseNames {
                    XCTAssertTrue(namesInWeek.insert(name).inserted, "Duplicate \(name) in week \(week.weekIndex)")
                }
            }
        }
    }

    func testLockedExerciseIsPrioritizedInMatchingSession() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 2,
                maxSessionMinutes: 60,
                splitStyle: .custom,
                customSessionTemplates: [
                    TrainingPlanSessionTemplate(title: "胸部主练", bodyParts: [.chest])
                ],
                lockedExerciseNames: ["坐姿推胸机"]
            ),
            catalogItems: [
                catalogItem(id: "json:chest-press", source: .json, name: "坐姿推胸机", bodyPart: .chest, equipmentId: "chest-press")
            ],
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(plan.weeks.first?.days.first?.suggestedExerciseNames.first, "坐姿推胸机")
        XCTAssertTrue(plan.recommendationReason.contains("锁定动作"))
    }

    func testExcludedExerciseNeverAppearsInPlan() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 3,
                maxSessionMinutes: 60,
                splitStyle: .custom,
                customSessionTemplates: [
                    TrainingPlanSessionTemplate(title: "胸部", bodyParts: [.chest]),
                    TrainingPlanSessionTemplate(title: "腿部", bodyParts: [.legs])
                ],
                excludedExerciseNames: ["杠铃卧推", "腿举"]
            ),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let names = plan.weeks.flatMap { $0.days.flatMap(\.suggestedExerciseNames) }
        XCTAssertFalse(names.contains("杠铃卧推"))
        XCTAssertFalse(names.contains("腿举"))
        XCTAssertTrue(plan.recommendationReason.contains("排除动作"))
    }

    func testCustomSessionTemplatesOverrideDefaultStructure() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 2,
                maxSessionMinutes: 45,
                splitStyle: .custom,
                customSessionTemplates: [
                    TrainingPlanSessionTemplate(title: "自定义胸背", bodyParts: [.chest, .back]),
                    TrainingPlanSessionTemplate(title: "自定义腿核", bodyParts: [.legs, .core])
                ]
            ),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(plan.weeks.first?.days.map(\.title), ["自定义胸背", "自定义腿核"])
        XCTAssertTrue(plan.recommendationReason.contains("自定义"))
    }

    func testWeakPointBoostCanBeDisabled() {
        let plan = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [.hamstring], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 1,
                maxSessionMinutes: 45,
                splitStyle: .custom,
                customSessionTemplates: [
                    TrainingPlanSessionTemplate(title: "胸部", bodyParts: [.chest])
                ],
                enableWeakPointBoost: false
            ),
            startDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(plan.weeks.first?.days.first?.targetBodyParts, [.chest])
        XCTAssertFalse(plan.recommendationReason.contains("腿部偏少"))
        XCTAssertTrue(plan.recommendationReason.contains("弱项补强已关闭"))
    }

    func testHighVariationRepeatsLessThanStableRotation() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let stable = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 1,
                maxSessionMinutes: 45,
                splitStyle: .custom,
                customSessionTemplates: [TrainingPlanSessionTemplate(title: "胸部", bodyParts: [.chest])],
                rotationLevel: .stable
            ),
            startDate: start
        )
        let varied = TrainingPlanRecommendationEngine().recommend(
            workouts: [],
            heatmapSummary: MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [], rawVolumes: [:]),
            preferences: TrainingPlanPreferences(
                goal: .hypertrophy,
                preferredDaysPerWeek: 1,
                maxSessionMinutes: 45,
                splitStyle: .custom,
                customSessionTemplates: [TrainingPlanSessionTemplate(title: "胸部", bodyParts: [.chest])],
                rotationLevel: .highVariation
            ),
            startDate: start
        )

        let stableUniqueCount = Set(stable.weeks.flatMap { $0.days.flatMap(\.suggestedExerciseNames) }).count
        let variedUniqueCount = Set(varied.weeks.flatMap { $0.days.flatMap(\.suggestedExerciseNames) }).count
        XCTAssertGreaterThanOrEqual(variedUniqueCount, stableUniqueCount)
    }

    private func emptyHeatmap() -> MuscleHeatmapSummary {
        MuscleHeatmapSummary(intensities: [], overloaded: [], missing: [.quadriceps], rawVolumes: [:])
    }

    private func catalogItem(
        id: String,
        source: ExerciseCatalogSource,
        name: String,
        bodyPart: BodyPart,
        equipmentId: String? = nil
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogId: id,
            source: source,
            dbExerciseId: source == .json ? nil : String(id.split(separator: ":").last ?? ""),
            jsonExerciseId: source == .json ? String(id.split(separator: ":").last ?? "") : nil,
            nameZh: name,
            nameEn: nil,
            bodyPart: bodyPart,
            unit: .weight,
            equipmentId: equipmentId,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: [],
            secondaryMuscles: [],
            isUserCreated: source == .user,
            images: []
        )
    }
}
