import Foundation

enum TrainingEquipmentPreference: String, Codable, CaseIterable {
    case noPreference
    case machine
    case freeWeight

    var displayName: String {
        switch self {
        case .noPreference: return "不限"
        case .machine: return "器械优先"
        case .freeWeight: return "自由重量优先"
        }
    }
}

enum TrainingPlanSplitStyle: String, Codable, CaseIterable {
    case ppl
    case fullBody
    case upperLower
    case custom

    var displayName: String {
        switch self {
        case .ppl: return "PPL"
        case .fullBody: return "全身"
        case .upperLower: return "上下肢"
        case .custom: return "自定义"
        }
    }
}

enum TrainingPlanRotationLevel: String, Codable, CaseIterable {
    case stable
    case moderate
    case highVariation

    var displayName: String {
        switch self {
        case .stable: return "稳定"
        case .moderate: return "适中"
        case .highVariation: return "高变化"
        }
    }
}

struct TrainingPlanSessionTemplate: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var bodyParts: [BodyPart]

    init(id: String = UUID().uuidString, title: String, bodyParts: [BodyPart]) {
        self.id = id
        self.title = title
        self.bodyParts = bodyParts
    }
}

struct TrainingPlanPreferences: Codable, Equatable {
    var goal: TrainingPlanGoal
    var preferredDaysPerWeek: Int?
    var maxSessionMinutes: Int?
    var equipmentPreference: TrainingEquipmentPreference
    var avoidedBodyParts: [BodyPart]
    var splitStyle: TrainingPlanSplitStyle
    var customSessionTemplates: [TrainingPlanSessionTemplate]
    var lockedExerciseNames: [String]
    var excludedExerciseNames: [String]
    var rotationLevel: TrainingPlanRotationLevel
    var enableWeakPointBoost: Bool

    init(
        goal: TrainingPlanGoal,
        preferredDaysPerWeek: Int? = nil,
        maxSessionMinutes: Int? = nil,
        equipmentPreference: TrainingEquipmentPreference = .noPreference,
        avoidedBodyParts: [BodyPart] = [],
        splitStyle: TrainingPlanSplitStyle = .ppl,
        customSessionTemplates: [TrainingPlanSessionTemplate] = [],
        lockedExerciseNames: [String] = [],
        excludedExerciseNames: [String] = [],
        rotationLevel: TrainingPlanRotationLevel = .moderate,
        enableWeakPointBoost: Bool = true
    ) {
        self.goal = goal
        self.preferredDaysPerWeek = preferredDaysPerWeek
        self.maxSessionMinutes = maxSessionMinutes
        self.equipmentPreference = equipmentPreference
        self.avoidedBodyParts = avoidedBodyParts
        self.splitStyle = splitStyle
        self.customSessionTemplates = customSessionTemplates
        self.lockedExerciseNames = lockedExerciseNames
        self.excludedExerciseNames = excludedExerciseNames
        self.rotationLevel = rotationLevel
        self.enableWeakPointBoost = enableWeakPointBoost
    }

    static let `default` = TrainingPlanPreferences(
        goal: .hypertrophy,
        preferredDaysPerWeek: nil,
        maxSessionMinutes: nil,
        equipmentPreference: .noPreference,
        avoidedBodyParts: [],
        splitStyle: .ppl,
        customSessionTemplates: [],
        lockedExerciseNames: [],
        excludedExerciseNames: [],
        rotationLevel: .moderate,
        enableWeakPointBoost: true
    )

    private enum CodingKeys: String, CodingKey {
        case goal
        case preferredDaysPerWeek
        case maxSessionMinutes
        case equipmentPreference
        case avoidedBodyParts
        case splitStyle
        case customSessionTemplates
        case lockedExerciseNames
        case excludedExerciseNames
        case rotationLevel
        case enableWeakPointBoost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decode(TrainingPlanGoal.self, forKey: .goal)
        preferredDaysPerWeek = try container.decodeIfPresent(Int.self, forKey: .preferredDaysPerWeek)
        maxSessionMinutes = try container.decodeIfPresent(Int.self, forKey: .maxSessionMinutes)
        equipmentPreference = try container.decodeIfPresent(TrainingEquipmentPreference.self, forKey: .equipmentPreference) ?? .noPreference
        avoidedBodyParts = try container.decodeIfPresent([BodyPart].self, forKey: .avoidedBodyParts) ?? []
        splitStyle = try container.decodeIfPresent(TrainingPlanSplitStyle.self, forKey: .splitStyle) ?? .ppl
        customSessionTemplates = try container.decodeIfPresent([TrainingPlanSessionTemplate].self, forKey: .customSessionTemplates) ?? []
        lockedExerciseNames = try container.decodeIfPresent([String].self, forKey: .lockedExerciseNames) ?? []
        excludedExerciseNames = try container.decodeIfPresent([String].self, forKey: .excludedExerciseNames) ?? []
        rotationLevel = try container.decodeIfPresent(TrainingPlanRotationLevel.self, forKey: .rotationLevel) ?? .moderate
        enableWeakPointBoost = try container.decodeIfPresent(Bool.self, forKey: .enableWeakPointBoost) ?? true
    }
}

struct TrainingPlanRecommendationEngine {
    func recommend(
        workouts: [Workout],
        heatmapSummary: MuscleHeatmapSummary,
        preferences: TrainingPlanPreferences = .default,
        healthSnapshot: HealthMetricsSnapshot? = nil,
        catalogItems: [ExerciseCatalogItem] = [],
        startDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingPlan {
        let completed = workouts.filter(\.isCompleted)
        let recent30 = completed.filter { $0.startTime >= (calendar.date(byAdding: .day, value: -30, to: startDate) ?? startDate) }
        let recent90 = completed.filter { $0.startTime >= (calendar.date(byAdding: .day, value: -90, to: startDate) ?? startDate) }
        let recent7 = completed.filter { $0.startTime >= (calendar.date(byAdding: .day, value: -7, to: startDate) ?? startDate) }
        let averageSessionMinutes = recent30.isEmpty ? 60 : Int(recent30.reduce(0) { $0 + $1.duration } / Double(recent30.count) / 60)
        let daysPerWeek = preferences.preferredDaysPerWeek ?? inferredDaysPerWeek(from: recent30, goal: preferences.goal)
        let pattern = weeklyPattern(
            goal: preferences.goal,
            splitStyle: preferences.splitStyle,
            daysPerWeek: daysPerWeek,
            missingMuscles: heatmapSummary.missing,
            customSessionTemplates: preferences.customSessionTemplates
        )
        let sessionMinutes = preferences.maxSessionMinutes ?? averageSessionMinutes
        let recentExerciseNames = Set(recent7.flatMap { $0.exercises.map(\.exerciseName) })
        let weakBodyParts = preferences.enableWeakPointBoost
            ? missingBodyParts(from: heatmapSummary.missing).filter { !preferences.avoidedBodyParts.contains($0) }
            : []
        let normalizedStart = calendar.startOfDay(for: startDate)
        let endDate = calendar.date(byAdding: .day, value: 27, to: normalizedStart) ?? normalizedStart
        let excludedNames = Set(preferences.excludedExerciseNames.map(normalizeName))
        let lockedNames = preferences.lockedExerciseNames.filter { !excludedNames.contains(normalizeName($0)) }

        var weeks: [TrainingPlanWeek] = []
        var usedNamesInPlan: Set<String> = []
        for week in 0..<4 {
            var days: [TrainingPlanDay] = []
            var usedNamesThisWeek: Set<String> = []
            let weekStart = calendar.date(byAdding: .day, value: week * 7, to: normalizedStart) ?? normalizedStart
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let strategy = TrainingPlanVariationEngine.strategy(for: week)

            for (sessionOffset, entry) in pattern.sorted(by: { $0.key < $1.key }).enumerated() {
                let prescription = entry.value
                let targetBodyParts = adjustedTargets(
                    prescription.bodyParts,
                    weakBodyParts: weakBodyParts,
                    avoidedBodyParts: preferences.avoidedBodyParts,
                    sessionOffset: sessionOffset
                )
                let displayDate = calendar.date(byAdding: .day, value: min(sessionOffset, 6), to: weekStart) ?? weekStart
                let suggestions = exerciseSuggestions(
                    for: targetBodyParts,
                    maxCount: exerciseCount(for: sessionMinutes, weekIndex: week),
                    equipmentPreference: preferences.equipmentPreference,
                    catalogItems: catalogItems,
                    strategy: strategy,
                    weekIndex: week,
                    recentExerciseNames: recentExerciseNames,
                    weakBodyParts: Set(weakBodyParts),
                    lockedExerciseNames: lockedNames,
                    excludedExerciseNames: excludedNames,
                    rotationLevel: preferences.rotationLevel,
                    usedNamesInPlan: usedNamesInPlan,
                    usedNamesThisWeek: &usedNamesThisWeek
                )
                usedNamesInPlan.formUnion(suggestions)
                days.append(TrainingPlanDay(
                    date: displayDate,
                    sequenceIndex: sessionOffset + 1,
                    availableFrom: weekStart,
                    availableUntil: weekEnd,
                    title: prescription.title,
                    targetBodyParts: targetBodyParts,
                    suggestedExerciseNames: suggestions,
                    status: .planned,
                    note: weekNote(for: strategy, weakBodyParts: weakBodyParts)
                ))
            }
            weeks.append(TrainingPlanWeek(weekIndex: week + 1, days: days))
        }

        let reason = recommendationReason(
            recent30Count: recent30.count,
            recent90Count: recent90.count,
            averageSessionMinutes: sessionMinutes,
            daysPerWeek: daysPerWeek,
            goal: preferences.goal,
            equipmentPreference: preferences.equipmentPreference,
            splitStyle: preferences.splitStyle,
            rotationLevel: preferences.rotationLevel,
            lockedExerciseCount: lockedNames.count,
            excludedExerciseCount: excludedNames.count,
            enableWeakPointBoost: preferences.enableWeakPointBoost,
            weakBodyParts: weakBodyParts,
            healthSnapshot: healthSnapshot
        )

        return TrainingPlan(
            name: "4周\(preferences.goal.displayName)计划",
            goal: preferences.goal,
            trainingDaysPerWeek: daysPerWeek,
            recommendationReason: reason,
            startDate: normalizedStart,
            endDate: endDate,
            weeks: weeks,
            healthSnapshot: healthSnapshot,
            recommendedSessionMinutes: sessionMinutes,
            equipmentPreference: preferences.equipmentPreference
        )
    }

    private func inferredDaysPerWeek(from recent30: [Workout], goal: TrainingPlanGoal) -> Int {
        if recent30.isEmpty {
            return goal == .ppl ? 5 : 3
        }
        let weekly = Int(round(Double(recent30.count) / 4.0))
        return min(max(weekly, goal == .ppl ? 4 : 2), 6)
    }

    private func weeklyPattern(
        goal: TrainingPlanGoal,
        splitStyle: TrainingPlanSplitStyle,
        daysPerWeek: Int,
        missingMuscles: [Muscle],
        customSessionTemplates: [TrainingPlanSessionTemplate]
    ) -> [Int: (title: String, bodyParts: [BodyPart])] {
        if splitStyle == .custom, !customSessionTemplates.isEmpty {
            let entries = customSessionTemplates.prefix(daysPerWeek).enumerated().map { index, template in
                (index, (template.title, template.bodyParts))
            }
            return Dictionary(uniqueKeysWithValues: entries)
        }

        let needsLegs = missingMuscles.contains { [.quadriceps, .hamstring, .gluteal, .calves].contains($0) }
        switch splitStyle {
        case .ppl:
            return [
                0: ("Push", [.chest, .shoulders, .arms]),
                1: ("Pull", [.back, .arms]),
                2: ("Legs", [.legs, .core]),
                4: ("Push/Pull 补强", [.chest, .back, .shoulders]),
                5: (needsLegs ? "Legs 补强" : "全身容量", needsLegs ? [.legs, .core] : [.legs, .chest, .back]),
                6: ("恢复泵感", [.arms, .core])
            ].limited(to: daysPerWeek)
        case .fullBody:
            return [
                0: ("全身 A", [.chest, .back, .legs]),
                2: ("全身 B", [.shoulders, .legs, .core]),
                4: ("全身 C", [.back, .chest, .arms]),
                5: ("弱项补强", needsLegs ? [.legs, .core] : [.shoulders, .arms, .core]),
                6: ("轻量循环", [.cardio, .core]),
                1: ("全身技术", [.legs, .back, .core])
            ].limited(to: daysPerWeek)
        case .upperLower:
            return [
                0: ("上肢 A", [.chest, .back, .shoulders]),
                1: ("下肢 A", [.legs, .core]),
                3: ("上肢 B", [.back, .chest, .arms]),
                4: ("下肢 B", [.legs, .core]),
                5: ("弱项补强", needsLegs ? [.legs, .core] : [.shoulders, .arms, .core]),
                6: ("有氧核心", [.cardio, .core])
            ].limited(to: daysPerWeek)
        case .custom:
            switch goal {
            case .fatLoss:
                return [
                    0: ("全身力量", [.chest, .back, .legs]),
                    2: ("下肢 + 核心", [.legs, .core]),
                    4: ("全身循环", [.shoulders, .back, .legs, .core]),
                    5: ("有氧恢复", [.cardio, .core]),
                    6: ("上肢代谢", [.chest, .back, .arms]),
                    1: ("低强度有氧", [.cardio])
                ].limited(to: daysPerWeek)
            case .hypertrophy:
                return [
                    0: ("上肢推", [.chest, .shoulders, .arms]),
                    1: ("下肢", [.legs, .core]),
                    3: ("上肢拉", [.back, .arms]),
                    4: ("肩臂容量", [.shoulders, .arms]),
                    5: ("弱项补强", needsLegs ? [.legs, .core] : [.chest, .back, .shoulders]),
                    6: ("核心恢复", [.core, .cardio])
                ].limited(to: daysPerWeek)
            case .ppl:
                return weeklyPattern(goal: goal, splitStyle: .ppl, daysPerWeek: daysPerWeek, missingMuscles: missingMuscles, customSessionTemplates: [])
            case .fullBody:
                return weeklyPattern(goal: goal, splitStyle: .fullBody, daysPerWeek: daysPerWeek, missingMuscles: missingMuscles, customSessionTemplates: [])
            }
        }
    }

    private func legacyGoalPattern(goal: TrainingPlanGoal, daysPerWeek: Int, missingMuscles: [Muscle]) -> [Int: (title: String, bodyParts: [BodyPart])] {
        let needsLegs = missingMuscles.contains { [.quadriceps, .hamstring, .gluteal, .calves].contains($0) }
        switch goal {
        case .fatLoss:
            return [
                0: ("全身力量", [.chest, .back, .legs]),
                2: ("下肢 + 核心", [.legs, .core]),
                4: ("全身循环", [.shoulders, .back, .legs, .core]),
                5: ("有氧恢复", [.cardio, .core]),
                6: ("上肢代谢", [.chest, .back, .arms]),
                1: ("低强度有氧", [.cardio])
            ].limited(to: daysPerWeek)
        case .hypertrophy:
            return [
                0: ("上肢推", [.chest, .shoulders, .arms]),
                1: ("下肢", [.legs, .core]),
                3: ("上肢拉", [.back, .arms]),
                4: ("肩臂容量", [.shoulders, .arms]),
                5: ("弱项补强", needsLegs ? [.legs, .core] : [.chest, .back, .shoulders]),
                6: ("核心恢复", [.core, .cardio])
            ].limited(to: daysPerWeek)
        case .ppl:
            return weeklyPattern(goal: goal, splitStyle: .ppl, daysPerWeek: daysPerWeek, missingMuscles: missingMuscles, customSessionTemplates: [])
        case .fullBody:
            return weeklyPattern(goal: goal, splitStyle: .fullBody, daysPerWeek: daysPerWeek, missingMuscles: missingMuscles, customSessionTemplates: [])
        }
    }

    private func adjustedTargets(
        _ bodyParts: [BodyPart],
        weakBodyParts: [BodyPart],
        avoidedBodyParts: [BodyPart],
        sessionOffset: Int
    ) -> [BodyPart] {
        var targets = bodyParts.filter { !avoidedBodyParts.contains($0) }
        if sessionOffset % 2 == 0, let weak = weakBodyParts.first(where: { !targets.contains($0) }) {
            if targets.count >= 3 {
                targets[targets.count - 1] = weak
            } else {
                targets.append(weak)
            }
        }
        return targets
    }

    private func exerciseSuggestions(
        for bodyParts: [BodyPart],
        maxCount: Int,
        equipmentPreference: TrainingEquipmentPreference,
        catalogItems: [ExerciseCatalogItem],
        strategy: TrainingPlanWeekStrategy,
        weekIndex: Int,
        recentExerciseNames: Set<String>,
        weakBodyParts: Set<BodyPart>,
        lockedExerciseNames: [String],
        excludedExerciseNames: Set<String>,
        rotationLevel: TrainingPlanRotationLevel,
        usedNamesInPlan: Set<String>,
        usedNamesThisWeek: inout Set<String>
    ) -> [String] {
        var candidates: [TrainingPlanExerciseCandidate] = []
        for bodyPart in bodyParts {
            candidates += catalogCandidates(for: bodyPart, catalogItems: catalogItems)
            candidates += fallbackCandidates(for: bodyPart)
        }
        candidates = candidates.filter { !excludedExerciseNames.contains(normalizeName($0.name)) }

        let ranked = candidates
            .map { candidate in
                TrainingPlanVariationEngine.score(
                    candidate,
                    strategy: strategy,
                    equipmentPreference: equipmentPreference,
                    weekIndex: weekIndex,
                    primaryBodyPart: bodyParts.first,
                    recentExerciseNames: recentExerciseNames,
                    weakBodyParts: weakBodyParts,
                    lockedExerciseNames: Set(lockedExerciseNames.map(normalizeName)),
                    rotationLevel: rotationLevel,
                    usedNamesInPlan: usedNamesInPlan,
                    usedNamesThisWeek: usedNamesThisWeek
                )
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.candidate.name < $1.candidate.name
            }

        var selected: [String] = []
        for name in lockedExerciseNames where candidates.contains(where: { normalizeName($0.name) == normalizeName(name) }) {
            guard !selected.contains(name), !usedNamesThisWeek.contains(name) else { continue }
            selected.append(name)
            usedNamesThisWeek.insert(name)
            if selected.count == maxCount { return selected }
        }
        for item in ranked {
            guard !selected.contains(item.candidate.name), !usedNamesThisWeek.contains(item.candidate.name) else { continue }
            selected.append(item.candidate.name)
            usedNamesThisWeek.insert(item.candidate.name)
            if selected.count == maxCount { break }
        }
        return selected
    }

    private func catalogCandidates(
        for bodyPart: BodyPart,
        catalogItems: [ExerciseCatalogItem]
    ) -> [TrainingPlanExerciseCandidate] {
        catalogItems.compactMap { item in
            guard item.bodyPart == bodyPart else { return nil }
            return TrainingPlanExerciseCandidate(
                name: item.nameZh,
                bodyPart: bodyPart,
                source: item.source,
                equipmentId: item.equipmentId,
                isFallback: false
            )
        }
    }

    private func fallbackCandidates(for bodyPart: BodyPart) -> [TrainingPlanExerciseCandidate] {
        fallbackNames(for: bodyPart).map { name in
            TrainingPlanExerciseCandidate(
                name: name,
                bodyPart: bodyPart,
                source: .db,
                equipmentId: nil,
                isFallback: true
            )
        }
    }

    private func fallbackNames(for bodyPart: BodyPart) -> [String] {
        switch bodyPart {
        case .chest:
            return ["杠铃卧推", "哑铃卧推", "上斜卧推", "坐姿推胸机", "哑铃飞鸟", "绳索夹胸"]
        case .back:
            return ["高位下拉", "坐姿划船", "杠铃划船", "单臂哑铃划船", "直臂下压", "反向飞鸟"]
        case .shoulders:
            return ["杠铃推举", "哑铃推举", "哑铃侧平举", "器械肩推", "面拉", "反向飞鸟"]
        case .arms:
            return ["杠铃弯举", "哑铃弯举", "绳索弯举", "绳索下压", "仰卧臂屈伸", "双杠臂屈伸"]
        case .legs:
            return ["深蹲", "罗马尼亚硬拉", "腿举", "腿弯举", "腿伸展", "站姿提踵", "臀桥"]
        case .core:
            return ["平板支撑", "卷腹", "悬垂举腿", "绳索卷腹", "俄罗斯转体", "死虫"]
        case .cardio:
            return ["跑步机", "椭圆机", "划船机", "动感单车"]
        }
    }

    private func exerciseCount(for sessionMinutes: Int, weekIndex: Int) -> Int {
        let base: Int
        switch sessionMinutes {
        case ..<45:
            base = 4
        case ..<60:
            base = 5
        case ..<75:
            base = 6
        default:
            base = 7
        }
        if weekIndex == 0 {
            return max(base - 1, 3)
        }
        if weekIndex == 3 {
            return max(base - 1, 3)
        }
        return base
    }

    private func weekNote(for strategy: TrainingPlanWeekStrategy, weakBodyParts: [BodyPart]) -> String {
        var note = strategy.note
        if let weak = weakBodyParts.first {
            note += " 弱项补强：增加\(weak.displayName)出现频率。"
        }
        return note
    }

    private func recommendationReason(
        recent30Count: Int,
        recent90Count: Int,
        averageSessionMinutes: Int,
        daysPerWeek: Int,
        goal: TrainingPlanGoal,
        equipmentPreference: TrainingEquipmentPreference,
        splitStyle: TrainingPlanSplitStyle,
        rotationLevel: TrainingPlanRotationLevel,
        lockedExerciseCount: Int,
        excludedExerciseCount: Int,
        enableWeakPointBoost: Bool,
        weakBodyParts: [BodyPart],
        healthSnapshot: HealthMetricsSnapshot?
    ) -> String {
        var parts = ["近30天完成 \(recent30Count) 次训练，按每周 \(daysPerWeek) 天生成\(goal.displayName)。"]
        parts.append("按你选择的\(splitStyle.displayName)结构、\(rotationLevel.displayName)轮换生成。")
        parts.append("单次约 \(averageSessionMinutes) 分钟，偏好：\(equipmentPreference.displayName)。")
        if lockedExerciseCount > 0 {
            parts.append("已优先安排 \(lockedExerciseCount) 个锁定动作。")
        }
        if excludedExerciseCount > 0 {
            parts.append("已避开 \(excludedExerciseCount) 个排除动作。")
        }
        parts.append("已按适应、容量、强度、deload 四周周期轮换动作。")
        if !weakBodyParts.isEmpty {
            parts.append("热力图显示\(weakBodyParts.map(\.displayName).joined(separator: "、"))偏少，已加入弱项补强。")
        } else if !enableWeakPointBoost {
            parts.append("弱项补强已关闭。")
        }
        if let energy = healthSnapshot?.activeEnergyKcal30d, energy > 0 {
            parts.append("已参考近30天活动能量 \(Int(energy)) kcal。")
        } else {
            parts.append("健康数据未接入，已基于本地训练记录推荐。")
        }
        if recent90Count > recent30Count {
            parts.append("近90天历史用于判断训练连续性。")
        }
        return parts.joined(separator: " ")
    }

    private func missingBodyParts(from muscles: [Muscle]) -> [BodyPart] {
        var seen: Set<BodyPart> = []
        return muscles.compactMap { muscle in
            guard let bodyPart = bodyPart(for: muscle), seen.insert(bodyPart).inserted else { return nil }
            return bodyPart
        }
    }

    private func bodyPart(for muscle: Muscle) -> BodyPart? {
        switch muscle {
        case .chest, .upperChest, .lowerChest:
            return .chest
        case .upperBack, .lowerBack, .trapezius, .upperTrapezius, .lowerTrapezius, .rhomboids:
            return .back
        case .deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff:
            return .shoulders
        case .biceps, .triceps, .forearm:
            return .arms
        case .quadriceps, .hamstring, .gluteal, .calves, .innerQuad, .outerQuad, .adductors, .tibialis, .hipFlexors:
            return .legs
        case .abs, .obliques, .upperAbs, .lowerAbs, .serratus:
            return .core
        default:
            return nil
        }
    }

    private func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct TrainingPlanExerciseCandidate {
    let name: String
    let bodyPart: BodyPart
    let source: ExerciseCatalogSource
    let equipmentId: String?
    let isFallback: Bool
}

private struct TrainingPlanWeekStrategy {
    let label: String
    let note: String
    let foundationalBoost: Int
    let accessoryBoost: Int
    let freeWeightBoost: Int
    let machineBoost: Int
}

private enum TrainingPlanVariationEngine {
    static func strategy(for weekIndex: Int) -> TrainingPlanWeekStrategy {
        switch weekIndex {
        case 0:
            return TrainingPlanWeekStrategy(
                label: "适应",
                note: "适应周：基础复合动作优先，保留 1-2 次余力。",
                foundationalBoost: 28,
                accessoryBoost: 0,
                freeWeightBoost: 8,
                machineBoost: 0
            )
        case 1:
            return TrainingPlanWeekStrategy(
                label: "容量",
                note: "容量周：增加辅助和孤立动作，补足目标肌群训练量。",
                foundationalBoost: 8,
                accessoryBoost: 28,
                freeWeightBoost: 0,
                machineBoost: 8
            )
        case 2:
            return TrainingPlanWeekStrategy(
                label: "强度",
                note: "强度周：复合动作和自由重量优先，冲击本周期最高质量。",
                foundationalBoost: 24,
                accessoryBoost: 0,
                freeWeightBoost: 26,
                machineBoost: 0
            )
        default:
            return TrainingPlanWeekStrategy(
                label: "Deload",
                note: "Deload 周：降低总量 10-15%，更多器械和技术动作。",
                foundationalBoost: 0,
                accessoryBoost: 18,
                freeWeightBoost: 0,
                machineBoost: 30
            )
        }
    }

    static func score(
        _ candidate: TrainingPlanExerciseCandidate,
        strategy: TrainingPlanWeekStrategy,
        equipmentPreference: TrainingEquipmentPreference,
        weekIndex: Int,
        primaryBodyPart: BodyPart?,
        recentExerciseNames: Set<String>,
        weakBodyParts: Set<BodyPart>,
        lockedExerciseNames: Set<String>,
        rotationLevel: TrainingPlanRotationLevel,
        usedNamesInPlan: Set<String>,
        usedNamesThisWeek: Set<String>
    ) -> (candidate: TrainingPlanExerciseCandidate, score: Int) {
        var score = 100
        score += sourceScore(candidate.source, isFallback: candidate.isFallback)
        score += equipmentPreferenceScore(candidate, preference: equipmentPreference)
        score += weekStrategyScore(candidate, strategy: strategy)
        score += lockedExerciseNames.contains(candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ? 1_000 : 0
        score += candidate.bodyPart == primaryBodyPart ? 70 : 0
        score += weakBodyParts.contains(candidate.bodyPart) ? 24 : 0
        score -= recentExerciseNames.contains(candidate.name) ? 90 : 0
        score -= rotationPenalty(candidate.name, rotationLevel: rotationLevel, usedNamesInPlan: usedNamesInPlan)
        score -= usedNamesThisWeek.contains(candidate.name) ? 120 : 0
        score += stableRotationScore(candidate.name, weekIndex: weekIndex)
        return (candidate, score)
    }

    private static func sourceScore(_ source: ExerciseCatalogSource, isFallback: Bool) -> Int {
        if isFallback { return 8 }
        switch source {
        case .db: return 26
        case .user: return 24
        case .json: return 16
        }
    }

    private static func equipmentPreferenceScore(_ candidate: TrainingPlanExerciseCandidate, preference: TrainingEquipmentPreference) -> Int {
        switch preference {
        case .machine:
            return isMachine(candidate.name) || candidate.equipmentId != nil || candidate.source == .json ? 52 : -30
        case .freeWeight:
            return isFreeWeight(candidate.name) ? 36 : -8
        case .noPreference:
            return 0
        }
    }

    private static func weekStrategyScore(_ candidate: TrainingPlanExerciseCandidate, strategy: TrainingPlanWeekStrategy) -> Int {
        var score = 0
        if isFoundational(candidate.name) { score += strategy.foundationalBoost }
        if isAccessory(candidate.name) { score += strategy.accessoryBoost }
        if isFreeWeight(candidate.name) { score += strategy.freeWeightBoost }
        if isMachine(candidate.name) || candidate.equipmentId != nil || candidate.source == .json { score += strategy.machineBoost }
        return score
    }

    private static func stableRotationScore(_ name: String, weekIndex: Int) -> Int {
        let scalarSum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return ((scalarSum + weekIndex * 17) % 23) - 11
    }

    private static func rotationPenalty(_ name: String, rotationLevel: TrainingPlanRotationLevel, usedNamesInPlan: Set<String>) -> Int {
        guard usedNamesInPlan.contains(name) else { return 0 }
        switch rotationLevel {
        case .stable: return 8
        case .moderate: return 70
        case .highVariation: return 180
        }
    }

    private static func isFoundational(_ name: String) -> Bool {
        ["深蹲", "硬拉", "卧推", "划船", "推举", "引体", "下拉", "腿举"].contains { name.contains($0) }
    }

    private static func isAccessory(_ name: String) -> Bool {
        ["飞鸟", "侧平举", "弯举", "下压", "腿弯举", "腿伸展", "提踵", "卷腹", "面拉", "夹胸", "转体"].contains { name.contains($0) }
    }

    private static func isFreeWeight(_ name: String) -> Bool {
        ["杠铃", "哑铃", "壶铃"].contains { name.contains($0) }
    }

    private static func isMachine(_ name: String) -> Bool {
        ["器械", "绳索", "坐姿", "高位", "腿举", "跑步机", "椭圆机", "划船机", "动感单车"].contains { name.contains($0) }
    }
}

private extension Dictionary where Key == Int, Value == (title: String, bodyParts: [BodyPart]) {
    func limited(to count: Int) -> [Int: (title: String, bodyParts: [BodyPart])] {
        Dictionary(uniqueKeysWithValues: sorted { $0.key < $1.key }.prefix(count).map { ($0.key, $0.value) })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
