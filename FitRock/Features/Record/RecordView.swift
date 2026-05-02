import SwiftUI

struct RecordView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RecordViewModel()
    @State private var showExerciseSearch = false
    @State private var showSummary = false
    @State private var showEmptyAlert = false
    @State private var showDiscardAlert = false
    @State private var pendingDiscardAction: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.isWorkoutActive {
                    activeWorkoutView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("训练")
            .toolbar {
                if viewModel.isWorkoutActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("结束") {
                            if viewModel.totalSets == 0 {
                                showEmptyAlert = true
                            } else {
                                showSummary = true
                            }
                        }
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showExerciseSearch) {
                ExerciseSearchView(onSelect: { exercise in
                    viewModel.addExercise(exercise)
                })
            }
            .sheet(isPresented: $showSummary) {
                WorkoutSummaryView(
                    workout: viewModel.currentWorkout,
                    exercises: viewModel.workoutExercises,
                    duration: viewModel.elapsedTime,
                    onComplete: {
                        viewModel.finishWorkout()
                        showSummary = false
                    }
                )
            }
            .alert("无法结束训练", isPresented: $showEmptyAlert) {
                Button("确定") { }
            } message: {
                Text("请至少添加一组训练数据")
            }
            .alert("确认删除", isPresented: $showDiscardAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    pendingDiscardAction?()
                }
            } message: {
                Text("确定要删除这个动作吗？")
            }
            .onAppear {
                if appState.shouldResumeWorkout, let workout = appState.unfinishedWorkout {
                    viewModel.resumeWorkout(from: workout)
                    appState.shouldResumeWorkout = false
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if let workout = appState.unfinishedWorkout {
            // Has unfinished workout - show resume option
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.accent)

                Text("继续上次训练")
                    .font(Theme.Fonts.title)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("\(formatDate(workout.startTime)) · \(formatDuration(Date().timeIntervalSince(workout.startTime)))")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)

                Button {
                    viewModel.resumeWorkout(from: workout)
                    appState.shouldResumeWorkout = false
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("继续训练")
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Button {
                    appState.discardUnfinishedWorkout()
                } label: {
                    Text("放弃")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.error)
                }

                Spacer()
            }
        } else {
            // No unfinished workout - show start new
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundColor(Theme.Colors.textMuted)

                Text("开始训练")
                    .font(Theme.Fonts.title)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("记录每一次进步")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)

                Button { viewModel.startWorkout() } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("开始训练")
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes) 分钟"
    }

    private var activeWorkoutView: some View {
        VStack(spacing: 0) {
            timerHeader

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.workoutExercises) { we in
                        ExerciseCardView(
                            workoutExercise: we,
                            onToggleExpand: { viewModel.toggleExpand(for: we.id) },
                            isExpanded: viewModel.isExpanded(we.id),
                            onAddSet: { viewModel.addSet(to: we) },
                            onDeleteSet: { setId in viewModel.deleteSet(setId, from: we) },
                            onUpdateSet: { setId, weight, reps in
                                viewModel.updateSet(setId, weight: weight, reps: reps, in: we)
                            },
                            onToggleWarmUp: { setId in
                                viewModel.toggleWarmUp(setId, in: we)
                            },
                            onRequestDeleteExercise: {
                                pendingDiscardAction = { viewModel.deleteExercise(we) }
                                showDiscardAlert = true
                            }
                        )
                    }

                    addExerciseButton
                }
                .padding()
            }
        }
    }

    private var timerHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("训练时长")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                Text(viewModel.formattedElapsedTime)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.Colors.accent)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(viewModel.workoutExercises.count) 个动作")
                    .font(Theme.Fonts.body)
                Text("\(viewModel.totalSets) 组")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
    }

    private var addExerciseButton: some View {
        Button { showExerciseSearch = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("添加动作")
            }
            .font(Theme.Fonts.body)
            .foregroundColor(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(Theme.Colors.accent.opacity(0.5))
            )
        }
    }
}

struct ExerciseCardView: View {
    let workoutExercise: WorkoutExerciseDisplay
    let onToggleExpand: () -> Void
    let isExpanded: Bool
    let onAddSet: () -> Void
    let onDeleteSet: (String) -> Void
    let onUpdateSet: (String, Double, Int) -> Void
    let onToggleWarmUp: (String) -> Void
    let onRequestDeleteExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button(action: onToggleExpand) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    VStack(alignment: .leading) {
                        Text(workoutExercise.exerciseName)
                            .font(Theme.Fonts.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(workoutExercise.bodyPart.displayName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(workoutExercise.bodyPart.themeColor)

                        if !isExpanded, let lastSets = workoutExercise.lastSets, !lastSets.isEmpty {
                            Text("上次: \(formatLastSets(lastSets))")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                    }

                    Spacer()

                    Text("\(workoutExercise.sets.count) 组")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let lastSets = workoutExercise.lastSets, !lastSets.isEmpty {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Text("上次: \(formatLastSets(lastSets))")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Theme.Colors.divider)
                }

                ForEach(workoutExercise.sets, id: \.id) { set in
                    SwipeableSetRow(
                        set: set,
                        onToggleWarmUp: { onToggleWarmUp(set.id) },
                        onUpdate: { weight, reps in onUpdateSet(set.id, weight, reps) },
                        onDelete: { onDeleteSet(set.id) }
                    )
                }

                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus")
                        Text("添加一组")
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.accent)
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onRequestDeleteExercise()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func formatLastSets(_ sets: [ExerciseSetDisplay]) -> String {
        let validSets = sets.prefix(3)
        let parts = validSets.map { set in
            String(format: "%.1f×%d", set.weight, set.reps)
        }
        let result = parts.joined(separator: " ")
        if sets.count > 3 {
            return result + "...)"
        }
        return result + ")"
    }
}

struct SwipeableSetRow: View {
    let set: ExerciseSetDisplay
    let onToggleWarmUp: () -> Void
    let onUpdate: (Double, Int) -> Void
    let onDelete: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onToggleWarmUp) {
                Text(set.setType == .warmup ? "W" : "\(set.setNumber)")
                    .font(Theme.Fonts.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(set.setType == .warmup ? .white : Theme.Colors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(set.setType == .warmup ? Theme.Colors.warning : Theme.Colors.surface2)
                    .cornerRadius(6)
            }

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onAppear { weightText = set.weight > 0 ? String(format: "%.1f", set.weight) : "" }

            Text("kg")
                .font(Theme.Fonts.body)
                .foregroundColor(Color.white)

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onAppear { repsText = set.reps > 0 ? "\(set.reps)" : "" }

            Text("次")
                .font(Theme.Fonts.body)
                .foregroundColor(Color.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(set.setType == .warmup ? Theme.Colors.warning : Theme.Colors.success)
                .font(.title2)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(set.setType == .warmup ? 0.7 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RecordView()
}
