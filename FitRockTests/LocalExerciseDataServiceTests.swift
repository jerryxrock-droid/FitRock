import XCTest
@testable import FitRock

final class LocalExerciseDataServiceTests: XCTestCase {
    func testBundledExerciseJsonAndImagesAreConsistent() throws {
        let equipments: [Equipment] = try decodeResource("equipments")
        let exercises: [ExerciseInfo] = try decodeResource("exercises")
        let muscles: [String: String] = try decodeResource("muscle_zh_map")

        XCTAssertEqual(equipments.count, 20)
        XCTAssertEqual(exercises.count, 26)
        XCTAssertEqual(muscles["chest"], "胸部")

        let imageRoot = projectRoot()
            .appendingPathComponent("FitRock/Resources/ExerciseImages")
        let result = ExerciseResourceValidator().validate(
            equipments: equipments,
            exercises: exercises,
            imageExists: { FileManager.default.fileExists(atPath: imageRoot.appendingPathComponent($0).path) }
        )

        XCTAssertTrue(result.missingExerciseIds.isEmpty, "Missing exercises: \(result.missingExerciseIds)")
        XCTAssertTrue(result.missingImagePaths.isEmpty, "Missing images: \(result.missingImagePaths)")
    }

    private func decodeResource<T: Decodable>(_ name: String) throws -> T {
        let url = projectRoot()
            .appendingPathComponent("FitRock/Resources/Data")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
