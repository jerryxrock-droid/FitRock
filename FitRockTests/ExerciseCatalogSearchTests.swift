import XCTest
@testable import FitRock

final class ExerciseCatalogSearchTests: XCTestCase {
    func testDbUserAndJsonItemsCanEnterSelectableList() {
        let items = [
            item(id: "db:bench", source: .db, name: "杠铃卧推", bodyPart: .chest),
            item(id: "user:plank", source: .user, name: "自定义平板", bodyPart: .core),
            item(id: "json:row", source: .json, name: "坐姿绳索划船", bodyPart: .back, equipmentName: "坐姿划船机")
        ]

        let filtered = ExerciseCatalogSearchFilter().filter(items, searchText: "", selectedBodyPart: nil, selectedMuscle: nil)

        XCTAssertEqual(Set(filtered.map(\.catalogId)), ["db:bench", "user:plank", "json:row"])
    }

    func testItemsWithoutBodyPartAreExcludedFromTrainingSelection() {
        let items = [
            item(id: "json:unknown", source: .json, name: "未知动作", bodyPart: nil),
            item(id: "db:squat", source: .db, name: "深蹲", bodyPart: .legs)
        ]

        let filtered = ExerciseCatalogSearchFilter().filter(items, searchText: "", selectedBodyPart: nil, selectedMuscle: nil)

        XCTAssertEqual(filtered.map(\.catalogId), ["db:squat"])
    }

    func testSearchMatchesEquipmentName() {
        let items = [
            item(id: "json:row", source: .json, name: "坐姿绳索划船", bodyPart: .back, equipmentName: "坐姿划船机")
        ]

        let filtered = ExerciseCatalogSearchFilter().filter(items, searchText: "划船机", selectedBodyPart: nil, selectedMuscle: nil)

        XCTAssertEqual(filtered.map(\.catalogId), ["json:row"])
    }

    func testMuscleFilterPrioritizesPrimaryBeforeSecondary() {
        let primary = item(id: "db:curl", source: .db, name: "杠铃弯举", bodyPart: .arms, primary: [.biceps], secondary: [])
        let secondary = item(id: "db:row", source: .db, name: "坐姿划船", bodyPart: .back, primary: [.upperBack], secondary: [.biceps])

        let filtered = ExerciseCatalogSearchFilter().filter([secondary, primary], searchText: "", selectedBodyPart: nil, selectedMuscle: .biceps)

        XCTAssertEqual(filtered.map(\.catalogId), ["db:curl", "db:row"])
    }

    func testSearchScoringPrioritizesExactAndPrefixNameMatches() {
        let exact = item(id: "db:bench", source: .db, name: "卧推", bodyPart: .chest)
        let contains = item(id: "db:dumbbell-bench", source: .db, name: "哑铃卧推", bodyPart: .chest)
        let equipment = item(id: "json:machine", source: .json, name: "胸推训练", bodyPart: .chest, equipmentName: "卧推架")

        let filtered = ExerciseCatalogSearchFilter().filter(
            [equipment, contains, exact],
            searchText: "卧推",
            selectedBodyPart: nil,
            selectedMuscle: nil
        )

        XCTAssertEqual(filtered.map(\.catalogId), ["db:bench", "db:dumbbell-bench", "json:machine"])
    }

    func testSearchNormalizesEnglishCaseAndWhitespace() {
        let bench = item(id: "db:bench", source: .db, name: "杠铃卧推", nameEn: "Bench Press", bodyPart: .chest)

        let filtered = ExerciseCatalogSearchFilter().filter(
            [bench],
            searchText: "  BENCH   press ",
            selectedBodyPart: nil,
            selectedMuscle: nil
        )

        XCTAssertEqual(filtered.map(\.catalogId), ["db:bench"])
    }

    func testSearchAliasMatchesMuscleAndMovementTerms() {
        let curl = item(id: "db:curl", source: .db, name: "杠铃弯举", bodyPart: .arms, primary: [.biceps])
        let row = item(id: "json:row", source: .json, name: "坐姿绳索划船", nameEn: "Seated Cable Rows", bodyPart: .back, primary: [.upperBack])

        let bicepsResults = ExerciseCatalogSearchFilter().filter(
            [row, curl],
            searchText: "二头",
            selectedBodyPart: nil,
            selectedMuscle: nil
        )
        let rowResults = ExerciseCatalogSearchFilter().filter(
            [row, curl],
            searchText: "row",
            selectedBodyPart: nil,
            selectedMuscle: nil
        )

        XCTAssertEqual(bicepsResults.map(\.catalogId), ["db:curl"])
        XCTAssertEqual(rowResults.map(\.catalogId), ["json:row"])
    }

    func testDbAndUserItemsWinTieBeforeJsonTeachingItems() {
        let db = item(id: "db:bench", source: .db, name: "卧推", bodyPart: .chest)
        let json = item(id: "json:bench", source: .json, name: "卧推", bodyPart: .chest)

        let filtered = ExerciseCatalogSearchFilter().filter(
            [json, db],
            searchText: "卧推",
            selectedBodyPart: nil,
            selectedMuscle: nil
        )

        XCTAssertEqual(filtered.map(\.catalogId), ["db:bench", "json:bench"])
    }

    private func item(
        id: String,
        source: ExerciseCatalogSource,
        name: String,
        nameEn: String? = nil,
        bodyPart: BodyPart?,
        equipmentName: String? = nil,
        primary: [Muscle] = [.chest],
        secondary: [Muscle] = []
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogId: id,
            source: source,
            dbExerciseId: source == .json ? nil : String(id.split(separator: ":").last ?? ""),
            jsonExerciseId: source == .json ? String(id.split(separator: ":").last ?? "") : nil,
            nameZh: name,
            nameEn: nameEn,
            bodyPart: bodyPart,
            unit: .weight,
            equipmentId: equipmentName == nil ? nil : "equipment",
            equipmentNameZh: equipmentName,
            equipmentNameEn: nil,
            primaryMuscles: primary,
            secondaryMuscles: secondary,
            isUserCreated: source == .user,
            images: []
        )
    }
}
