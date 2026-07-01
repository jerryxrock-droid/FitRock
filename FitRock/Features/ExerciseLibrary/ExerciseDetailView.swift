import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var appState: AppState

    // Existing DB exercise mode
    let exercise: Exercise?
    let viewModel: ExerciseLibraryViewModel?

    // New ExerciseInfo mode
    let exerciseInfo: ExerciseInfo?

    @State private var showAddConfirm = false
    @State private var showAddSuccess = false
    @State private var showStartConfirm = false
    @State private var addError: String?

    private let dataService = LocalExerciseDataService.shared

    // MARK: - Init (DB exercise mode)

    init(exercise: Exercise, viewModel: ExerciseLibraryViewModel) {
        self.exercise = exercise
        self.viewModel = viewModel
        self.exerciseInfo = nil
    }

    // MARK: - Init (ExerciseInfo mode)

    init(exerciseInfo: ExerciseInfo) {
        self.exerciseInfo = exerciseInfo
        self.exercise = nil
        self.viewModel = nil
    }

    // MARK: - Teaching content (for DB exercise mode)

    private var teachingContent: ExerciseTeachingContent? {
        guard let name = exercise?.name else { return nil }
        return exerciseTeachingData[name]
    }

    private var navigationTitle: String {
        exercise?.name ?? exerciseInfo?.nameZh ?? ""
    }

    private var primaryMusclesZh: [String] {
        exerciseInfo?.primaryMusclesZh ?? []
    }

    private var secondaryMusclesZh: [String] {
        exerciseInfo?.secondaryMusclesZh ?? []
    }

    private var relatedEquipment: Equipment? {
        guard let eid = exerciseInfo?.equipmentId else { return nil }
        return dataService.equipment(by: eid)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let info = exerciseInfo {
                        // New ExerciseInfo mode
                        exerciseInfoHeader(info)
                        imageSection(info)
                        muscleSection
                        equipmentSection
                        stepsSection(info)
                        mistakesSection(info)
                    } else if let ex = exercise {
                        // Existing DB exercise mode
                        headerSection(ex)
                        NavigationLink(destination: ExerciseHistoryView(exercise: ex)) {
                            historyLinkLabel
                        }
                        .buttonStyle(.plain)
                        if let content = teachingContent {
                            teachingSection(content)
                        } else {
                            emptyTeachingSection
                        }
                    }

                    if exercise != nil {
                        addToWorkoutButton
                            .padding(.top, Theme.Spacing.sm)
                    } else if let info = exerciseInfo {
                        NavigationLink(destination: ExerciseHistoryView(exerciseInfo: info)) {
                            historyLinkLabel
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("添加到训练", isPresented: $showAddConfirm) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                performAddToWorkout()
            }
        } message: {
            Text("将该动作添加到当前训练？")
        }
        .alert("开始新训练", isPresented: $showStartConfirm) {
            Button("取消", role: .cancel) { }
            Button("开始训练") {
                performAddToWorkout()
            }
        } message: {
            Text("当前没有进行中的训练。是否开始新训练并添加\"\(exercise?.name ?? "")\"？")
        }
        .alert(addError ?? "", isPresented: .init(
            get: { addError != nil },
            set: { if !$0 { addError = nil } }
        )) {
            Button("确定", role: .cancel) { }
        }
        .onChange(of: viewModel?.addToWorkoutResult) { result in
            guard let result = result else { return }
            showAddSuccess = true
            switch result {
            case .addedToExisting:
                addError = nil
            case .startedNewWorkout:
                appState.workoutStartedExternally = true
            }
            appState.selectedTab = 1
        }
    }

    // MARK: - ExerciseInfo Header

    private func exerciseInfoHeader(_ info: ExerciseInfo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(info.nameZh)
                .font(Theme.Fonts.title)
                .foregroundColor(Theme.Colors.textPrimary)

            Text(info.nameEn)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: Theme.Spacing.sm) {
                Text(info.difficulty)
                    .font(.system(size: 12))
                    .foregroundColor(difficultyColor(info.difficulty))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor(info.difficulty).opacity(0.15))
                    .cornerRadius(6)

                if let eq = relatedEquipment {
                    Text(eq.nameZh)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent.opacity(0.12))
                        .cornerRadius(6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Image Section

    private func imageSection(_ info: ExerciseInfo) -> some View {
        Group {
            if !info.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(info.images, id: \.self) { imagePath in
                            AsyncExerciseImageView(imagePath: imagePath)
                        }
                    }
                }
            } else {
                // Placeholder when no images
                ZStack {
                    Theme.Colors.surface2
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .frame(height: 200)
                .cornerRadius(Theme.CornerRadius.medium)
            }
        }
    }

    // MARK: - Muscle Section (ExerciseInfo mode)

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !primaryMusclesZh.isEmpty {
                sectionTitle("主练肌群")
                FlowLayout(spacing: 8) {
                    ForEach(primaryMusclesZh, id: \.self) { muscle in
                        muscleTag(muscle, color: Theme.Colors.accent)
                    }
                }
            }

            if !secondaryMusclesZh.isEmpty {
                sectionTitle("辅助肌群")
                FlowLayout(spacing: 8) {
                    ForEach(secondaryMusclesZh, id: \.self) { muscle in
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

    // MARK: - Equipment Section

    private var equipmentSection: some View {
        Group {
            if let eq = relatedEquipment {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    sectionTitle("所需器械")

                    NavigationLink(destination: EquipmentDetailView(equipment: eq)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(eq.nameZh)
                                    .font(Theme.Fonts.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(eq.nameEn)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Theme.Colors.textMuted)
                                .font(.caption)
                        }
                        .padding()
                        .background(Theme.Colors.surface2)
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.CornerRadius.medium)
            }
        }
    }

    // MARK: - Steps Section (ExerciseInfo mode)

    private func stepsSection(_ info: ExerciseInfo) -> some View {
        Group {
            if !info.stepsZh.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    sectionTitle("动作步骤")
                    ForEach(Array(info.stepsZh.enumerated()), id: \.offset) { index, step in
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
        }
    }

    // MARK: - Mistakes Section (ExerciseInfo mode)

    private func mistakesSection(_ info: ExerciseInfo) -> some View {
        Group {
            if !info.commonMistakesZh.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    sectionTitle("常见错误")
                    ForEach(info.commonMistakesZh, id: \.self) { mistake in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.error)
                                .font(.caption)
                            Text(mistake)
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
        }
    }

    // MARK: - Existing DB Exercise Header

    private func headerSection(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label(exercise.bodyPart.displayName, systemImage: "circle.fill")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(exercise.bodyPart.themeColor)
                    .labelStyle(.titleOnly)

                Text(exercise.unit.displayName)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.surface2)
                    .cornerRadius(6)

                if exercise.isUserCreated {
                    Text("自定义")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.accent.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Teaching Content (existing)

    private func teachingSection(_ content: ExerciseTeachingContent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !content.intro.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    sectionTitle("简介")
                    Text(content.intro)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(4)
                }
            }

            if !content.steps.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    sectionTitle("动作步骤")
                    ForEach(Array(content.steps.enumerated()), id: \.offset) { index, step in
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
            }

            if !content.commonMistakes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    sectionTitle("常见错误")
                    ForEach(content.commonMistakes, id: \.self) { mistake in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.error)
                                .font(.caption)
                            Text(mistake)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(3)
                        }
                    }
                }
            }

            if !content.safetyTips.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    sectionTitle("安全提示")
                    ForEach(content.safetyTips, id: \.self) { tip in
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
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var emptyTeachingSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "book")
                .font(.title2)
                .foregroundColor(Theme.Colors.textMuted)
            Text("暂无详细教学内容")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var historyLinkLabel: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(Theme.Colors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("动作历史")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("查看训练记录、PR 和相关肌肉")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Add to Workout (only for DB exercises)

    private var addToWorkoutButton: some View {
        Button {
            handleAddToWorkout()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("添加到训练")
            }
            .font(Theme.Fonts.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.accent)
            .cornerRadius(Theme.CornerRadius.medium)
        }
    }

    private func handleAddToWorkout() {
        guard let exercise = exercise else { return }
        do {
            try DatabaseManager.shared.connect()
            if try DatabaseManager.shared.hasUnfinishedWorkout() {
                showAddConfirm = true
            } else {
                showStartConfirm = true
            }
        } catch {
            addError = "操作失败：\(error.localizedDescription)"
        }
    }

    private func performAddToWorkout() {
        guard let exercise = exercise, let viewModel = viewModel else { return }
        do {
            try viewModel.addExerciseToWorkout(exercise)
        } catch {
            addError = "添加失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.headline)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.bottom, Theme.Spacing.xs)
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "新手友好": return Theme.Colors.success
        case "中级": return Theme.Colors.warning
        default: return Theme.Colors.error
        }
    }
}
