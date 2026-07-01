import SwiftUI

struct TrainingManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var templateViewModel = TemplateViewModel()
    @State private var selectedTab: Tab = .templates
    @State private var editorTemplate: WorkoutTemplate?
    @State private var templateToDelete: WorkoutTemplate?
    @State private var showDeleteAlert = false
    @State private var activePlan: TrainingPlan?
    @State private var weeklyPlan: WeeklyTrainingPlan?
    @State private var preferences: TrainingPlanPreferences = UserDefaultsTrainingPlanPreferencesStore.shared.load()
    @State private var generationError: String?
    @State private var showSavedMessage = false

    private let planRepository = UserDefaultsTrainingPlanRepository.shared
    private let preferencesStore = UserDefaultsTrainingPlanPreferencesStore.shared
    private let weeklyPlanResolver = WeeklyPlanResolver()
    private let planGenerationService = TrainingPlanGenerationService()

    enum Tab: String, CaseIterable {
        case templates = "模板"
        case plan = "训练计划"
        case preferences = "计划偏好"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("训练管理", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch selectedTab {
                    case .templates:
                        templatesTab
                    case .plan:
                        planTab
                    case .preferences:
                        preferencesTab
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("训练管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
                if selectedTab == .templates {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("新建") {
                            editorTemplate = WorkoutTemplate(name: "")
                        }
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .sheet(item: $editorTemplate) { template in
                TemplateEditorView(template: template) {
                    templateViewModel.loadTemplates()
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let templateToDelete {
                        templateViewModel.deleteTemplate(templateToDelete)
                    }
                }
            } message: {
                Text("确定要删除这个模板吗？删除后不可恢复。")
            }
            .alert("生成计划失败", isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )) {
                Button("确定") { generationError = nil }
            } message: {
                Text(generationError ?? "")
            }
            .alert("偏好已保存", isPresented: $showSavedMessage) {
                Button("确定") { }
            }
        }
        .onAppear {
            templateViewModel.loadTemplates()
            preferences = preferencesStore.load()
            loadPlan()
        }
    }

    private var templatesTab: some View {
        Group {
            if templateViewModel.templates.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.Colors.textMuted)
                    Text("暂无模板")
                        .font(Theme.Fonts.title)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("创建模板，快速开始训练")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textMuted)
                    Button("创建模板") {
                        editorTemplate = WorkoutTemplate(name: "")
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(templateViewModel.templates) { template in
                        TemplateRowView(
                            template: template,
                            exerciseCount: templateViewModel.getTemplateExerciseCount(template.id),
                            onEdit: { editorTemplate = template }
                        )
                        .listRowBackground(Theme.Colors.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                templateToDelete = template
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var planTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let activePlan {
                    planSummaryCard(activePlan)
                    if let weeklyPlan {
                        weekPoolCard(weeklyPlan)
                    }
                    planOverview(activePlan)
                    planActions
                } else {
                    emptyPlanCard
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var preferencesTab: some View {
        TrainingPlanSetupView(
            initialPreferences: preferences,
            mode: .embedded,
            onSavePreferences: savePreferences
        )
    }

    private var emptyPlanCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("还没有训练计划")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("使用计划偏好生成 4 周周训练池。你可以先编辑偏好，控制周结构、动作锁定和轮换强度。")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)
            Button {
                generatePlan(preferences)
            } label: {
                Label("按计划偏好生成4周计划", systemImage: "sparkles")
                    .font(Theme.Fonts.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.small)
            }
            Button {
                selectedTab = .preferences
            } label: {
                Label("编辑计划偏好", systemImage: "slider.horizontal.3")
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
        .padding(.horizontal)
    }

    private var planActions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                generatePlan(preferences)
            } label: {
                Label("按计划偏好重新生成", systemImage: "arrow.clockwise")
                    .font(Theme.Fonts.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.small)
            }

            Button {
                selectedTab = .preferences
            } label: {
                Label("编辑计划偏好", systemImage: "slider.horizontal.3")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .cornerRadius(Theme.CornerRadius.small)
            }

            Button(role: .destructive) {
                clearPlan()
            } label: {
                Label("停用当前计划", systemImage: "xmark.circle")
                    .font(Theme.Fonts.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal)
    }

    private func planSummaryCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(Theme.Fonts.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("\(plan.trainingDaysPerWeek) 天/周 · \(plan.recommendedSessionMinutes ?? 60) 分钟 · \(plan.equipmentPreference?.displayName ?? "不限")")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                Text("\(Int((weeklyPlan?.completionRate ?? 0) * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text(plan.recommendationReason)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .lineSpacing(3)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.horizontal)
    }

    private func weekPoolCard(_ weeklyPlan: WeeklyTrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("本周任务池")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            ForEach(weeklyPlan.sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(session.sequenceIndex ?? 1) 练 · \(session.title)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(session.suggestedExerciseNames.prefix(5).joined(separator: " / "))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(2)
                }
                .padding(10)
                .background(Theme.Colors.surface2)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.horizontal)
    }

    private func planOverview(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("4 周概览")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            ForEach(plan.weeks) { week in
                Text("第 \(week.weekIndex) 周 · " + week.days.map(\.title).joined(separator: " / "))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.horizontal)
    }

    private func loadPlan() {
        do {
            try planRepository.markPastDueSessionsSkipped(currentDate: Date())
            activePlan = try planRepository.getActivePlan()
            weeklyPlan = weeklyPlanResolver.resolve(plan: activePlan)
        } catch {
            activePlan = nil
            weeklyPlan = nil
        }
    }

    private func savePreferences(_ newPreferences: TrainingPlanPreferences) {
        preferences = newPreferences
        preferencesStore.save(newPreferences)
        showSavedMessage = true
    }

    private func generatePlan(_ newPreferences: TrainingPlanPreferences) {
        preferences = newPreferences
        preferencesStore.save(newPreferences)
        planGenerationService.generate(preferences: newPreferences) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let plan):
                    activePlan = plan
                    weeklyPlan = weeklyPlanResolver.resolve(plan: plan)
                    selectedTab = .plan
                case .failure(let error):
                    generationError = error.localizedDescription
                }
            }
        }
    }

    private func clearPlan() {
        do {
            try planRepository.clearActivePlan()
            activePlan = nil
            weeklyPlan = nil
        } catch {
            generationError = error.localizedDescription
        }
    }
}
