import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?

    // Tables
    private let workouts = Table("workouts")
    private let workoutExercises = Table("workout_exercises")
    private let exerciseSets = Table("exercise_sets")
    private let exercises = Table("exercises")

    // Workout columns
    private let colId = SQLite.Expression<String>("id")
    private let colStartTime = SQLite.Expression<Date>("start_time")
    private let colEndTime = SQLite.Expression<Date?>("end_time")
    private let colIsCompleted = SQLite.Expression<Bool>("is_completed")

    // WorkoutExercise columns
    private let colWorkoutExerciseId = SQLite.Expression<String>("id")
    private let colWorkoutId = SQLite.Expression<String>("workout_id")
    private let colExerciseId = SQLite.Expression<String>("exercise_id")
    private let colExerciseName = SQLite.Expression<String>("exercise_name")
    private let colBodyPart = SQLite.Expression<String>("body_part")

    // ExerciseSet columns
    private let colSetId = SQLite.Expression<String>("id")
    private let colSetWorkoutExerciseId = SQLite.Expression<String>("workout_exercise_id")
    private let colSetNumber = SQLite.Expression<Int>("set_number")
    private let colWeight = SQLite.Expression<Double>("weight")
    private let colReps = SQLite.Expression<Int>("reps")
    private let colSetType = SQLite.Expression<String>("set_type")
    private let colIsSetCompleted = SQLite.Expression<Bool>("is_completed")

    // Exercise columns
    private let colExId = SQLite.Expression<String>("id")
    private let colExName = SQLite.Expression<String>("exercise_name")
    private let colExBodyPart = SQLite.Expression<String>("body_part")
    private let colExDescription = SQLite.Expression<String>("description")
    private let colExIsUserCreated = SQLite.Expression<Bool>("is_user_created")
    private let colExUnit = SQLite.Expression<String>("unit")

    private init() {}

    func connect() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsPath.appendingPathComponent("fitrock.sqlite3").path
        db = try Connection(dbPath)
        try createTables()
        try seedExercises()
        try migrateSchemaIfNeeded()
    }

    private func migrateSchemaIfNeeded() throws {
        guard let db = db else { return }

        let tableInfo = try db.prepare("PRAGMA table_info(exercises)")
        var hasIsUserCreated = false
        var hasUnit = false
        for row in tableInfo {
            if row[1] as? String == "is_user_created" {
                hasIsUserCreated = true
            }
            if row[1] as? String == "unit" {
                hasUnit = true
            }
        }

        if !hasIsUserCreated {
            try db.run("ALTER TABLE exercises ADD COLUMN is_user_created INTEGER DEFAULT 0")
        }
        if !hasUnit {
            try db.run("ALTER TABLE exercises ADD COLUMN unit TEXT DEFAULT 'weight'")
        }
        // Migrate existing exercises with NULL unit to default weight
        try db.run("UPDATE exercises SET unit = 'weight' WHERE unit IS NULL")
    }

    private func createTables() throws {
        guard let db = db else { return }

        try db.run(workouts.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colStartTime)
            t.column(colEndTime)
            t.column(colIsCompleted)
        })

        try db.run(workoutExercises.create(ifNotExists: true) { t in
            t.column(colWorkoutExerciseId, primaryKey: true)
            t.column(colWorkoutId)
            t.column(colExerciseId)
            t.column(colExerciseName)
            t.column(colBodyPart)
        })

        try db.run(exerciseSets.create(ifNotExists: true) { t in
            t.column(colSetId, primaryKey: true)
            t.column(colSetWorkoutExerciseId)
            t.column(colSetNumber)
            t.column(colWeight)
            t.column(colReps)
            t.column(colSetType)
            t.column(colIsSetCompleted)
        })

        try db.run(exercises.create(ifNotExists: true) { t in
            t.column(colExId, primaryKey: true)
            t.column(colExName)
            t.column(colExBodyPart)
            t.column(colExDescription)
            t.column(colExIsUserCreated)
            t.column(colExUnit)
        })
    }

    // MARK: - Workout Operations

    func saveWorkout(_ workout: Workout) throws {
        guard let db = db else { return }

        let insert = workouts.insert(or: .replace,
            colId <- workout.id,
            colStartTime <- workout.startTime,
            colEndTime <- workout.endTime,
            colIsCompleted <- workout.isCompleted
        )
        try db.run(insert)

        for we in workout.exercises {
            let weInsert = workoutExercises.insert(or: .replace,
                colWorkoutExerciseId <- we.id,
                colWorkoutId <- workout.id,
                colExerciseId <- we.exerciseId,
                colExerciseName <- we.exerciseName,
                colBodyPart <- we.bodyPart.rawValue
            )
            try db.run(weInsert)

            for s in we.sets {
                let setInsert = exerciseSets.insert(or: .replace,
                    colSetId <- s.id,
                    colSetWorkoutExerciseId <- we.id,
                    colSetNumber <- s.setNumber,
                    colWeight <- s.weight,
                    colReps <- s.reps,
                    colSetType <- s.setType.rawValue,
                    colIsSetCompleted <- s.isCompleted
                )
                try db.run(setInsert)
            }
        }
    }

    func getWorkouts(for date: Date) throws -> [Workout] {
        guard let db = db else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        var result: [Workout] = []
        let query = workouts.filter(colStartTime >= startOfDay && colStartTime < endOfDay && colIsCompleted == true)

        for row in try db.prepare(query) {
            let workoutIdValue = row[colId]
            let workout = try parseWorkout(workoutIdValue: workoutIdValue)
            result.append(workout)
        }
        return result
    }

    func getAllCompletedWorkouts() throws -> [Workout] {
        guard let db = db else { return [] }

        var result: [Workout] = []
        let query = workouts.filter(colIsCompleted == true).order(colStartTime.desc)

        for row in try db.prepare(query) {
            let workoutIdValue = row[colId]
            let workout = try parseWorkout(workoutIdValue: workoutIdValue)
            result.append(workout)
        }
        return result
    }

    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] {
        guard let db = db else { return [] }

        let weQuery = workoutExercises.filter(colExerciseId == exerciseIdValue)
        var result: [ExerciseSet] = []

        for weRow in try db.prepare(weQuery) {
            let weId = weRow[colWorkoutExerciseId]

            let setQuery = exerciseSets
                .filter(colSetWorkoutExerciseId == weId)
                .order(colSetNumber.asc)

            for setRow in try db.prepare(setQuery) {
                let set = ExerciseSet(
                    id: setRow[colSetId],
                    setNumber: setRow[colSetNumber],
                    weight: setRow[colWeight],
                    reps: setRow[colReps],
                    setType: ExerciseSetType(rawValue: setRow[colSetType]) ?? .normal,
                    isCompleted: setRow[colIsSetCompleted]
                )
                result.append(set)
            }
        }

        return Array(result.prefix(10))
    }

    func hasUnfinishedWorkout() throws -> Bool {
        guard let db = db else { return false }
        let query = workouts.filter(colIsCompleted == false)
        return try db.pluck(query) != nil
    }

    func getUnfinishedWorkout() throws -> Workout? {
        guard let db = db else { return nil }
        let query = workouts.filter(colIsCompleted == false).limit(1)
        guard let row = try db.pluck(query) else { return nil }
        let workoutIdValue = row[colId]
        return try parseWorkout(workoutIdValue: workoutIdValue)
    }

    func deleteWorkout(_ workoutIdValue: String) throws {
        guard let db = db else { return }

        let weQuery = workoutExercises.filter(colWorkoutId == workoutIdValue)
        for weRow in try db.prepare(weQuery) {
            let weId = weRow[colWorkoutExerciseId]
            try db.run(exerciseSets.filter(colSetWorkoutExerciseId == weId).delete())
        }
        try db.run(weQuery.delete())
        try db.run(workouts.filter(colId == workoutIdValue).delete())
    }

    private func parseWorkout(workoutIdValue: String) throws -> Workout {
        guard let db = db else {
            return Workout(id: workoutIdValue)
        }

        var exercisesList: [WorkoutExercise] = []
        let weQuery = workoutExercises.filter(colWorkoutId == workoutIdValue)

        for weRow in try db.prepare(weQuery) {
            let weId = weRow[colWorkoutExerciseId]
            var setsList: [ExerciseSet] = []

            let setQuery = exerciseSets.filter(colSetWorkoutExerciseId == weId)
            for setRow in try db.prepare(setQuery) {
                let s = ExerciseSet(
                    id: setRow[colSetId],
                    setNumber: setRow[colSetNumber],
                    weight: setRow[colWeight],
                    reps: setRow[colReps],
                    setType: ExerciseSetType(rawValue: setRow[colSetType]) ?? .normal,
                    isCompleted: setRow[colIsSetCompleted]
                )
                setsList.append(s)
            }

            let we = WorkoutExercise(
                id: weId,
                exerciseId: weRow[colExerciseId],
                exerciseName: weRow[colExerciseName],
                bodyPart: BodyPart(rawValue: weRow[colBodyPart]) ?? .chest,
                sets: setsList
            )
            exercisesList.append(we)
        }

        let workoutRow = try db.pluck(workouts.filter(colId == workoutIdValue))

        return Workout(
            id: workoutIdValue,
            startTime: workoutRow?[colStartTime] ?? Date(),
            endTime: workoutRow?[colEndTime],
            exercises: exercisesList,
            isCompleted: workoutRow?[colIsCompleted] ?? false
        )
    }

    // MARK: - Exercise Operations

    func getAllExercises() throws -> [Exercise] {
        guard let db = db else { return [] }

        var result: [Exercise] = []
        for row in try db.prepare(exercises) {
            let ex = Exercise(
                id: row[colExId],
                name: row[colExName],
                bodyPart: BodyPart(rawValue: row[colExBodyPart]) ?? .chest,
                description: row[colExDescription],
                isUserCreated: row[colExIsUserCreated],
                unit: ExerciseUnit(rawValue: row[colExUnit]) ?? .weight
            )
            result.append(ex)
        }
        return result
    }

    func getExercise(by id: String) throws -> Exercise? {
        guard let db = db else { return nil }
        let query = exercises.filter(colExId == id)
        guard let row = try db.pluck(query) else { return nil }
        return Exercise(
            id: row[colExId],
            name: row[colExName],
            bodyPart: BodyPart(rawValue: row[colExBodyPart]) ?? .chest,
            description: row[colExDescription],
            isUserCreated: row[colExIsUserCreated],
            unit: ExerciseUnit(rawValue: row[colExUnit]) ?? .weight
        )
    }

    func saveUserExercise(name: String, bodyPart: BodyPart, unit: ExerciseUnit = .weight) throws {
        guard let db = db else { return }

        let insert = exercises.insert(
            colExId <- UUID().uuidString,
            colExName <- name,
            colExBodyPart <- bodyPart.rawValue,
            colExDescription <- "",
            colExIsUserCreated <- true,
            colExUnit <- unit.rawValue
        )
        try db.run(insert)
    }

    func deleteExercise(_ exerciseId: String) throws {
        guard let db = db else { return }
        try db.run(exercises.filter(colExId == exerciseId).delete())
    }

    func seedExercises() throws {
        guard let db = db else { return }

        let count = try db.scalar(exercises.count)
        if count > 0 {
            // Update existing exercises' unit values
            try updateExerciseUnits(db)
            return
        }

        // (name, bodyPart, description, unit)
        let defaultExercises: [(String, String, String, String)] = [
            // 胸部 - 重量类
            ("杠铃卧推", "chest", "主要锻炼胸部肌肉", "weight"),
            ("哑铃卧推", "chest", "锻炼胸部肌肉", "weight"),
            ("双杠臂屈伸", "chest", "锻炼下胸部和肱三头肌", "weight"),
            ("哑铃飞鸟", "chest", "锻炼胸大肌", "weight"),
            // 背部 - 重量类
            ("高位下拉", "back", "锻炼背阔肌", "weight"),
            ("坐姿划船", "back", "锻炼背部肌肉", "weight"),
            ("引体向上", "back", "锻炼背阔肌和肱二头肌", "reps"),
            ("直臂下压", "back", "锻炼背阔肌", "weight"),
            // 肩部 - 重量类
            ("杠铃推举", "shoulders", "锻炼肩部肌肉", "weight"),
            ("哑铃侧平举", "shoulders", "锻炼三角肌中束", "weight"),
            ("前平举", "shoulders", "锻炼三角肌前束", "weight"),
            ("俯身飞鸟", "shoulders", "锻炼三角肌后束", "weight"),
            // 手臂 - 重量类
            ("杠铃弯举", "arms", "锻炼肱二头肌", "weight"),
            ("哑铃弯举", "arms", "锻炼肱二头肌", "weight"),
            ("锤式弯举", "arms", "锻炼肱肌和肱二头肌", "weight"),
            ("窄距卧推", "arms", "锻炼肱三头肌", "weight"),
            ("绳索下压", "arms", "锻炼肱三头肌", "weight"),
            ("过顶伸展", "arms", "锻炼肱三头肌", "weight"),
            // 腿部 - 重量类
            ("深蹲", "legs", "锻炼大腿和臀部肌肉", "weight"),
            ("腿举", "legs", "锻炼大腿肌肉", "weight"),
            ("腿弯举", "legs", "锻炼腘绳肌", "weight"),
            ("腿伸展", "legs", "锻炼股四头肌", "weight"),
            ("罗马尼亚硬拉", "legs", "锻炼臀部和腘绳肌", "weight"),
            ("小腿提踵", "legs", "锻炼小腿肌肉", "weight"),
            // 核心 - 次数/时长类
            ("卷腹", "core", "锻炼腹肌", "reps"),
            ("平板支撑", "core", "锻炼核心肌群", "duration"),
            ("悬垂举腿", "core", "锻炼下腹部", "reps"),
            ("俄语转体", "core", "锻炼腹斜肌", "reps"),
            ("山羊挺身", "core", "锻炼下背部和臀部", "duration"),
            // 有氧 - 时长类
            ("跑步机", "cardio", "有氧运动", "duration"),
        ]

        for ex in defaultExercises {
            let insert = exercises.insert(
                colExId <- UUID().uuidString,
                colExName <- ex.0,
                colExBodyPart <- ex.1,
                colExDescription <- ex.2,
                colExIsUserCreated <- false,
                colExUnit <- ex.3
            )
            try db.run(insert)
        }
    }

    private func updateExerciseUnits(_ db: Connection) throws {
        // Map exercise names to their correct units
        let exerciseUnits: [String: String] = [
            "引体向上": "reps",
            "卷腹": "reps",
            "平板支撑": "duration",
            "悬垂举腿": "reps",
            "俄语转体": "reps",
            "山羊挺身": "duration",
            "跑步机": "duration"
        ]

        for (name, unit) in exerciseUnits {
            try db.run(exercises.filter(colExName == name).update(colExUnit <- unit))
        }
    }
}
