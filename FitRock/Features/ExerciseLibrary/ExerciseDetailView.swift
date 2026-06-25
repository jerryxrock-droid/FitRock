import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var appState: AppState

    let exercise: Exercise
    @ObservedObject var viewModel: ExerciseLibraryViewModel

    @State private var showAddConfirm = false
    @State private var showAddSuccess = false
    @State private var showStartConfirm = false
    @State private var addError: String?

    private var teachingContent: ExerciseTeachingContent? {
        exerciseTeachingData[exercise.name]
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Header
                    headerSection

                    // Teaching Content
                    if let content = teachingContent {
                        teachingSection(content)
                    } else {
                        emptyTeachingSection
                    }

                    // Add to workout button
                    addToWorkoutButton
                        .padding(.top, Theme.Spacing.sm)
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
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
            Text("当前没有进行中的训练。是否开始新训练并添加\"\(exercise.name)\"？")
        }
        .alert(addError ?? "", isPresented: .init(
            get: { addError != nil },
            set: { if !$0 { addError = nil } }
        )) {
            Button("确定", role: .cancel) { }
        }
        .onChange(of: viewModel.addToWorkoutResult) { result in
            guard let result = result else { return }
            showAddSuccess = true
            switch result {
            case .addedToExisting:
                addError = nil
            case .startedNewWorkout:
                appState.workoutStartedExternally = true
            }
            // Switch to training tab
            appState.selectedTab = 1
        }
    }

    // MARK: - Header

    private var headerSection: some View {
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

    // MARK: - Teaching Content

    private func teachingSection(_ content: ExerciseTeachingContent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Intro
            if !content.intro.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    sectionTitle("简介")
                    Text(content.intro)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(4)
                }
            }

            // Steps
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

            // Common Mistakes
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

            // Safety Tips
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

    // MARK: - Add to Workout

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
}
