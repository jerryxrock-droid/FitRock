import Foundation

enum SamplePreviewData {
    static var workout: Workout {
        var workout = Workout(startTime: referenceDate.addingTimeInterval(-2_700))
        workout.endTime = referenceDate
        workout.isCompleted = true
        workout.exercises = [
            WorkoutExercise(
                exerciseId: "sample-bench-press",
                exerciseName: "杠铃卧推",
                bodyPart: .chest,
                sets: [
                    ExerciseSet(setNumber: 1, weight: 60, reps: 10, isCompleted: true),
                    ExerciseSet(setNumber: 2, weight: 70, reps: 8, isCompleted: true),
                    ExerciseSet(setNumber: 3, weight: 75, reps: 6, isCompleted: true)
                ]
            ),
            WorkoutExercise(
                exerciseId: "sample-row",
                exerciseName: "坐姿划船",
                bodyPart: .back,
                sets: [
                    ExerciseSet(setNumber: 1, weight: 45, reps: 12, isCompleted: true),
                    ExerciseSet(setNumber: 2, weight: 50, reps: 10, isCompleted: true)
                ]
            )
        ]
        return workout
    }

    static var muscleHeatmapSummary: MuscleHeatmapSummary {
        MuscleHeatmapSummary(
            intensities: [
                MuscleIntensity(muscle: .chest, intensity: 0.9),
                MuscleIntensity(muscle: .upperChest, intensity: 0.72),
                MuscleIntensity(muscle: .triceps, intensity: 0.55),
                MuscleIntensity(muscle: .upperBack, intensity: 0.5),
                MuscleIntensity(muscle: .quadriceps, intensity: 0.18)
            ],
            overloaded: [.chest, .upperChest],
            missing: [.hamstring, .calves, .lowerBack],
            rawVolumes: [
                .chest: 1_950,
                .upperChest: 1_560,
                .triceps: 1_120,
                .upperBack: 1_050,
                .quadriceps: 380
            ]
        )
    }

    static var trainingPlan: TrainingPlan {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: referenceDate)
        let weeks = (0..<4).map { weekIndex in
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: start) ?? start
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let note: String
            switch weekIndex {
            case 0:
                note = "适应周：基础复合动作优先，建立节奏。"
            case 1:
                note = "容量周：增加辅助动作，补足训练量。"
            case 2:
                note = "强度周：自由重量优先，冲击高质量训练。"
            default:
                note = "Deload 周：降低总量，使用更稳定的器械动作。"
            }
            let weeklyExercises = [
                [["杠铃卧推", "哑铃侧平举", "绳索下压"], ["高位下拉", "坐姿划船", "杠铃弯举"], ["深蹲", "腿弯举", "平板支撑"]],
                [["哑铃卧推", "绳索夹胸", "绳索下压"], ["杠铃划船", "直臂下压", "哑铃弯举"], ["腿举", "腿伸展", "站姿提踵"]],
                [["上斜卧推", "杠铃推举", "双杠臂屈伸"], ["单臂哑铃划船", "高位下拉", "面拉"], ["深蹲", "罗马尼亚硬拉", "臀桥"]],
                [["坐姿推胸机", "哑铃飞鸟", "绳索下压"], ["坐姿划船", "直臂下压", "反向飞鸟"], ["腿举", "腿弯举", "卷腹"]]
            ][weekIndex]

            return TrainingPlanWeek(
                weekIndex: weekIndex + 1,
                days: [
                    TrainingPlanDay(date: weekStart, sequenceIndex: 1, availableFrom: weekStart, availableUntil: weekEnd, title: "Push", targetBodyParts: [.chest, .shoulders, .arms], suggestedExerciseNames: weeklyExercises[0], note: note),
                    TrainingPlanDay(date: weekStart, sequenceIndex: 2, availableFrom: weekStart, availableUntil: weekEnd, title: "Pull", targetBodyParts: [.back, .arms], suggestedExerciseNames: weeklyExercises[1], note: note),
                    TrainingPlanDay(date: weekStart, sequenceIndex: 3, availableFrom: weekStart, availableUntil: weekEnd, title: "Legs 弱项补强", targetBodyParts: [.legs, .core], suggestedExerciseNames: weeklyExercises[2], note: "\(note) 弱项补强：增加腿后侧出现频率。")
                ]
            )
        }
        return TrainingPlan(
            name: "示例 4 周增肌计划",
            goal: .hypertrophy,
            trainingDaysPerWeek: 3,
            recommendationReason: "示例预览：按周训练池生成，动作会随适应、容量、强度和 deload 周轮换，不会写入真实计划。",
            startDate: start,
            endDate: calendar.date(byAdding: .day, value: 27, to: start) ?? start,
            weeks: weeks,
            healthSnapshot: .empty
        )
    }

    static var exerciseHistory: ExerciseHistorySummary {
        ExerciseHistorySummary(
            exerciseName: "杠铃卧推",
            workoutCount: 6,
            totalSets: 18,
            totalVolume: 14_500,
            recentWorkouts: [workout],
            personalRecords: [],
            relatedMuscles: [.chest, .upperChest, .triceps, .frontDeltoid]
        )
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_735_689_600)
}
