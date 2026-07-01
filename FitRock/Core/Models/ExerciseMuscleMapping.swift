import Foundation

struct ExerciseMuscleMapping {
    let exerciseId: String?
    let exerciseName: String?
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]

    init(exerciseId: String? = nil, exerciseName: String? = nil, primaryMuscles: [Muscle], secondaryMuscles: [Muscle] = []) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
    }
}

enum ExerciseMuscleMappingProvider {
    static func mapping(for workoutExercise: WorkoutExercise, exercise: Exercise? = nil) -> ExerciseMuscleMapping {
        if workoutExercise.exerciseId.hasPrefix("json:") {
            let jsonId = String(workoutExercise.exerciseId.dropFirst("json:".count))
            if let exerciseInfo = LocalExerciseDataService.shared.exercise(by: jsonId) {
                return mapping(for: exerciseInfo)
            }
        }
        LocalExerciseDataService.shared.loadIfNeeded()
        if let exerciseInfo = LocalExerciseDataService.shared.exercises.first(where: {
            $0.nameZh == workoutExercise.exerciseName || $0.nameEn == workoutExercise.exerciseName
        }) {
            return mapping(for: exerciseInfo)
        }
        if let byId = dbMappings.first(where: { $0.exerciseId == workoutExercise.exerciseId }) {
            return byId
        }
        if let byName = dbMappings.first(where: { $0.exerciseName == workoutExercise.exerciseName }) {
            return byName
        }
        return mapping(for: exercise?.bodyPart ?? workoutExercise.bodyPart)
    }

    static func mapping(for exerciseInfo: ExerciseInfo) -> ExerciseMuscleMapping {
        let primary = exerciseInfo.primaryMuscles.flatMap { muscles(from: $0) }
        let secondary = exerciseInfo.secondaryMuscles.flatMap { muscles(from: $0) }
        return ExerciseMuscleMapping(
            exerciseId: exerciseInfo.id,
            exerciseName: exerciseInfo.nameZh,
            primaryMuscles: primary.isEmpty ? muscles(from: exerciseInfo.primaryMusclesZh.joined(separator: " ")) : unique(primary),
            secondaryMuscles: unique(secondary)
        )
    }

    static func mapping(for bodyPart: BodyPart) -> ExerciseMuscleMapping {
        switch bodyPart {
        case .chest:
            return ExerciseMuscleMapping(primaryMuscles: [.chest, .upperChest, .lowerChest], secondaryMuscles: [.triceps, .frontDeltoid])
        case .back:
            return ExerciseMuscleMapping(primaryMuscles: [.upperBack, .lowerBack, .rhomboids, .trapezius], secondaryMuscles: [.biceps, .forearm])
        case .shoulders:
            return ExerciseMuscleMapping(primaryMuscles: [.deltoids, .frontDeltoid, .rearDeltoid], secondaryMuscles: [.triceps, .trapezius])
        case .arms:
            return ExerciseMuscleMapping(primaryMuscles: [.biceps, .triceps, .forearm])
        case .legs:
            return ExerciseMuscleMapping(primaryMuscles: [.quadriceps, .hamstring, .gluteal, .calves], secondaryMuscles: [.adductors, .tibialis])
        case .core:
            return ExerciseMuscleMapping(primaryMuscles: [.abs, .upperAbs, .lowerAbs, .obliques], secondaryMuscles: [.lowerBack, .serratus])
        case .cardio:
            return ExerciseMuscleMapping(primaryMuscles: [.quadriceps, .hamstring, .calves], secondaryMuscles: [.gluteal, .abs])
        }
    }

    static func muscles(from rawName: String) -> [Muscle] {
        let normalized = rawName.lowercased()
        if normalized.contains("lat") || normalized.contains("背阔") {
            return [.upperBack]
        }
        if normalized.contains("middle back") || normalized.contains("中背") {
            return [.rhomboids, .trapezius, .upperBack]
        }
        if normalized.contains("lower back") || normalized.contains("下背") {
            return [.lowerBack]
        }
        if normalized.contains("chest") || normalized.contains("胸") {
            return [.chest, .upperChest, .lowerChest]
        }
        if normalized.contains("biceps") || normalized.contains("肱二") {
            return [.biceps]
        }
        if normalized.contains("triceps") || normalized.contains("肱三") {
            return [.triceps]
        }
        if normalized.contains("forearm") || normalized.contains("前臂") {
            return [.forearm]
        }
        if normalized.contains("shoulder") || normalized.contains("deltoid") || normalized.contains("肩") || normalized.contains("三角") {
            return [.deltoids, .frontDeltoid, .rearDeltoid]
        }
        if normalized.contains("quad") || normalized.contains("股四") {
            return [.quadriceps, .innerQuad, .outerQuad]
        }
        if normalized.contains("hamstring") || normalized.contains("腘绳") {
            return [.hamstring]
        }
        if normalized.contains("glute") || normalized.contains("臀") {
            return [.gluteal]
        }
        if normalized.contains("calf") || normalized.contains("calves") || normalized.contains("小腿") {
            return [.calves]
        }
        if normalized.contains("adductor") || normalized.contains("内收") {
            return [.adductors]
        }
        if normalized.contains("ab") || normalized.contains("core") || normalized.contains("腹") || normalized.contains("核心") {
            return [.abs, .upperAbs, .lowerAbs]
        }
        if normalized.contains("oblique") || normalized.contains("腹斜") {
            return [.obliques]
        }
        return []
    }

    private static let dbMappings: [ExerciseMuscleMapping] = [
        ExerciseMuscleMapping(exerciseName: "杠铃卧推", primaryMuscles: [.chest, .upperChest], secondaryMuscles: [.triceps, .frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "哑铃卧推", primaryMuscles: [.chest, .upperChest], secondaryMuscles: [.triceps, .frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "双杠臂屈伸", primaryMuscles: [.lowerChest, .triceps], secondaryMuscles: [.frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "哑铃飞鸟", primaryMuscles: [.chest], secondaryMuscles: [.frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "高位下拉", primaryMuscles: [.upperBack], secondaryMuscles: [.biceps, .forearm]),
        ExerciseMuscleMapping(exerciseName: "坐姿划船", primaryMuscles: [.rhomboids, .trapezius, .upperBack], secondaryMuscles: [.biceps]),
        ExerciseMuscleMapping(exerciseName: "引体向上", primaryMuscles: [.upperBack], secondaryMuscles: [.biceps, .abs]),
        ExerciseMuscleMapping(exerciseName: "直臂下压", primaryMuscles: [.upperBack], secondaryMuscles: [.triceps]),
        ExerciseMuscleMapping(exerciseName: "杠铃推举", primaryMuscles: [.deltoids, .frontDeltoid], secondaryMuscles: [.triceps, .upperTrapezius]),
        ExerciseMuscleMapping(exerciseName: "哑铃侧平举", primaryMuscles: [.deltoids], secondaryMuscles: [.upperTrapezius]),
        ExerciseMuscleMapping(exerciseName: "前平举", primaryMuscles: [.frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "俯身飞鸟", primaryMuscles: [.rearDeltoid], secondaryMuscles: [.rhomboids]),
        ExerciseMuscleMapping(exerciseName: "杠铃弯举", primaryMuscles: [.biceps], secondaryMuscles: [.forearm]),
        ExerciseMuscleMapping(exerciseName: "哑铃弯举", primaryMuscles: [.biceps], secondaryMuscles: [.forearm]),
        ExerciseMuscleMapping(exerciseName: "锤式弯举", primaryMuscles: [.biceps, .forearm]),
        ExerciseMuscleMapping(exerciseName: "窄距卧推", primaryMuscles: [.triceps], secondaryMuscles: [.chest, .frontDeltoid]),
        ExerciseMuscleMapping(exerciseName: "绳索下压", primaryMuscles: [.triceps], secondaryMuscles: [.forearm]),
        ExerciseMuscleMapping(exerciseName: "过顶伸展", primaryMuscles: [.triceps]),
        ExerciseMuscleMapping(exerciseName: "深蹲", primaryMuscles: [.quadriceps, .gluteal], secondaryMuscles: [.hamstring, .abs, .lowerBack]),
        ExerciseMuscleMapping(exerciseName: "腿举", primaryMuscles: [.quadriceps], secondaryMuscles: [.gluteal, .hamstring, .calves]),
        ExerciseMuscleMapping(exerciseName: "腿弯举", primaryMuscles: [.hamstring], secondaryMuscles: [.calves]),
        ExerciseMuscleMapping(exerciseName: "腿伸展", primaryMuscles: [.quadriceps, .innerQuad, .outerQuad]),
        ExerciseMuscleMapping(exerciseName: "罗马尼亚硬拉", primaryMuscles: [.hamstring, .gluteal], secondaryMuscles: [.lowerBack, .forearm]),
        ExerciseMuscleMapping(exerciseName: "小腿提踵", primaryMuscles: [.calves]),
        ExerciseMuscleMapping(exerciseName: "卷腹", primaryMuscles: [.abs, .upperAbs], secondaryMuscles: [.obliques]),
        ExerciseMuscleMapping(exerciseName: "平板支撑", primaryMuscles: [.abs, .lowerAbs, .obliques], secondaryMuscles: [.lowerBack, .gluteal]),
        ExerciseMuscleMapping(exerciseName: "悬垂举腿", primaryMuscles: [.lowerAbs, .hipFlexors], secondaryMuscles: [.forearm]),
        ExerciseMuscleMapping(exerciseName: "俄语转体", primaryMuscles: [.obliques], secondaryMuscles: [.abs]),
        ExerciseMuscleMapping(exerciseName: "山羊挺身", primaryMuscles: [.lowerBack, .gluteal], secondaryMuscles: [.hamstring]),
        ExerciseMuscleMapping(exerciseName: "跑步机", primaryMuscles: [.quadriceps, .hamstring, .calves], secondaryMuscles: [.gluteal, .abs])
    ]

    private static func unique(_ muscles: [Muscle]) -> [Muscle] {
        var seen: Set<Muscle> = []
        return muscles.filter { seen.insert($0).inserted }
    }
}
