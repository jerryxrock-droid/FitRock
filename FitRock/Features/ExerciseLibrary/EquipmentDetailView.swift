import SwiftUI

struct EquipmentDetailView: View {
    let equipment: Equipment
    private let dataService = LocalExerciseDataService.shared

    private var relatedExercises: [ExerciseInfo] {
        dataService.exercises(for: equipment.id)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    headerSection
                    targetMusclesSection
                    descriptionSection
                    adjustmentsSection
                    safetyTipsSection
                    if !relatedExercises.isEmpty {
                        relatedExercisesSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle(equipment.nameZh)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(equipment.nameZh)
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.Colors.textPrimary)

            Text(equipment.nameEn)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: Theme.Spacing.sm) {
                difficultyBadge
                categoryBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var difficultyBadge: some View {
        Text(equipment.difficulty)
            .font(.system(size: 12))
            .foregroundColor(difficultyColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(difficultyColor.opacity(0.15))
            .cornerRadius(6)
    }

    private var categoryBadge: some View {
        Text(equipment.category)
            .font(.system(size: 12))
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.Colors.surface2)
            .cornerRadius(6)
    }

    private var difficultyColor: Color {
        switch equipment.difficulty {
        case "新手友好": return Theme.Colors.success
        case "中级": return Theme.Colors.warning
        default: return Theme.Colors.error
        }
    }

    // MARK: - Target Muscles

    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("主要训练肌群")

            FlowLayout(spacing: 8) {
                ForEach(equipment.targetMusclesZh, id: \.self) { muscle in
                    muscleTag(muscle, color: Theme.Colors.accent)
                }
            }

            if !equipment.secondaryMusclesZh.isEmpty {
                sectionTitle("辅助肌群")
                FlowLayout(spacing: 8) {
                    ForEach(equipment.secondaryMusclesZh, id: \.self) { muscle in
                        muscleTag(muscle, color: Theme.Colors.textMuted)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func muscleTag(_ name: String, color: Color) -> some View {
        Text(name)
            .font(.system(size: 13))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle("器械简介")
            Text(equipment.descriptionZh)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Adjustments

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("使用前调节方法")
            ForEach(Array(equipment.adjustmentsZh.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                    Text(step)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(3)
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Safety Tips

    private var safetyTipsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("安全提示")
            ForEach(equipment.safetyTipsZh, id: \.self) { tip in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.caption)
                    Text(tip)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(3)
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Related Exercises

    private var relatedExercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("相关动作 (\(relatedExercises.count))")

            ForEach(relatedExercises) { exercise in
                NavigationLink(destination: ExerciseDetailView(exerciseInfo: exercise)) {
                    relatedExerciseCard(exercise)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func relatedExerciseCard(_ exercise: ExerciseInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.nameZh)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(exercise.nameEn)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)

                if !exercise.primaryMusclesZh.isEmpty {
                    Text(exercise.primaryMusclesZh.joined(separator: "、"))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accentLight)
                }
            }

            Spacer()

            difficultyLabel(exercise.difficulty)

            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.textMuted)
                .font(.caption)
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private func difficultyLabel(_ difficulty: String) -> some View {
        Text(difficulty)
            .font(.system(size: 11))
            .foregroundColor(difficulty == "新手友好" ? Theme.Colors.success : (difficulty == "中级" ? Theme.Colors.warning : Theme.Colors.error))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((difficulty == "新手友好" ? Theme.Colors.success : (difficulty == "中级" ? Theme.Colors.warning : Theme.Colors.error)).opacity(0.15))
            .cornerRadius(4)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.headline)
            .foregroundColor(Theme.Colors.textPrimary)
    }
}
