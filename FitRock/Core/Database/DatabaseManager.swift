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

    private init() {}

    func connect() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsPath.appendingPathComponent("fitrock.sqlite3").path
        db = try Connection(dbPath)
        try createTables()
        try seedExercises()
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
                description: row[colExDescription]
            )
            result.append(ex)
        }
        return result
    }

    func seedExercises() throws {
        guard let db = db else { return }

        let count = try db.scalar(exercises.count)
        if count > 0 { return }

        let defaultExercises: [(String, String, String)] = [
            ("杠铃卧推", "chest", "主要锻炼胸部肌肉"),
            ("哑铃卧推", "chest", "锻炼胸部肌肉"),
            ("双杠臂屈伸", "chest", "锻炼下胸部和肱三头肌"),
            ("哑铃飞鸟", "chest", "锻炼胸大肌"),
            ("高位下拉", "back", "锻炼背阔肌"),
            ("坐姿划船", "back", "锻炼背部肌肉"),
            ("引体向上", "back", "锻炼背阔肌和肱二头肌"),
            ("直臂下压", "back", "锻炼背阔肌"),
            ("杠铃推举", "shoulders", "锻炼肩部肌肉"),
            ("哑铃侧平举", "shoulders", "锻炼三角肌中束"),
            ("前平举", "shoulders", "锻炼三角肌前束"),
            ("俯身飞鸟", "shoulders", "锻炼三角肌后束"),
            ("杠铃弯举", "arms", "锻炼肱二头肌"),
            ("哑铃弯举", "arms", "锻炼肱二头肌"),
            ("锤式弯举", "arms", "锻炼肱肌和肱二头肌"),
            ("窄距卧推", "arms", "锻炼肱三头肌"),
            ("绳索下压", "arms", "锻炼肱三头肌"),
            ("过顶伸展", "arms", "锻炼肱三头肌"),
            ("深蹲", "legs", "锻炼大腿和臀部肌肉"),
            ("腿举", "legs", "锻炼大腿肌肉"),
            ("腿弯举", "legs", "锻炼腘绳肌"),
            ("腿伸展", "legs", "锻炼股四头肌"),
            ("罗马尼亚硬拉", "legs", "锻炼臀部和腘绳肌"),
            ("小腿提踵", "legs", "锻炼小腿肌肉"),
            ("卷腹", "core", "锻炼腹肌"),
            ("平板支撑", "core", "锻炼核心肌群"),
            ("悬垂举腿", "core", "锻炼下腹部"),
            ("俄语转体", "core", "锻炼腹斜肌"),
            ("山羊挺身", "core", "锻炼下背部和臀部"),
            ("跑步机", "cardio", "有氧运动"),
        ]

        for ex in defaultExercises {
            let insert = exercises.insert(
                colExId <- UUID().uuidString,
                colExName <- ex.0,
                colExBodyPart <- ex.1,
                colExDescription <- ex.2
            )
            try db.run(insert)
        }
    }
}
