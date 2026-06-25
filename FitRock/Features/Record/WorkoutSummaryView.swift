import SwiftUI

struct WorkoutSummaryView: View {
    let workout: Workout?
    let exercises: [WorkoutExerciseDisplay]
    let duration: TimeInterval
    let newPRs: [PersonalRecordEvent]
    let onComplete: () -> Void

    init(workout: Workout?, exercises: [WorkoutExerciseDisplay], duration: TimeInterval, newPRs: [PersonalRecordEvent] = [], onComplete: @escaping () -> Void) {
        self.workout = workout
        self.exercises = exercises
        self.duration = duration
        self.newPRs = newPRs
        self.onComplete = onComplete
    }

    @Environment(\.dismiss) private var dismiss

    private var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    private var totalSets: Int {
        exercises.flatMap { $0.sets }.filter { $0.setType != .warmup }.count
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        summaryHeader

                        if !newPRs.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(Theme.Colors.warning)
                                    Text("新纪录")
                                        .font(Theme.Fonts.headline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }

                                ForEach(newPRs) { event in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Image(systemName: event.prType.icon)
                                            .font(.title2)
                                            .foregroundColor(Theme.Colors.warning)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(event.exerciseName)
                                                    .font(Theme.Fonts.body)
                                                    .foregroundColor(Theme.Colors.textPrimary)
                                                Spacer()
                                                Text(event.formattedNewValue)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Theme.Colors.accent)
                                            }
                                            HStack {
                                                Text(event.prType.displayName)
                                                    .font(Theme.Fonts.caption)
                                                    .foregroundColor(Theme.Colors.textMuted)
                                                Spacer()
                                                if event.isNewRecord {
                                                    Text("新纪录")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(Theme.Colors.success)
                                                } else if !event.formattedImprovement.isEmpty {
                                                    Text(event.formattedImprovement)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(Theme.Colors.success)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                    if event.id != newPRs.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(Theme.CornerRadius.medium)
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("训练详情")
                                .font(Theme.Fonts.headline)
                                .foregroundColor(Theme.Colors.textPrimary)

                            ForEach(exercises) { we in
                                ExerciseSummaryRow(workoutExercise: we)
                            }
                        }
                        .padding()
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .padding()
                }
            }
            .navigationTitle("训练完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.success)

            Text("太棒了！")
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.Colors.textPrimary)

            HStack(spacing: Theme.Spacing.xl) {
                SummaryStatItem(title: "时长", value: formattedDuration)
                SummaryStatItem(title: "容量", value: "\(Int(totalVolume))kg")
                SummaryStatItem(title: "组数", value: "\(totalSets)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

struct SummaryStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.accent)
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
    }
}

struct ExerciseSummaryRow: View {
    let workoutExercise: WorkoutExerciseDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(workoutExercise.exerciseName)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text(workoutExercise.bodyPart.displayName)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(workoutExercise.bodyPart.themeColor)
            }

            Text(formatSets(workoutExercise.sets))
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func formatSets(_ sets: [ExerciseSetDisplay]) -> String {
        let validSets = sets.filter { $0.setType != .warmup }
        let parts = validSets.prefix(5).map { set in
            String(format: "%.1fkg × %d次", set.weight, set.reps)
        }
        let result = parts.joined(separator: " | ")
        if validSets.count > 5 {
            return result + " ..."
        }
        return result
    }
}
