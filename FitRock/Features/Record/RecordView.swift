import SwiftUI

struct RecordView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RecordViewModel()
    @State private var showExerciseSearch = false
    @State private var showSummary = false
    @State private var showEmptyAlert = false
    @State private var showDiscardAlert = false
    @State private var pendingDiscardAction: (() -> Void)?
    @State private var showCountdown = false
    @State private var showCompletionRing = false
    @State private var showCancelAlert = false
    @State private var showWorkoutRecovery = false
    @State private var prefillEnabled = true
    @State private var showTemplateList = false
    @State private var showTemplateCountdown = false
    @State private var templateToStart: WorkoutTemplate?
    @State private var quickTemplates: [WorkoutTemplate] = []
    @State private var templateDetails: [String: (count: Int, names: [String])] = [:]
    @State private var showTemplateConflictAlert = false
    @State private var pendingTemplateChoice: WorkoutTemplate?
    @State private var showTrainingManagement = false
    @State private var weeklyPlan: WeeklyTrainingPlan?
    @State private var showPlanCountdown = false
    @State private var pendingPlanStart: (plan: TrainingPlan, day: TrainingPlanDay)?

    private let planRepository = UserDefaultsTrainingPlanRepository.shared
    private let weeklyPlanResolver = WeeklyPlanResolver()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.isWorkoutActive {
                    activeWorkoutView
                } else {
                    emptyStateView
                }

                // Countdown overlay
                if showCountdown {
                    CountdownView(onComplete: {
                        showCountdown = false
                        viewModel.startWorkout()
                    })
                }

                // Template countdown overlay
                if showTemplateCountdown, let template = templateToStart {
                    CountdownView(onComplete: {
                        showTemplateCountdown = false
                        templateToStart = nil
                        viewModel.startWorkoutFromTemplate(template.id)
                    })
                }

                if showPlanCountdown, let planStart = pendingPlanStart {
                    CountdownView(onComplete: {
                        showPlanCountdown = false
                        pendingPlanStart = nil
                        viewModel.startWorkoutFromPlan(day: planStart.day, planId: planStart.plan.id)
                    })
                }

                // Completion ring overlay
                if showCompletionRing {
                    CompletionRingView(onComplete: {
                        showCompletionRing = false
                        viewModel.finishWorkout()
                        appState.markWorkoutCompleted(viewModel.currentWorkout?.id)
                        loadActivePlan()
                        showSummary = true
                    })
                }
            }
            .navigationTitle("训练")
            .toolbar {
                if viewModel.isWorkoutActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            showCancelAlert = true
                        }
                        .foregroundColor(Theme.Colors.error)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("结束") {
                            if viewModel.totalSets == 0 {
                                showEmptyAlert = true
                            } else {
                                showCompletionRing = true
                            }
                        }
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .alert("确认取消训练", isPresented: $showCancelAlert) {
                Button("继续训练", role: .cancel) { }
                Button("取消训练", role: .destructive) {
                    viewModel.cancelWorkout()
                    appState.discardUnfinishedWorkout()
                }
            } message: {
                Text("确定要取消当前训练吗？所有记录将被删除。")
            }
            .sheet(isPresented: $showExerciseSearch) {
                ExerciseCatalogSearchView(onSelect: { item in
                    viewModel.addExercise(item)
                })
            }
            .sheet(isPresented: $showSummary) {
                WorkoutSummaryView(
                    workout: viewModel.currentWorkout,
                    exercises: viewModel.workoutExercises,
                    duration: viewModel.elapsedTime,
                    newPRs: viewModel.pendingNewPRs,
                    onComplete: {
                        appState.markWorkoutCompleted(viewModel.currentWorkout?.id)
                        viewModel.dismissWorkoutSummary()
                        loadActivePlan()
                        showSummary = false
                    }
                )
            }
            .sheet(isPresented: $showTemplateList, onDismiss: {
                loadQuickTemplates()
                loadActivePlan()
            }) {
                TrainingManagementView()
            }
            .sheet(isPresented: $showTrainingManagement, onDismiss: {
                loadQuickTemplates()
                loadActivePlan()
            }) {
                TrainingManagementView()
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
            .alert("有未完成的训练", isPresented: $showTemplateConflictAlert) {
                Button("放弃并从模板开始", role: .destructive) {
                    if let template = pendingTemplateChoice {
                        appState.discardUnfinishedWorkout()
                        templateToStart = template
                        pendingTemplateChoice = nil
                        showTemplateCountdown = true
                    }
                }
                Button("继续当前训练", role: .cancel) {
                    pendingTemplateChoice = nil
                }
            } message: {
                Text("您有未完成的训练，是否放弃并从模板开始？")
            }
            .onAppear {
                handlePendingRecoveryRequest()
                if appState.workoutStartedExternally, !viewModel.isWorkoutActive {
                    appState.workoutStartedExternally = false
                    do {
                        try DatabaseManager.shared.connect()
                        if let workout = try DatabaseManager.shared.getUnfinishedWorkout() {
                            viewModel.resumeWorkout(from: workout)
                        }
                    } catch {
                        print("Error resuming externally started workout: \(error)")
                    }
                }
                loadQuickTemplates()
                loadActivePlan()
            }
            .onChange(of: appState.shouldResumeWorkout) { _ in
                handlePendingRecoveryRequest()
            }
            .overlay {
                if showWorkoutRecovery, let workout = appState.unfinishedWorkout {
                    WorkoutRecoveryView(
                        workout: workout,
                        onResume: {
                            viewModel.resumeWorkout(from: workout)
                            showWorkoutRecovery = false
                        },
                        onDiscard: {
                            appState.discardUnfinishedWorkout()
                            showWorkoutRecovery = false
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private func handlePendingRecoveryRequest() {
        if appState.shouldResumeWorkout, appState.unfinishedWorkout != nil {
            showWorkoutRecovery = true
            appState.shouldResumeWorkout = false
        }
    }

    @ViewBuilder
    private var todayPlanSection: some View {
        if let weeklyPlan {
            WeeklyPlanCard(
                weeklyPlan: weeklyPlan,
                onStart: { startRecommendedPlanSession(weeklyPlan) },
                onSelectSession: { startPlanSession($0, in: weeklyPlan.plan) },
                onAdjust: { showTrainingManagement = true },
                onSkip: { updatePlanSessionStatus($0, status: .skipped) }
            )
            .padding(.horizontal, Theme.Spacing.xl)
        } else {
            NoPlanCard {
                showTrainingManagement = true
            }
            .padding(.horizontal, Theme.Spacing.xl)
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
            // No unfinished workout - show start new + template quick-pick
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer().frame(height: 40)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 72))
                        .foregroundColor(Theme.Colors.textMuted)

                    VStack(spacing: Theme.Spacing.sm) {
                        Text("开始训练")
                            .font(Theme.Fonts.title)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("记录每一次进步")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textMuted)
                    }

                    todayPlanSection

                    Button {
                        showCountdown = true
                    } label: {
                        Text("开始自由训练")
                            .font(Theme.Fonts.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.accent)
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)

                    // Template quick-start section
                    if !quickTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("从模板开始")
                                .font(Theme.Fonts.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal, Theme.Spacing.xl)

                            ForEach(Array(quickTemplates.prefix(3).enumerated()), id: \.element.id) { _, template in
                                let detail = templateDetails[template.id]
                                TemplateQuickStartCard(
                                    templateName: template.name,
                                    exerciseCount: detail?.count ?? 0,
                                    exercisePreview: detail?.names ?? [],
                                    onTap: { startFromTemplate(template) }
                                )
                                .padding(.horizontal, Theme.Spacing.xl)
                            }

                            if quickTemplates.count > 3 {
                                Button {
                                    showTrainingManagement = true
                                } label: {
                                    Text("更多模板 (\(quickTemplates.count) 个)")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                    }

                    Button {
                        showTrainingManagement = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("训练管理")
                        }
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)

                    Spacer().frame(height: 40)
                }
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

    private func startFromTemplate(_ template: WorkoutTemplate) {
        if appState.unfinishedWorkout != nil {
            pendingTemplateChoice = template
            showTemplateConflictAlert = true
        } else {
            templateToStart = template
            showTemplateCountdown = true
        }
    }

    private func loadQuickTemplates() {
        do {
            let db = DatabaseManager.shared
            try db.connect()
            let templates = try db.getWorkoutTemplates()
            quickTemplates = templates

            var details: [String: (count: Int, names: [String])] = [:]
            for t in templates {
                if let detail = try db.getWorkoutTemplateDetail(templateId: t.id) {
                    let (_, exercises, _) = detail
                    details[t.id] = (count: exercises.count, names: exercises.map { $0.exerciseName })
                }
            }
            templateDetails = details
        } catch {
            print("Error loading quick templates: \(error)")
        }
    }

    private func loadActivePlan() {
        do {
            try planRepository.markPastDueSessionsSkipped(currentDate: Date())
            let plan = try planRepository.getActivePlan()
            weeklyPlan = weeklyPlanResolver.resolve(plan: plan)
        } catch {
            print("Error loading active plan: \(error)")
            weeklyPlan = nil
        }
    }

    private func startRecommendedPlanSession(_ weeklyPlan: WeeklyTrainingPlan) {
        guard let session = weeklyPlan.recommendedSession else { return }
        startPlanSession(session, in: weeklyPlan.plan)
    }

    private func startPlanSession(_ session: TrainingPlanDay, in plan: TrainingPlan) {
        guard session.status != .rest, session.status != .completed else { return }
        pendingPlanStart = (plan, session)
        showPlanCountdown = true
    }

    private func updatePlanSessionStatus(_ session: TrainingPlanDay, status: TrainingPlanDayStatus) {
        guard let weeklyPlan else { return }
        do {
            try planRepository.updateDayStatus(
                planId: weeklyPlan.plan.id,
                dayId: session.id,
                status: status,
                matchedWorkoutId: session.matchedWorkoutId
            )
            loadActivePlan()
        } catch {
            print("Error updating plan session status: \(error)")
        }
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
                            onAddSet: { viewModel.addSet(to: we, prefill: prefillEnabled) },
                            onDeleteSet: { setId in viewModel.deleteSet(setId, from: we) },
                            onUpdateSet: { setId, weight, reps in
                                viewModel.updateSet(setId, weight: weight, reps: reps, in: we)
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
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .trailing) {
                    Text("\(viewModel.workoutExercises.count) 个动作")
                        .font(Theme.Fonts.body)
                    Text("\(viewModel.totalSets) 组")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Button {
                    prefillEnabled.toggle()
                } label: {
                    Image(systemName: prefillEnabled ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                        .font(.title2)
                        .foregroundColor(prefillEnabled ? Theme.Colors.accent : Theme.Colors.textMuted)
                }
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

// MARK: - Weekly Plan Cards
private struct WeeklyPlanCard: View {
    let weeklyPlan: WeeklyTrainingPlan
    let onStart: () -> Void
    let onSelectSession: (TrainingPlanDay) -> Void
    let onAdjust: () -> Void
    let onSkip: (TrainingPlanDay) -> Void
    @State private var isExpanded = false

    private var plan: TrainingPlan { weeklyPlan.plan }
    private var recommendedSession: TrainingPlanDay? { weeklyPlan.recommendedSession }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本周计划")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    Text(recommendedSession?.title ?? "本周计划已完成")
                        .font(Theme.Fonts.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(summaryText)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                progressBadge
            }

            ProgressView(value: weeklyPlan.completionRate)
                .tint(Theme.Colors.accent)

            Text("本周推荐按顺序完成，也可任意选择训练。")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)

            if let recommendedSession {
                if !recommendedSession.suggestedExerciseNames.isEmpty {
                    Text(recommendedSession.suggestedExerciseNames.prefix(5).joined(separator: " / "))
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                if let note = recommendedSession.note {
                    Text(note)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            } else {
                Text("本周训练任务已经完成，可以开始自由训练或调整计划。")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(weeklyPlan.sessions) { session in
                        WeeklyPlanSessionRow(
                            session: session,
                            onStart: { onSelectSession(session) },
                            onSkip: { onSkip(session) }
                        )
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onStart) {
                    Label(primaryActionTitle, systemImage: recommendedSession == nil ? "checkmark.circle.fill" : "play.fill")
                        .font(Theme.Fonts.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryActionColor)
                        .cornerRadius(Theme.CornerRadius.small)
                }
                .disabled(recommendedSession == nil)

                Menu {
                    Button(isExpanded ? "收起本周任务" : "查看本周任务") {
                        isExpanded.toggle()
                    }
                    Button("调整计划", action: onAdjust)
                    if let recommendedSession, recommendedSession.status == .planned || recommendedSession.status == .moved {
                        Button("跳过推荐训练", role: .destructive) {
                            onSkip(recommendedSession)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surface2)
                        .cornerRadius(Theme.CornerRadius.small)
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .accessibilityIdentifier("weekly-plan-card")
    }

    private var summaryText: String {
        var parts: [String] = []
        parts.append("第 \(weeklyPlan.week.weekIndex) 周")
        parts.append("\(weeklyPlan.completedCount)/\(weeklyPlan.totalCount) 已完成")
        if let recommendedSession, !recommendedSession.targetBodyParts.isEmpty {
            parts.append(recommendedSession.targetBodyParts.map(\.displayName).joined(separator: " / "))
        }
        if let minutes = plan.recommendedSessionMinutes {
            parts.append("预计 \(minutes) 分钟")
        }
        return parts.joined(separator: " · ")
    }

    private var primaryActionTitle: String {
        recommendedSession == nil ? "本周已完成" : "开始推荐训练"
    }

    private var primaryActionColor: Color {
        recommendedSession == nil ? Theme.Colors.success.opacity(0.7) : Theme.Colors.accent
    }

    private var progressBadge: some View {
        Text("\(Int(weeklyPlan.completionRate * 100))%")
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.accent.opacity(0.12))
            .cornerRadius(6)
    }
}

private struct WeeklyPlanSessionRow: View {
    let session: TrainingPlanDay
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("第 \(session.sequenceIndex ?? 1) 练 · \(session.title)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(session.status == .completed ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                    strategyBadge
                }
                Text(session.targetBodyParts.map(\.displayName).joined(separator: " / "))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .lineLimit(1)
                if let completedAt = session.completedAt {
                    Text("完成于 \(shortTime(completedAt))")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.success)
                }
            }
            Spacer()
            Menu {
                if session.status == .planned || session.status == .moved {
                    Button("开始此训练", action: onStart)
                    Button("标记跳过", role: .destructive, action: onSkip)
                }
            } label: {
                Text(session.status.displayName)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(6)
            }
            .disabled(session.status == .completed || session.status == .skipped)
        }
        .padding(10)
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private var strategyBadge: some View {
        Text(strategyLabel)
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Colors.accent.opacity(0.12))
            .cornerRadius(5)
    }

    private var strategyLabel: String {
        guard let note = session.note else { return "计划" }
        if note.contains("适应") { return "适应" }
        if note.contains("容量") { return "容量" }
        if note.contains("强度") { return "强度" }
        if note.contains("Deload") || note.contains("deload") { return "Deload" }
        return "计划"
    }

    private var statusColor: Color {
        switch session.status {
        case .completed: return Theme.Colors.success
        case .skipped: return Theme.Colors.error
        case .moved: return Theme.Colors.warning
        case .rest: return Theme.Colors.textMuted
        case .planned: return Theme.Colors.accent
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

private struct NoPlanCard: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(Theme.Colors.accent)
                Text("还没有训练计划")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Text("根据目标、每周天数和单次时长生成 4 周安排，之后每天都能从这里直接开始。")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)
                .lineSpacing(3)

            Button(action: onGenerate) {
                Label("生成4周计划", systemImage: "sparkles")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .cornerRadius(Theme.CornerRadius.small)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .accessibilityIdentifier("no-plan-card")
    }
}

// MARK: - CountdownView
struct CountdownView: View {
    let onComplete: () -> Void

    @State private var countdownNumber = 3
    @State private var isActive = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                Text("准备开始")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textMuted)

                ZStack {
                    Text("\(countdownNumber)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.accent)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1 : 0.5)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
            }
        }
        .onAppear {
            task = Task {
                isActive = true
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                countdownNumber = 2
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                countdownNumber = 1
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                countdownNumber = 0
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    isActive = false
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
                if Task.isCancelled { return }
                onComplete()
            }
        }
        .onDisappear {
            task?.cancel()
        }
    }
}

// MARK: - CompletionRingView
struct CompletionRingView: View {
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var ringOpacity: Double = 1
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Theme.Colors.surface, lineWidth: 12)
                        .frame(width: 150, height: 150)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Theme.Colors.accent,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))

                    // Checkmark
                    if progress >= 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(Theme.Colors.success)
                            .scaleEffect(checkmarkScale)
                    }
                }

                Text("保存中...")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .opacity(ringOpacity)
            }
        }
        .onAppear {
            animateRing()
        }
    }

    private func animateRing() {
        // Animate ring filling up
        withAnimation(.easeInOut(duration: 0.8)) {
            progress = 1
        }

        // Show checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkScale = 1
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                ringOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onComplete()
            }
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
    let onRequestDeleteExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
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
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: Theme.Spacing.md) {
                    Text("\(workoutExercise.sets.count) 组")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    Button(action: onRequestDeleteExercise) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(Theme.Colors.error.opacity(0.7))
                    }
                }
            }

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
                        unit: workoutExercise.unit,
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
    }

    private func formatLastSets(_ sets: [ExerciseSetDisplay]) -> String {
        let validSets = sets.prefix(3)
        let parts = validSets.map { set in
            if set.weight > 0 && set.reps > 0 {
                return String(format: "%.1f×%d", set.weight, set.reps)
            } else if set.weight > 0 {
                return String(format: "%.1f", set.weight)
            } else {
                return "\(set.reps)次"
            }
        }
        let result = parts.joined(separator: " ")
        if sets.count > 3 {
            return result + "..."
        }
        return result
    }
}

struct SwipeableSetRow: View {
    let set: ExerciseSetDisplay
    let unit: ExerciseUnit
    let onUpdate: (Double, Int) -> Void
    let onDelete: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    private var unitLabel: String {
        switch unit {
        case .weight: return "kg"
        case .reps: return "次"
        case .duration: return "分钟"
        }
    }

    private var valuePlaceholder: String {
        switch unit {
        case .weight: return "0"
        case .reps: return "0"
        case .duration: return "0"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(set.setNumber)")
                .font(Theme.Fonts.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 30, height: 30)
                .background(Theme.Colors.surface2)
                .cornerRadius(6)

            TextField(valuePlaceholder, text: $weightText)
                .keyboardType(unit == .duration ? .numberPad : .decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onAppear {
                if set.weight > 0 {
                    if unit == .duration {
                        weightText = "\(Int(set.weight))"
                    } else {
                        weightText = String(format: "%.1f", set.weight)
                    }
                } else {
                    weightText = ""
                }
            }
                .onChange(of: weightText) { newValue in
                    if unit == .duration {
                        if let weight = Int(newValue), weight > 0 {
                            onUpdate(Double(weight), repsText.isEmpty ? 0 : Int(repsText) ?? 0)
                        }
                    } else {
                        if let weight = Double(newValue), weight > 0 {
                            onUpdate(weight, repsText.isEmpty ? 0 : Int(repsText) ?? 0)
                        }
                    }
                }

            Text(unitLabel)
                .font(Theme.Fonts.body)
                .foregroundColor(Color.white)

            if unit != .duration {
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onAppear { repsText = set.reps > 0 ? "\(set.reps)" : "" }
                    .onChange(of: repsText) { newValue in
                        if let reps = Int(newValue), let weight = Double(weightText), weight > 0 {
                            onUpdate(weight, reps)
                        }
                    }

                Text("次")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Color.white)
            }

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

// MARK: - BodyPartPickerView
struct BodyPartPickerView: View {
    let selectedBodyPart: BodyPart
    let onSelect: (BodyPart) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                    Button(action: {
                        onSelect(bodyPart)
                    }) {
                        HStack {
                            Circle()
                                .fill(bodyPart.themeColor)
                                .frame(width: 12, height: 12)
                            Text(bodyPart.displayName)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            if bodyPart == selectedBodyPart {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择部位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - WorkoutRecoveryView
struct WorkoutRecoveryView: View {
    let workout: Workout
    let onResume: () -> Void
    let onDiscard: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 70))
                        .foregroundColor(Theme.Colors.accent)
                        .rotationEffect(.degrees(isAnimating ? 5 : -5))
                }
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                VStack(spacing: Theme.Spacing.md) {
                    Text("发现未完成的训练")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("您有一项训练记录尚未完成")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)

                    // Workout summary
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("\(formatDate(workout.startTime))")
                            .font(Theme.Fonts.headline)
                            .foregroundColor(Theme.Colors.accent)

                        Text("\(workout.exercises.count) 个动作 · \(formatDuration(Date().timeIntervalSince(workout.startTime)))")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .padding()
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.CornerRadius.medium)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Button(action: onResume) {
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

                    Button(action: onDiscard) {
                        Text("放弃此次训练")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .onAppear {
            isAnimating = true
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
}

// MARK: - TemplateQuickStartCard
struct TemplateQuickStartCard: View {
    let templateName: String
    let exerciseCount: Int
    let exercisePreview: [String]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(templateName)
                            .font(Theme.Fonts.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(exerciseCount) 个动作")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }

                    if !exercisePreview.isEmpty {
                        Text(exercisePreview.prefix(4).joined(separator: " · "))
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding()
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}
