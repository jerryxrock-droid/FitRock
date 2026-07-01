import Foundation

struct ExerciseCatalogSearchFilter {
    private let scorer = ExerciseSearchScorer()

    func filter(
        _ items: [ExerciseCatalogItem],
        searchText: String,
        selectedBodyPart: BodyPart?,
        selectedMuscle: Muscle?,
        requireBodyPart: Bool = true
    ) -> [ExerciseCatalogItem] {
        var result = items

        if requireBodyPart {
            result = result.filter { $0.bodyPart != nil }
        }

        if let selectedBodyPart {
            result = result.filter { $0.bodyPart == selectedBodyPart }
        }

        if let selectedMuscle {
            result = result.filter {
                $0.primaryMuscles.contains(selectedMuscle) || $0.secondaryMuscles.contains(selectedMuscle)
            }
            result.sort { lhs, rhs in
                let lhsPrimary = lhs.primaryMuscles.contains(selectedMuscle)
                let rhsPrimary = rhs.primaryMuscles.contains(selectedMuscle)
                if lhsPrimary != rhsPrimary {
                    return lhsPrimary && !rhsPrimary
                }
                return lhs.nameZh.localizedCompare(rhs.nameZh) == .orderedAscending
            }
        } else {
            result.sort { $0.nameZh.localizedCompare($1.nameZh) == .orderedAscending }
        }

        guard !scorer.normalize(searchText).isEmpty else { return result }
        return scorer.sortedCatalogItems(result, query: searchText)
    }
}
