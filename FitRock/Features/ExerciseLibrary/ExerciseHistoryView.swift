import SwiftUI

struct ExerciseHistoryView: View {
    let exerciseId: String?
    let exerciseName: String
    let bodyPart: BodyPart?

    @State private var summary: ExerciseHistorySummary?
    @State private var errorMessage: String?

    private let calculator = ExerciseHistoryCalculator()
    private let catalogItem: ExerciseCatalogItem?
    private let db = DatabaseManager.shared

    init(exercise: Exercise) {
        self.exerciseId = exercise.id
        self.exerciseName = exercise.name
        self.bodyPart = exercise.bodyPart
        self.catalogItem = nil
    }

    init(exerciseInfo: ExerciseInfo) {
        self.exerciseId = nil
        self.exerciseName = exerciseInfo.nameZh
        self.bodyPart = nil
        self.catalogItem = nil
    }

    init(catalogItem: ExerciseCatalogItem) {
        self.exerciseId = catalogItem.dbExerciseId
        self.exerciseName = catalogItem.nameZh
        self.bodyPart = catalogItem.bodyPart
        self.catalogItem = catalogItem
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                if let summary {
                    if summary.workoutCount == 0 {
                        emptyState
                    } else {
                        overview(summary)
                        records(summary)
                        muscles(summary)
                        recentWorkouts(summary)
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.error)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.CornerRadius.medium)
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("动作历史")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(exerciseName)
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("历史训练、个人纪录与相关肌肉")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .font(.title)
                .foregroundColor(Theme.Colors.textMuted)
            Text("暂无该动作的训练记录")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func overview(_ summary: ExerciseHistorySummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            compactCard("训练次数", "\(summary.workoutCount)", "calendar")
            compactCard("总组数", "\(summary.totalSets)", "number")
            compactCard("总容量", String(format: "%.1fT", summary.totalVolume / 1000), "scalemass")
            compactCard("最近训练", summary.latestWorkout?.formattedDate ?? "-", "clock")
        }
    }

    private func records(_ summary: ExerciseHistorySummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("个人纪录")
            if summary.personalRecords.isEmpty {
                Text("暂无纪录")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
            } else {
                ForEach(summary.personalRecords) { record in
                    HStack {
                        Label(record.prType.displayName, systemImage: record.prType.icon)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text(record.formattedValue)
                            .font(Theme.Fonts.headline)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func muscles(_ summary: ExerciseHistorySummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("相关肌肉")
            if summary.relatedMuscles.isEmpty {
                Text("暂无肌肉映射")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(summary.relatedMuscles, id: \.self) { muscle in
                        Text(displayName(for: muscle))
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.accent.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func recentWorkouts(_ summary: ExerciseHistorySummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("最近记录")
            ForEach(summary.recentWorkouts) { workout in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(workout.formattedDate)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text(workout.formattedDuration)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    ForEach(workout.exercises.flatMap(\.sets)) { set in
                        Text("第\(set.setNumber)组  \(formatSet(set))")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
                .padding()
                .background(Theme.Colors.surface2)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func compactCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
            Text(value)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.headline)
            .foregroundColor(Theme.Colors.textPrimary)
    }

    private func load() {
        do {
            try db.connect()
            let workouts = try db.getAllCompletedWorkouts()
            let records = try db.getPersonalRecords()
            if let catalogItem {
                summary = ExerciseCatalogHistoryResolver(calculator: calculator).resolve(
                    item: catalogItem,
                    workouts: workouts,
                    personalRecords: records
                )
            } else {
                summary = calculator.calculate(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    bodyPart: bodyPart,
                    workouts: workouts,
                    personalRecords: records
                )
            }
        } catch {
            errorMessage = "加载动作历史失败：\(error.localizedDescription)"
        }
    }

    private func formatSet(_ set: ExerciseSet) -> String {
        if set.weight > 0 && set.reps > 0 {
            return String(format: "%.1f kg × %d", set.weight, set.reps)
        }
        if set.weight > 0 {
            return String(format: "%.0f", set.weight)
        }
        return "\(set.reps) 次"
    }

    private func displayName(for muscle: Muscle) -> String {
        switch muscle {
        case .abs, .upperAbs, .lowerAbs: return "腹肌"
        case .biceps: return "肱二头肌"
        case .calves: return "小腿"
        case .chest, .upperChest, .lowerChest: return "胸部"
        case .deltoids, .frontDeltoid, .rearDeltoid: return "肩部"
        case .forearm: return "前臂"
        case .gluteal: return "臀部"
        case .hamstring: return "腘绳肌"
        case .lowerBack: return "下背部"
        case .obliques: return "腹斜肌"
        case .quadriceps, .innerQuad, .outerQuad: return "股四头肌"
        case .trapezius, .upperTrapezius, .lowerTrapezius: return "斜方肌"
        case .triceps: return "肱三头肌"
        case .upperBack, .rhomboids: return "上背部"
        default: return muscle.rawValue
        }
    }
}
