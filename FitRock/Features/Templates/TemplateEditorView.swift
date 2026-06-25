import SwiftUI

struct TemplateEditorView: View {
    let template: WorkoutTemplate?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templateName: String = ""
    @State private var templateNote: String = ""
    @State private var exercises: [TemplateExerciseItem] = []
    @State private var showExerciseSearch = false
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editingExerciseIndex: Int?

    private let db = DatabaseManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        nameSection
                        noteSection
                        exercisesSection
                        addExerciseButton
                    }
                    .padding()
                }
            }
            .navigationTitle(template == nil ? "新建模板" : "编辑模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveTemplate() }
                        .foregroundColor(Theme.Colors.accent)
                        .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showExerciseSearch) {
                ExerciseSearchView(onSelect: { exercise in
                    addExercise(exercise)
                })
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("确定") {
                    onSave()
                    dismiss()
                }
            } message: {
                Text("模板已保存")
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            if let t = template {
                loadTemplate(t)
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("模板名称")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            TextField("例如：胸肩三头", text: $templateName)
                .textFieldStyle(.roundedBorder)
                .font(Theme.Fonts.body)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("备注（可选）")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            TextField("例如：每周一训练", text: $templateNote)
                .textFieldStyle(.roundedBorder)
                .font(Theme.Fonts.body)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("动作列表")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.leading, Theme.Spacing.xs)

            if exercises.isEmpty {
                Text("暂无动作，请添加")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xl)
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, ex in
                    TemplateExerciseRow(
                        exercise: ex,
                        onUpdateSets: { sets in
                            exercises[index].sets = sets
                        },
                        onDelete: {
                            exercises.remove(at: index)
                        }
                    )
                }
                .onMove { from, to in
                    exercises.move(fromOffsets: from, toOffset: to)
                    for (i, _) in exercises.enumerated() {
                        exercises[i].sortOrder = i
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var addExerciseButton: some View {
        Button {
            showExerciseSearch = true
        } label: {
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

    private func loadTemplate(_ t: WorkoutTemplate) {
        templateName = t.name
        templateNote = t.note ?? ""

        do {
            try db.connect()
            if let detail = try db.getWorkoutTemplateDetail(templateId: t.id) {
                let (_, templateExercises, templateSets) = detail
                exercises = templateExercises.map { te in
                    let relatedSets = templateSets.filter { $0.templateExerciseId == te.id }
                    let sets = relatedSets.isEmpty
                        ? (1...3).map { TemplateSetItem(setNumber: $0, weight: 0, reps: 10, setType: .normal) }
                        : relatedSets.map { TemplateSetItem(setNumber: $0.setNumber, weight: $0.weight, reps: $0.reps, setType: $0.setType) }
                    return TemplateExerciseItem(
                        id: te.id,
                        exerciseId: te.exerciseId,
                        exerciseName: te.exerciseName,
                        bodyPart: te.bodyPart,
                        sortOrder: te.sortOrder,
                        unit: te.unit,
                        sets: sets
                    )
                }
            }
        } catch {
            errorMessage = "加载模板失败"
            showError = true
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let existing = exercises.first { $0.exerciseId == exercise.id }
        guard existing == nil else { return }

        exercises.append(TemplateExerciseItem(
            id: UUID().uuidString,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            bodyPart: exercise.bodyPart,
            sortOrder: exercises.count,
            unit: exercise.unit,
            sets: [
                TemplateSetItem(setNumber: 1, weight: 0, reps: 10, setType: .normal),
                TemplateSetItem(setNumber: 2, weight: 0, reps: 10, setType: .normal),
                TemplateSetItem(setNumber: 3, weight: 0, reps: 10, setType: .normal)
            ]
        ))
        Haptic.light.trigger()
    }

    private func saveTemplate() {
        guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try db.connect()

            let now = Date()
            let templateObj = WorkoutTemplate(
                id: template?.id ?? UUID().uuidString,
                name: templateName.trimmingCharacters(in: .whitespaces),
                note: templateNote.isEmpty ? nil : templateNote,
                createdAt: template?.createdAt ?? now,
                updatedAt: now
            )

            let templateExercises = exercises.enumerated().map { index, ex in
                WorkoutTemplateExercise(
                    id: ex.id,
                    templateId: templateObj.id,
                    exerciseId: ex.exerciseId,
                    exerciseName: ex.exerciseName,
                    bodyPart: ex.bodyPart,
                    sortOrder: index,
                    unit: ex.unit
                )
            }

            var templateSets: [WorkoutTemplateSet] = []
            for ex in exercises {
                for s in ex.sets {
                    templateSets.append(WorkoutTemplateSet(
                        id: UUID().uuidString,
                        templateExerciseId: ex.id,
                        setNumber: s.setNumber,
                        weight: s.weight,
                        reps: s.reps,
                        setType: s.setType
                    ))
                }
            }

            try db.saveWorkoutTemplate(templateObj, exercises: templateExercises, sets: templateSets)
            Haptic.success.trigger()
            showSaveSuccess = true
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Supporting Types

struct TemplateExerciseItem: Identifiable {
    let id: String
    let exerciseId: String
    var exerciseName: String
    let bodyPart: BodyPart
    var sortOrder: Int
    let unit: ExerciseUnit
    var sets: [TemplateSetItem]
}

struct TemplateSetItem: Identifiable, Equatable {
    let id = UUID()
    var setNumber: Int
    var weight: Double
    var reps: Int
    var setType: ExerciseSetType
}

struct TemplateExerciseRow: View {
    let exercise: TemplateExerciseItem
    let onUpdateSets: ([TemplateSetItem]) -> Void
    let onDelete: () -> Void

    @State private var isExpanded = true
    @State private var localSets: [TemplateSetItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    VStack(alignment: .leading) {
                        Text(exercise.exerciseName)
                            .font(Theme.Fonts.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(exercise.bodyPart.displayName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(exercise.bodyPart.themeColor)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.error.opacity(0.7))
                    }
                }
            }
            .buttonStyle(.plain)

            // Sets
            if isExpanded {
                ForEach(localSets.indices, id: \.self) { index in
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(localSets[index].setNumber)")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(width: 24)

                        TextField("0", value: $localSets[index].weight, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)

                        Text(exercise.unit == .duration ? "分钟" : "kg")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)

                        TextField("0", value: $localSets[index].reps, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)

                        Text(exercise.unit == .duration ? "" : "次")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)

                        Spacer()
                    }
                }

                HStack {
                    Button {
                        let newSet = TemplateSetItem(setNumber: localSets.count + 1, weight: 0, reps: 10, setType: .normal)
                        localSets.append(newSet)
                        onUpdateSets(localSets)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("添加组")
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
        .onAppear {
            localSets = exercise.sets
        }
        .onChange(of: localSets) { newValue in
            onUpdateSets(newValue)
        }
    }
}