import Foundation

struct ExerciseSearchScorer {
    func sortedCatalogItems(_ items: [ExerciseCatalogItem], query: String) -> [ExerciseCatalogItem] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return items.sorted(by: defaultCatalogSort)
        }

        return items
            .compactMap { item -> (item: ExerciseCatalogItem, score: Int)? in
                guard let score = score(item, query: normalizedQuery), score > 0 else { return nil }
                return (item, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsPriority = sourcePriority(lhs.item.source)
                let rhsPriority = sourcePriority(rhs.item.source)
                if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
                return lhs.item.nameZh.localizedCompare(rhs.item.nameZh) == .orderedAscending
            }
            .map(\.item)
    }

    func sortedEquipments(_ equipments: [Equipment], query: String) -> [Equipment] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return equipments.sorted { $0.nameZh.localizedCompare($1.nameZh) == .orderedAscending }
        }

        return equipments
            .compactMap { equipment -> (equipment: Equipment, score: Int)? in
                guard let score = score(equipment, query: normalizedQuery), score > 0 else { return nil }
                return (equipment, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.equipment.nameZh.localizedCompare(rhs.equipment.nameZh) == .orderedAscending
            }
            .map(\.equipment)
    }

    func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private func score(_ item: ExerciseCatalogItem, query: String) -> Int? {
        let queries = expandedQueries(for: query)
        var best = 0

        for candidate in queries {
            best = max(best, scoreName(item.nameZh, query: candidate))
            best = max(best, scoreName(item.nameEn, query: candidate))
            best = max(best, scoreField(item.equipmentNameZh, query: candidate, base: 520))
            best = max(best, scoreField(item.equipmentNameEn, query: candidate, base: 520))
            best = max(best, scoreField(item.equipmentId, query: candidate, base: 500))
            best = max(best, scoreMuscles(item.primaryMuscles, query: candidate, base: 430))
            best = max(best, scoreMuscles(item.secondaryMuscles, query: candidate, base: 360))
            best = max(best, scoreField(item.bodyPart?.displayName, query: candidate, base: 250))
        }

        return best > 0 ? best : nil
    }

    private func score(_ equipment: Equipment, query: String) -> Int? {
        let queries = expandedQueries(for: query)
        var best = 0

        for candidate in queries {
            best = max(best, scoreName(equipment.nameZh, query: candidate))
            best = max(best, scoreName(equipment.nameEn, query: candidate))
            best = max(best, scoreField(equipment.id, query: candidate, base: 520))
            best = max(best, scoreField(equipment.category, query: candidate, base: 420))
            best = max(best, scoreStrings(equipment.targetMusclesZh, query: candidate, base: 390))
            best = max(best, scoreStrings(equipment.secondaryMusclesZh, query: candidate, base: 330))
            best = max(best, scoreField(equipment.descriptionZh, query: candidate, base: 260))
            best = max(best, scoreStrings(equipment.safetyTipsZh, query: candidate, base: 220))
        }

        return best > 0 ? best : nil
    }

    private func scoreName(_ text: String?, query: String) -> Int {
        guard let normalized = normalizedOptional(text) else { return 0 }
        if normalized == query { return 1000 }
        if normalized.hasPrefix(query) { return 850 }
        if normalized.contains(query) { return 700 }
        return tokenMatchScore(normalized, query: query, base: 620)
    }

    private func scoreField(_ text: String?, query: String, base: Int) -> Int {
        guard let normalized = normalizedOptional(text) else { return 0 }
        if normalized == query { return base + 80 }
        if normalized.hasPrefix(query) { return base + 40 }
        if normalized.contains(query) { return base }
        return tokenMatchScore(normalized, query: query, base: max(base - 60, 1))
    }

    private func scoreStrings(_ texts: [String], query: String, base: Int) -> Int {
        texts.reduce(0) { max($0, scoreField($1, query: query, base: base)) }
    }

    private func scoreMuscles(_ muscles: [Muscle], query: String, base: Int) -> Int {
        muscles.reduce(0) { partial, muscle in
            max(partial, scoreField(muscle.displayName, query: query, base: base))
        }
    }

    private func tokenMatchScore(_ normalizedText: String, query: String, base: Int) -> Int {
        let tokens = query.split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return 0 }
        return tokens.allSatisfy { normalizedText.contains($0) } ? base : 0
    }

    private func normalizedOptional(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = normalize(text)
        return normalized.isEmpty ? nil : normalized
    }

    private func expandedQueries(for query: String) -> [String] {
        var result = [query]
        for group in aliasGroups where group.contains(query) {
            result.append(contentsOf: group)
        }
        return Array(Set(result))
    }

    private func defaultCatalogSort(_ lhs: ExerciseCatalogItem, _ rhs: ExerciseCatalogItem) -> Bool {
        let lhsPriority = sourcePriority(lhs.source)
        let rhsPriority = sourcePriority(rhs.source)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        return lhs.nameZh.localizedCompare(rhs.nameZh) == .orderedAscending
    }

    private func sourcePriority(_ source: ExerciseCatalogSource) -> Int {
        switch source {
        case .db, .user:
            return 0
        case .json:
            return 1
        }
    }

    private var aliasGroups: [[String]] {
        [
            ["卧推", "bench", "bench press"],
            ["深蹲", "squat"],
            ["硬拉", "deadlift"],
            ["划船", "row"],
            ["肩推", "press"],
            ["二头", "肱二头肌", "biceps"],
            ["三头", "肱三头肌", "triceps"],
            ["背", "背部", "back"],
            ["胸", "胸部", "chest"],
            ["腿", "腿部", "legs"]
        ].map { $0.map(normalize) }
    }
}
