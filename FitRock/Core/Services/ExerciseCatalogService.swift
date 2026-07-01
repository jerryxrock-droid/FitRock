import Foundation

protocol ExerciseCatalogProviding {
    func loadCatalogItems() throws -> [ExerciseCatalogItem]
}

struct ExerciseCatalogService: ExerciseCatalogProviding {
    let exerciseRepository: ExerciseRepository
    let localExerciseDataService: LocalExerciseDataProviding

    init(
        exerciseRepository: ExerciseRepository = DatabaseManager.shared,
        localExerciseDataService: LocalExerciseDataProviding = LocalExerciseDataService.shared
    ) {
        self.exerciseRepository = exerciseRepository
        self.localExerciseDataService = localExerciseDataService
    }

    func loadCatalogItems() throws -> [ExerciseCatalogItem] {
        try exerciseRepository.connect()
        localExerciseDataService.loadIfNeeded()

        let dbItems = try exerciseRepository.getAllExercises().map(catalogItem(for:))
        let jsonItems = localExerciseDataService.exercises.map(catalogItem(for:))
        return dbItems + jsonItems
    }

    private func catalogItem(for exercise: Exercise) -> ExerciseCatalogItem {
        let mapping = ExerciseMuscleMappingProvider.mapping(for: exercise.bodyPart)
        let source: ExerciseCatalogSource = exercise.isUserCreated ? .user : .db
        return ExerciseCatalogItem(
            catalogId: "\(source.rawValue):\(exercise.id)",
            source: source,
            dbExerciseId: exercise.id,
            jsonExerciseId: nil,
            nameZh: exercise.name,
            nameEn: nil,
            bodyPart: exercise.bodyPart,
            unit: exercise.unit,
            equipmentId: nil,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: mapping.primaryMuscles,
            secondaryMuscles: mapping.secondaryMuscles,
            isUserCreated: exercise.isUserCreated,
            images: []
        )
    }

    private func catalogItem(for exerciseInfo: ExerciseInfo) -> ExerciseCatalogItem {
        let mapping = ExerciseMuscleMappingProvider.mapping(for: exerciseInfo)
        let equipment = exerciseInfo.equipmentId.flatMap { localExerciseDataService.equipment(by: $0) }
        return ExerciseCatalogItem(
            catalogId: "json:\(exerciseInfo.id)",
            source: .json,
            dbExerciseId: nil,
            jsonExerciseId: exerciseInfo.id,
            nameZh: exerciseInfo.nameZh,
            nameEn: exerciseInfo.nameEn,
            bodyPart: bodyPart(for: mapping.primaryMuscles),
            unit: .weight,
            equipmentId: exerciseInfo.equipmentId,
            equipmentNameZh: equipment?.nameZh,
            equipmentNameEn: equipment?.nameEn,
            primaryMuscles: mapping.primaryMuscles,
            secondaryMuscles: mapping.secondaryMuscles,
            isUserCreated: false,
            images: exerciseInfo.images
        )
    }

    private func bodyPart(for muscles: [Muscle]) -> BodyPart? {
        if muscles.contains(where: { [.chest, .upperChest, .lowerChest].contains($0) }) { return .chest }
        if muscles.contains(where: { [.upperBack, .lowerBack, .rhomboids, .trapezius, .upperTrapezius, .lowerTrapezius].contains($0) }) { return .back }
        if muscles.contains(where: { [.deltoids, .frontDeltoid, .rearDeltoid].contains($0) }) { return .shoulders }
        if muscles.contains(where: { [.biceps, .triceps, .forearm].contains($0) }) { return .arms }
        if muscles.contains(where: { [.quadriceps, .innerQuad, .outerQuad, .hamstring, .gluteal, .calves, .adductors, .hipFlexors].contains($0) }) { return .legs }
        if muscles.contains(where: { [.abs, .upperAbs, .lowerAbs, .obliques].contains($0) }) { return .core }
        return nil
    }
}
