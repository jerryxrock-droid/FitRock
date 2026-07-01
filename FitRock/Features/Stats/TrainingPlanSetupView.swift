import SwiftUI

struct TrainingPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var goal: TrainingPlanGoal
    @State private var daysPerWeek: Int
    @State private var sessionMinutes: Int
    @State private var equipmentPreference: TrainingEquipmentPreference
    @State private var avoidedBodyParts: Set<BodyPart>
    @State private var splitStyle: TrainingPlanSplitStyle
    @State private var selectedSessionTitles: Set<String>
    @State private var lockedExerciseNames: [String]
    @State private var excludedExerciseNames: [String]
    @State private var rotationLevel: TrainingPlanRotationLevel
    @State private var enableWeakPointBoost: Bool
    @State private var showLockedSearch = false
    @State private var showExcludedSearch = false

    let mode: Mode
    let onGenerate: ((TrainingPlanPreferences) -> Void)?
    let onSavePreferences: ((TrainingPlanPreferences) -> Void)?

    enum Mode {
        case sheet
        case embedded
    }

    private let dayOptions = [2, 3, 4, 5, 6]
    private let minuteOptions = [30, 45, 60, 75]
    private let bodyPartOptions: [BodyPart] = [.chest, .back, .shoulders, .arms, .legs, .core, .cardio]
    private let sessionOptions: [TrainingPlanSessionTemplate] = [
        TrainingPlanSessionTemplate(title: "Push", bodyParts: [.chest, .shoulders, .arms]),
        TrainingPlanSessionTemplate(title: "Pull", bodyParts: [.back, .arms]),
        TrainingPlanSessionTemplate(title: "Legs", bodyParts: [.legs, .core]),
        TrainingPlanSessionTemplate(title: "全身", bodyParts: [.chest, .back, .legs]),
        TrainingPlanSessionTemplate(title: "弱项补强", bodyParts: [.shoulders, .arms, .core]),
        TrainingPlanSessionTemplate(title: "有氧核心", bodyParts: [.cardio, .core])
    ]

    init(
        initialPreferences: TrainingPlanPreferences = UserDefaultsTrainingPlanPreferencesStore.shared.load(),
        mode: Mode = .sheet,
        onSavePreferences: ((TrainingPlanPreferences) -> Void)? = nil,
        onGenerate: ((TrainingPlanPreferences) -> Void)? = nil
    ) {
        _goal = State(initialValue: initialPreferences.goal)
        _daysPerWeek = State(initialValue: initialPreferences.preferredDaysPerWeek ?? 4)
        _sessionMinutes = State(initialValue: initialPreferences.maxSessionMinutes ?? 60)
        _equipmentPreference = State(initialValue: initialPreferences.equipmentPreference)
        _avoidedBodyParts = State(initialValue: Set(initialPreferences.avoidedBodyParts))
        _splitStyle = State(initialValue: initialPreferences.splitStyle)
        let selectedTitles = initialPreferences.customSessionTemplates.isEmpty
            ? Set(["Push", "Pull", "Legs", "弱项补强"])
            : Set(initialPreferences.customSessionTemplates.map(\.title))
        _selectedSessionTitles = State(initialValue: selectedTitles)
        _lockedExerciseNames = State(initialValue: initialPreferences.lockedExerciseNames)
        _excludedExerciseNames = State(initialValue: initialPreferences.excludedExerciseNames)
        _rotationLevel = State(initialValue: initialPreferences.rotationLevel)
        _enableWeakPointBoost = State(initialValue: initialPreferences.enableWeakPointBoost)
        self.mode = mode
        self.onSavePreferences = onSavePreferences
        self.onGenerate = onGenerate
    }

    var body: some View {
        Group {
            if mode == .sheet {
                NavigationStack {
                    content
                        .navigationTitle("生成计划")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { dismiss() }
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                setupSection(title: "基础") {
                    Picker("目标", selection: $goal) {
                        ForEach(TrainingPlanGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("每周训练", selection: $daysPerWeek) {
                        ForEach(dayOptions, id: \.self) { days in
                            Text("\(days)天").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("单次时长", selection: $sessionMinutes) {
                        ForEach(minuteOptions, id: \.self) { minutes in
                            Text("\(minutes)").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("训练偏好", selection: $equipmentPreference) {
                        ForEach(TrainingEquipmentPreference.allCases, id: \.self) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                setupSection(title: "周结构") {
                    Picker("周结构", selection: $splitStyle) {
                        ForEach(TrainingPlanSplitStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("选择自定义时，将按下方任务池生成每周训练。")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    FlowLayout(spacing: 8) {
                        ForEach(sessionOptions) { session in
                            toggleChip(
                                title: session.title,
                                isSelected: selectedSessionTitles.contains(session.title),
                                color: Theme.Colors.accent
                            ) {
                                if selectedSessionTitles.contains(session.title) {
                                    selectedSessionTitles.remove(session.title)
                                } else {
                                    selectedSessionTitles.insert(session.title)
                                }
                                if splitStyle != .custom {
                                    splitStyle = .custom
                                }
                            }
                        }
                    }
                }

                setupSection(title: "动作控制") {
                    exerciseNameList(title: "锁定动作", names: lockedExerciseNames, emptyText: "优先安排你指定的动作") {
                        showLockedSearch = true
                    } onRemove: { name in
                        lockedExerciseNames.removeAll { $0 == name }
                    }

                    exerciseNameList(title: "排除动作", names: excludedExerciseNames, emptyText: "计划中避开这些动作") {
                        showExcludedSearch = true
                    } onRemove: { name in
                        excludedExerciseNames.removeAll { $0 == name }
                    }
                }

                setupSection(title: "轮换与补强") {
                    Picker("轮换强度", selection: $rotationLevel) {
                        ForEach(TrainingPlanRotationLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("根据热力图做弱项补强", isOn: $enableWeakPointBoost)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)

                    FlowLayout(spacing: 8) {
                        ForEach(bodyPartOptions, id: \.self) { bodyPart in
                            toggleChip(
                                title: "避免\(bodyPart.displayName)",
                                isSelected: avoidedBodyParts.contains(bodyPart),
                                color: bodyPart.themeColor
                            ) {
                                if avoidedBodyParts.contains(bodyPart) {
                                    avoidedBodyParts.remove(bodyPart)
                                } else {
                                    avoidedBodyParts.insert(bodyPart)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if let onSavePreferences {
                        Button {
                            onSavePreferences(preferences)
                        } label: {
                            Label("保存偏好", systemImage: "checkmark.circle")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.Colors.accent.opacity(0.12))
                                .cornerRadius(Theme.CornerRadius.medium)
                        }
                    }

                    if let onGenerate {
                        Button {
                            onGenerate(preferences)
                        } label: {
                            Label("生成4周计划", systemImage: "sparkles")
                                .font(Theme.Fonts.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.Colors.accent)
                                .cornerRadius(Theme.CornerRadius.medium)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .sheet(isPresented: $showLockedSearch) {
            ExerciseCatalogSearchView(onSelect: { item in
                if !lockedExerciseNames.contains(item.nameZh) {
                    lockedExerciseNames.append(item.nameZh)
                }
                showLockedSearch = false
            })
        }
        .sheet(isPresented: $showExcludedSearch) {
            ExerciseCatalogSearchView(onSelect: { item in
                if !excludedExerciseNames.contains(item.nameZh) {
                    excludedExerciseNames.append(item.nameZh)
                }
                lockedExerciseNames.removeAll { $0 == item.nameZh }
                showExcludedSearch = false
            })
        }
    }

    private var preferences: TrainingPlanPreferences {
        let selectedTemplates = sessionOptions.filter { selectedSessionTitles.contains($0.title) }
        let templates = selectedTemplates.isEmpty ? Array(sessionOptions.prefix(daysPerWeek)) : Array(selectedTemplates.prefix(daysPerWeek))
        return TrainingPlanPreferences(
            goal: goal,
            preferredDaysPerWeek: daysPerWeek,
            maxSessionMinutes: sessionMinutes,
            equipmentPreference: equipmentPreference,
            avoidedBodyParts: Array(avoidedBodyParts),
            splitStyle: splitStyle,
            customSessionTemplates: templates,
            lockedExerciseNames: lockedExerciseNames,
            excludedExerciseNames: excludedExerciseNames,
            rotationLevel: rotationLevel,
            enableWeakPointBoost: enableWeakPointBoost
        )
    }

    private func setupSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            content()
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func exerciseNameList(
        title: String,
        names: [String],
        emptyText: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
                Button(action: onAdd) {
                    Label("添加", systemImage: "plus.circle")
                        .font(Theme.Fonts.caption)
                }
            }
            if names.isEmpty {
                Text(emptyText)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            onRemove(name)
                        } label: {
                            HStack(spacing: 4) {
                                Text(name)
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.surface2)
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                    }
                }
            }
        }
    }

    private func toggleChip(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .font(Theme.Fonts.caption)
            .foregroundColor(isSelected ? color : Theme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.16) : Theme.Colors.surface2)
            .cornerRadius(Theme.CornerRadius.small)
        }
    }
}

#Preview {
    TrainingPlanSetupView(onGenerate: { _ in })
}
