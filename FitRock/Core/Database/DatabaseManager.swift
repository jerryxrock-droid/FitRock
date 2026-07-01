import Foundation
import SQLite

final class DatabaseManager: FitRockRepository {
    static let shared = DatabaseManager()

    private var db: Connection?
    private let databaseURL: URL?

    // PR columns
    private let colPrId = SQLite.Expression<Int64>("id")
    private let colPrExerciseId = SQLite.Expression<String>("exercise_id")
    private let colPrExerciseName = SQLite.Expression<String>("exercise_name")
    private let colPrBodyPart = SQLite.Expression<String>("body_part")
    private let colPrType = SQLite.Expression<String>("pr_type")
    private let colPrValue = SQLite.Expression<Double>("value")
    private let colPrWeight = SQLite.Expression<Double?>("weight")
    private let colPrReps = SQLite.Expression<Int?>("reps")
    private let colPrVolume = SQLite.Expression<Double?>("volume")
    private let colPrWorkoutId = SQLite.Expression<String?>("workout_id")
    private let colPrWorkoutExerciseId = SQLite.Expression<String?>("workout_exercise_id")
    private let colPrSetId = SQLite.Expression<String?>("set_id")
    private let colPrAchievedAt = SQLite.Expression<Date>("achieved_at")
    private let colPrCreatedAt = SQLite.Expression<Date>("created_at")
    private let colPrUpdatedAt = SQLite.Expression<Date>("updated_at")

    // PR event columns
    private let colPeId = SQLite.Expression<Int64>("id")
    private let colPeExerciseId = SQLite.Expression<String>("exercise_id")
    private let colPeExerciseName = SQLite.Expression<String>("exercise_name")
    private let colPeBodyPart = SQLite.Expression<String>("body_part")
    private let colPeType = SQLite.Expression<String>("pr_type")
    private let colPeOldValue = SQLite.Expression<Double?>("old_value")
    private let colPeNewValue = SQLite.Expression<Double>("new_value")
    private let colPeWeight = SQLite.Expression<Double?>("weight")
    private let colPeReps = SQLite.Expression<Int?>("reps")
    private let colPeVolume = SQLite.Expression<Double?>("volume")
    private let colPeWorkoutId = SQLite.Expression<String?>("workout_id")
    private let colPeWorkoutExerciseId = SQLite.Expression<String?>("workout_exercise_id")
    private let colPeSetId = SQLite.Expression<String?>("set_id")
    private let colPeAchievedAt = SQLite.Expression<Date>("achieved_at")
    private let colPeCreatedAt = SQLite.Expression<Date>("created_at")

    // Tables
    private let workouts = Table("workouts")
    private let workoutExercises = Table("workout_exercises")
    private let exerciseSets = Table("exercise_sets")
    private let exercises = Table("exercises")
    private let workoutTemplates = Table("workout_templates")
    private let workoutTemplateExercises = Table("workout_template_exercises")
    private let workoutTemplateSets = Table("workout_template_sets")
    private let exercisePRs = Table("exercise_prs")
    private let prEvents = Table("pr_events")

    // Workout columns
    private let colId = SQLite.Expression<String>("id")
    private let colStartTime = SQLite.Expression<Date>("start_time")
    private let colEndTime = SQLite.Expression<Date?>("end_time")
    private let colIsCompleted = SQLite.Expression<Bool>("is_completed")
    private let colTrainingPlanId = SQLite.Expression<String?>("training_plan_id")
    private let colPlannedDayId = SQLite.Expression<String?>("planned_day_id")

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

    // WorkoutTemplate columns
    private let colTemplateId = SQLite.Expression<String>("id")
    private let colTemplateName = SQLite.Expression<String>("name")
    private let colTemplateNote = SQLite.Expression<String?>("note")
    private let colTemplateCreatedAt = SQLite.Expression<Date>("created_at")
    private let colTemplateUpdatedAt = SQLite.Expression<Date>("updated_at")

    // WorkoutTemplateExercise columns
    private let colTemplateExId = SQLite.Expression<String>("id")
    private let colTemplateExTemplateId = SQLite.Expression<String>("template_id")
    private let colTemplateExExerciseId = SQLite.Expression<String>("exercise_id")
    private let colTemplateExExerciseName = SQLite.Expression<String>("exercise_name")
    private let colTemplateExBodyPart = SQLite.Expression<String>("body_part")
    private let colTemplateExSortOrder = SQLite.Expression<Int>("sort_order")
    private let colTemplateExUnit = SQLite.Expression<String>("unit")

    // WorkoutTemplateSet columns
    private let colTemplateSetId = SQLite.Expression<String>("id")
    private let colTemplateSetTemplateExerciseId = SQLite.Expression<String>("template_exercise_id")
    private let colTemplateSetNumber = SQLite.Expression<Int>("set_number")
    private let colTemplateSetWeight = SQLite.Expression<Double>("weight")
    private let colTemplateSetReps = SQLite.Expression<Int>("reps")
    private let colTemplateSetType = SQLite.Expression<String>("set_type")
    private let colTemplateSetRestSeconds = SQLite.Expression<Int?>("rest_seconds")

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL
    }

    func connect() throws {
        guard db == nil else { return }
        let dbURL: URL
        if let databaseURL {
            dbURL = databaseURL
        } else {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--ui-testing") {
                dbURL = FileManager.default.temporaryDirectory.appendingPathComponent("fitrock-ui-testing.sqlite3")
                if arguments.contains("--reset-ui-data") {
                    try? FileManager.default.removeItem(at: dbURL)
                }
            } else {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                dbURL = documentsPath.appendingPathComponent("fitrock.sqlite3")
            }
        }
        db = try Connection(dbURL.path)
        try createTables()
        try seedExercises()
        try migrateSchemaIfNeeded()
    }

    private func migrateSchemaIfNeeded() throws {
        guard let db = db else { return }

        let exerciseTableInfo = try db.prepare("PRAGMA table_info(exercises)")
        var hasIsUserCreated = false
        var hasUnit = false
        for row in exerciseTableInfo {
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

        let workoutTableInfo = try db.prepare("PRAGMA table_info(workouts)")
        var hasTrainingPlanId = false
        var hasPlannedDayId = false
        for row in workoutTableInfo {
            if row[1] as? String == "training_plan_id" {
                hasTrainingPlanId = true
            }
            if row[1] as? String == "planned_day_id" {
                hasPlannedDayId = true
            }
        }
        if !hasTrainingPlanId {
            try db.run("ALTER TABLE workouts ADD COLUMN training_plan_id TEXT")
        }
        if !hasPlannedDayId {
            try db.run("ALTER TABLE workouts ADD COLUMN planned_day_id TEXT")
        }

        // Clean up old estimated_1rm PR records (removed PR type)
        try db.run("DELETE FROM exercise_prs WHERE pr_type = 'estimated_1rm'")
        try db.run("DELETE FROM pr_events WHERE pr_type = 'estimated_1rm'")
    }

    private func createTables() throws {
        guard let db = db else { return }

        try db.run(workouts.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colStartTime)
            t.column(colEndTime)
            t.column(colIsCompleted)
            t.column(colTrainingPlanId)
            t.column(colPlannedDayId)
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

        try db.run(workoutTemplates.create(ifNotExists: true) { t in
            t.column(colTemplateId, primaryKey: true)
            t.column(colTemplateName)
            t.column(colTemplateNote)
            t.column(colTemplateCreatedAt)
            t.column(colTemplateUpdatedAt)
        })

        try db.run(workoutTemplateExercises.create(ifNotExists: true) { t in
            t.column(colTemplateExId, primaryKey: true)
            t.column(colTemplateExTemplateId)
            t.column(colTemplateExExerciseId)
            t.column(colTemplateExExerciseName)
            t.column(colTemplateExBodyPart)
            t.column(colTemplateExSortOrder)
            t.column(colTemplateExUnit)
        })

        try db.run(workoutTemplateSets.create(ifNotExists: true) { t in
            t.column(colTemplateSetId, primaryKey: true)
            t.column(colTemplateSetTemplateExerciseId)
            t.column(colTemplateSetNumber)
            t.column(colTemplateSetWeight)
            t.column(colTemplateSetReps)
            t.column(colTemplateSetType)
            t.column(colTemplateSetRestSeconds)
        })

        try db.run(exercisePRs.create(ifNotExists: true) { t in
            t.column(colPrId, primaryKey: .autoincrement)
            t.column(colPrExerciseId)
            t.column(colPrExerciseName)
            t.column(colPrBodyPart)
            t.column(colPrType)
            t.column(colPrValue)
            t.column(colPrWeight)
            t.column(colPrReps)
            t.column(colPrVolume)
            t.column(colPrWorkoutId)
            t.column(colPrWorkoutExerciseId)
            t.column(colPrSetId)
            t.column(colPrAchievedAt)
            t.column(colPrCreatedAt)
            t.column(colPrUpdatedAt)
            t.unique(colPrExerciseId, colPrType)
        })

        try db.run(prEvents.create(ifNotExists: true) { t in
            t.column(colPeId, primaryKey: .autoincrement)
            t.column(colPeExerciseId)
            t.column(colPeExerciseName)
            t.column(colPeBodyPart)
            t.column(colPeType)
            t.column(colPeOldValue)
            t.column(colPeNewValue)
            t.column(colPeWeight)
            t.column(colPeReps)
            t.column(colPeVolume)
            t.column(colPeWorkoutId)
            t.column(colPeWorkoutExerciseId)
            t.column(colPeSetId)
            t.column(colPeAchievedAt)
            t.column(colPeCreatedAt)
        })
    }

    // MARK: - Workout Operations

    func saveWorkout(_ workout: Workout) throws {
        guard let db = db else { return }

        try db.transaction {
            let insert = workouts.insert(or: .replace,
                colId <- workout.id,
                colStartTime <- workout.startTime,
                colEndTime <- workout.endTime,
                colIsCompleted <- workout.isCompleted,
                colTrainingPlanId <- workout.trainingPlanId,
                colPlannedDayId <- workout.plannedDayId
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

        // Find the most recent completed workout containing this exercise
        var latestWeId: String?
        var latestTime: Date?

        for weRow in try db.prepare(workoutExercises.filter(colExerciseId == exerciseIdValue)) {
            let weId = weRow[colWorkoutExerciseId]
            let wId = weRow[colWorkoutId]

            if let wRow = try db.pluck(workouts.filter(colId == wId && colIsCompleted == true)) {
                let startTime = wRow[colStartTime]
                if latestTime == nil || startTime > latestTime! {
                    latestTime = startTime
                    latestWeId = weId
                }
            }
        }

        guard let resultWeId = latestWeId else { return [] }

        var result: [ExerciseSet] = []
        for setRow in try db.prepare(exerciseSets.filter(colSetWorkoutExerciseId == resultWeId).order(colSetNumber.asc)) {
            result.append(ExerciseSet(
                id: setRow[colSetId],
                setNumber: setRow[colSetNumber],
                weight: setRow[colWeight],
                reps: setRow[colReps],
                setType: ExerciseSetType(rawValue: setRow[colSetType]) ?? .normal,
                isCompleted: setRow[colIsSetCompleted]
            ))
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
            isCompleted: workoutRow?[colIsCompleted] ?? false,
            trainingPlanId: workoutRow?[colTrainingPlanId],
            plannedDayId: workoutRow?[colPlannedDayId]
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

    // MARK: - Template Operations

    func saveWorkoutTemplate(_ template: WorkoutTemplate, exercises: [WorkoutTemplateExercise], sets: [WorkoutTemplateSet]) throws {
        guard let db = db else { return }

        let insert = workoutTemplates.insert(or: .replace,
            colTemplateId <- template.id,
            colTemplateName <- template.name,
            colTemplateNote <- template.note,
            colTemplateCreatedAt <- template.createdAt,
            colTemplateUpdatedAt <- template.updatedAt
        )
        try db.run(insert)

        // Delete old exercises and sets for this template first
        let oldExerciseIds = try db.prepare(workoutTemplateExercises.filter(colTemplateExTemplateId == template.id)).map { $0[colTemplateExId] }
        for oldExId in oldExerciseIds {
            try db.run(workoutTemplateSets.filter(colTemplateSetTemplateExerciseId == oldExId).delete())
        }
        try db.run(workoutTemplateExercises.filter(colTemplateExTemplateId == template.id).delete())

        // Insert new exercises and sets
        for ex in exercises {
            let exInsert = workoutTemplateExercises.insert(or: .replace,
                colTemplateExId <- ex.id,
                colTemplateExTemplateId <- ex.templateId,
                colTemplateExExerciseId <- ex.exerciseId,
                colTemplateExExerciseName <- ex.exerciseName,
                colTemplateExBodyPart <- ex.bodyPart.rawValue,
                colTemplateExSortOrder <- ex.sortOrder,
                colTemplateExUnit <- ex.unit.rawValue
            )
            try db.run(exInsert)

            let relatedSets = sets.filter { $0.templateExerciseId == ex.id }
            for s in relatedSets {
                let setInsert = workoutTemplateSets.insert(or: .replace,
                    colTemplateSetId <- s.id,
                    colTemplateSetTemplateExerciseId <- s.templateExerciseId,
                    colTemplateSetNumber <- s.setNumber,
                    colTemplateSetWeight <- s.weight,
                    colTemplateSetReps <- s.reps,
                    colTemplateSetType <- s.setType.rawValue,
                    colTemplateSetRestSeconds <- s.restSeconds
                )
                try db.run(setInsert)
            }
        }
    }

    func getWorkoutTemplates() throws -> [WorkoutTemplate] {
        guard let db = db else { return [] }

        var result: [WorkoutTemplate] = []
        for row in try db.prepare(workoutTemplates.order(colTemplateUpdatedAt.desc)) {
            let template = WorkoutTemplate(
                id: row[colTemplateId],
                name: row[colTemplateName],
                note: row[colTemplateNote],
                createdAt: row[colTemplateCreatedAt],
                updatedAt: row[colTemplateUpdatedAt]
            )
            result.append(template)
        }
        return result
    }

    func getWorkoutTemplateDetail(templateId: String) throws -> (WorkoutTemplate, [WorkoutTemplateExercise], [WorkoutTemplateSet])? {
        guard let db = db else { return nil }

        guard let row = try db.pluck(workoutTemplates.filter(colTemplateId == templateId)) else {
            return nil
        }

        let template = WorkoutTemplate(
            id: row[colTemplateId],
            name: row[colTemplateName],
            note: row[colTemplateNote],
            createdAt: row[colTemplateCreatedAt],
            updatedAt: row[colTemplateUpdatedAt]
        )

        var exercisesList: [WorkoutTemplateExercise] = []
        let exQuery = workoutTemplateExercises.filter(colTemplateExTemplateId == templateId).order(colTemplateExSortOrder.asc)
        for exRow in try db.prepare(exQuery) {
            let ex = WorkoutTemplateExercise(
                id: exRow[colTemplateExId],
                templateId: exRow[colTemplateExTemplateId],
                exerciseId: exRow[colTemplateExExerciseId],
                exerciseName: exRow[colTemplateExExerciseName],
                bodyPart: BodyPart(rawValue: exRow[colTemplateExBodyPart]) ?? .chest,
                sortOrder: exRow[colTemplateExSortOrder],
                unit: ExerciseUnit(rawValue: exRow[colTemplateExUnit]) ?? .weight
            )
            exercisesList.append(ex)
        }

        var setsList: [WorkoutTemplateSet] = []
        for ex in exercisesList {
            let setQuery = workoutTemplateSets.filter(colTemplateSetTemplateExerciseId == ex.id).order(colTemplateSetNumber.asc)
            for setRow in try db.prepare(setQuery) {
                let s = WorkoutTemplateSet(
                    id: setRow[colTemplateSetId],
                    templateExerciseId: setRow[colTemplateSetTemplateExerciseId],
                    setNumber: setRow[colTemplateSetNumber],
                    weight: setRow[colTemplateSetWeight],
                    reps: setRow[colTemplateSetReps],
                    setType: ExerciseSetType(rawValue: setRow[colTemplateSetType]) ?? .normal,
                    restSeconds: setRow[colTemplateSetRestSeconds]
                )
                setsList.append(s)
            }
        }

        return (template, exercisesList, setsList)
    }

    func deleteWorkoutTemplate(_ templateId: String) throws {
        guard let db = db else { return }

        let exQuery = workoutTemplateExercises.filter(colTemplateExTemplateId == templateId)
        for exRow in try db.prepare(exQuery) {
            let exId = exRow[colTemplateExId]
            try db.run(workoutTemplateSets.filter(colTemplateSetTemplateExerciseId == exId).delete())
        }
        try db.run(exQuery.delete())
        try db.run(workoutTemplates.filter(colTemplateId == templateId).delete())
    }

    func createWorkoutFromTemplate(_ templateId: String) throws -> (Workout, [WorkoutExerciseDisplay])? {
        guard db != nil else { return nil }
        guard let detail = try getWorkoutTemplateDetail(templateId: templateId) else { return nil }

        let (_, templateExercises, templateSets) = detail
        var workout = Workout(id: UUID().uuidString, startTime: Date())

        var workoutExercisesDisplay: [WorkoutExerciseDisplay] = []

        for templateEx in templateExercises {
            var exerciseSets: [ExerciseSet] = []
            var displaySets: [ExerciseSetDisplay] = []

            // Try to get last workout sets for this exercise
            if !templateEx.exerciseId.isEmpty {
                let lastSets = try getLastWorkoutSets(for: templateEx.exerciseId)

                if !lastSets.isEmpty {
                    // Use last workout data
                    for (index, lastSet) in lastSets.enumerated() {
                        let newSet = ExerciseSet(
                            id: UUID().uuidString,
                            setNumber: index + 1,
                            weight: lastSet.weight,
                            reps: lastSet.reps,
                            setType: lastSet.setType,
                            isCompleted: false
                        )
                        exerciseSets.append(newSet)
                        displaySets.append(ExerciseSetDisplay(from: newSet))
                    }
                }
            }

            // If no history, use template default sets
            if displaySets.isEmpty {
                let relatedSets = templateSets.filter { $0.templateExerciseId == templateEx.id }

                if relatedSets.isEmpty {
                    // Create 3 default sets
                    for i in 1...3 {
                        let newSet = ExerciseSet(
                            id: UUID().uuidString,
                            setNumber: i,
                            weight: 0,
                            reps: 10,
                            setType: .normal,
                            isCompleted: false
                        )
                        exerciseSets.append(newSet)
                        displaySets.append(ExerciseSetDisplay(from: newSet))
                    }
                } else {
                    for ts in relatedSets {
                        let newSet = ExerciseSet(
                            id: UUID().uuidString,
                            setNumber: ts.setNumber,
                            weight: ts.weight,
                            reps: ts.reps,
                            setType: ts.setType,
                            isCompleted: false
                        )
                        exerciseSets.append(newSet)
                        displaySets.append(ExerciseSetDisplay(from: newSet))
                    }
                }
            }

            // Get last sets for display (for reference)
            var lastSetsRef: [ExerciseSetDisplay] = []
            if !templateEx.exerciseId.isEmpty {
                let lastSets = try getLastWorkoutSets(for: templateEx.exerciseId)
                lastSetsRef = lastSets.map { ExerciseSetDisplay(from: $0) }
            }

            let weId = UUID().uuidString

            // Create WorkoutExercise with the same ID so currentWorkout.exercises is populated
            let workoutExercise = WorkoutExercise(
                id: weId,
                exerciseId: templateEx.exerciseId,
                exerciseName: templateEx.exerciseName,
                bodyPart: templateEx.bodyPart,
                sets: exerciseSets
            )
            workout.exercises.append(workoutExercise)

            let workoutExerciseDisplay = WorkoutExerciseDisplay(
                id: weId,
                exerciseId: templateEx.exerciseId,
                exerciseName: templateEx.exerciseName,
                bodyPart: templateEx.bodyPart,
                unit: templateEx.unit,
                sets: displaySets,
                lastSets: lastSetsRef.isEmpty ? nil : lastSetsRef
            )
            workoutExercisesDisplay.append(workoutExerciseDisplay)
        }

        return (workout, workoutExercisesDisplay)
    }

    // MARK: - Personal Record Operations

    func getPersonalRecords() throws -> [PersonalRecord] {
        guard let db = db else { return [] }
        var result: [PersonalRecord] = []
        for row in try db.prepare(exercisePRs.order(colPrValue.desc)) {
            result.append(PersonalRecord(
                id: row[colPrId],
                exerciseId: row[colPrExerciseId],
                exerciseName: row[colPrExerciseName],
                bodyPart: BodyPart(rawValue: row[colPrBodyPart]) ?? .chest,
                prType: PRType(rawValue: row[colPrType]) ?? .maxWeight,
                value: row[colPrValue],
                weight: row[colPrWeight],
                reps: row[colPrReps],
                volume: row[colPrVolume],
                workoutId: row[colPrWorkoutId],
                workoutExerciseId: row[colPrWorkoutExerciseId],
                setId: row[colPrSetId],
                achievedAt: row[colPrAchievedAt],
                createdAt: row[colPrCreatedAt],
                updatedAt: row[colPrUpdatedAt]
            ))
        }
        return result
    }

    func getPersonalRecords(for exerciseId: String) throws -> [PersonalRecord] {
        guard let db = db else { return [] }
        var result: [PersonalRecord] = []
        let query = exercisePRs.filter(colPrExerciseId == exerciseId)
        for row in try db.prepare(query) {
            result.append(PersonalRecord(
                id: row[colPrId],
                exerciseId: row[colPrExerciseId],
                exerciseName: row[colPrExerciseName],
                bodyPart: BodyPart(rawValue: row[colPrBodyPart]) ?? .chest,
                prType: PRType(rawValue: row[colPrType]) ?? .maxWeight,
                value: row[colPrValue],
                weight: row[colPrWeight],
                reps: row[colPrReps],
                volume: row[colPrVolume],
                workoutId: row[colPrWorkoutId],
                workoutExerciseId: row[colPrWorkoutExerciseId],
                setId: row[colPrSetId],
                achievedAt: row[colPrAchievedAt],
                createdAt: row[colPrCreatedAt],
                updatedAt: row[colPrUpdatedAt]
            ))
        }
        return result
    }

    func savePersonalRecord(_ record: PersonalRecord) throws {
        guard let db = db else { return }

        if let _ = try db.pluck(exercisePRs.filter(colPrExerciseId == record.exerciseId && colPrType == record.prType.rawValue)) {
            try db.run(exercisePRs.filter(colPrExerciseId == record.exerciseId && colPrType == record.prType.rawValue).update(
                colPrExerciseName <- record.exerciseName,
                colPrBodyPart <- record.bodyPart.rawValue,
                colPrValue <- record.value,
                colPrWeight <- record.weight,
                colPrReps <- record.reps,
                colPrVolume <- record.volume,
                colPrWorkoutId <- record.workoutId,
                colPrWorkoutExerciseId <- record.workoutExerciseId,
                colPrSetId <- record.setId,
                colPrAchievedAt <- record.achievedAt,
                colPrUpdatedAt <- Date()
            ))
        } else {
            try db.run(exercisePRs.insert(
                colPrExerciseId <- record.exerciseId,
                colPrExerciseName <- record.exerciseName,
                colPrBodyPart <- record.bodyPart.rawValue,
                colPrType <- record.prType.rawValue,
                colPrValue <- record.value,
                colPrWeight <- record.weight,
                colPrReps <- record.reps,
                colPrVolume <- record.volume,
                colPrWorkoutId <- record.workoutId,
                colPrWorkoutExerciseId <- record.workoutExerciseId,
                colPrSetId <- record.setId,
                colPrAchievedAt <- record.achievedAt,
                colPrCreatedAt <- Date(),
                colPrUpdatedAt <- Date()
            ))
        }
    }

    func clearAllPersonalRecords() throws {
        guard let db = db else { return }
        try db.run(exercisePRs.delete())
        try db.run(prEvents.delete())
    }

    func savePersonalRecordEvent(_ event: PersonalRecordEvent) throws {
        guard let db = db else { return }
        try db.run(prEvents.insert(
            colPeExerciseId <- event.exerciseId,
            colPeExerciseName <- event.exerciseName,
            colPeBodyPart <- event.bodyPart.rawValue,
            colPeType <- event.prType.rawValue,
            colPeOldValue <- event.oldValue,
            colPeNewValue <- event.newValue,
            colPeWeight <- event.weight,
            colPeReps <- event.reps,
            colPeVolume <- event.volume,
            colPeWorkoutId <- event.workoutId,
            colPeWorkoutExerciseId <- event.workoutExerciseId,
            colPeSetId <- event.setId,
            colPeAchievedAt <- event.achievedAt,
            colPeCreatedAt <- event.createdAt
        ))
    }

    func getPersonalRecordEvents(for workoutId: String) throws -> [PersonalRecordEvent] {
        guard let db = db else { return [] }
        var result: [PersonalRecordEvent] = []
        let query = prEvents.filter(colPeWorkoutId == workoutId).order(colPeCreatedAt.desc)
        for row in try db.prepare(query) {
            result.append(PersonalRecordEvent(
                id: row[colPeId],
                exerciseId: row[colPeExerciseId],
                exerciseName: row[colPeExerciseName],
                bodyPart: BodyPart(rawValue: row[colPeBodyPart]) ?? .chest,
                prType: PRType(rawValue: row[colPeType]) ?? .maxWeight,
                oldValue: row[colPeOldValue],
                newValue: row[colPeNewValue],
                weight: row[colPeWeight],
                reps: row[colPeReps],
                volume: row[colPeVolume],
                workoutId: row[colPeWorkoutId],
                workoutExerciseId: row[colPeWorkoutExerciseId],
                setId: row[colPeSetId],
                achievedAt: row[colPeAchievedAt],
                createdAt: row[colPeCreatedAt]
            ))
        }
        return result
    }
}
