import SwiftUI

struct ExerciseSearchView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var exercises: [Exercise] = []
    @State private var selectedBodyPart: BodyPart?
    @State private var showCreateSheet = false
    @State private var showDeleteAlert = false
    @State private var exerciseToDelete: Exercise?

    private let db = DatabaseManager.shared

    var filteredExercises: [Exercise] {
        var result = exercises

        if let bp = selectedBodyPart {
            result = result.filter { $0.bodyPart == bp }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    bodyPartFilter
                        .padding(.horizontal)
                        .padding(.top, 8)

                    List {
                        ForEach(filteredExercises) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(exercise.name)
                                                .font(Theme.Fonts.headline)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            if exercise.isUserCreated {
                                                Text("我的动作")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Theme.Colors.accent)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.Colors.accent.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text(exercise.bodyPart.displayName)
                                            .font(Theme.Fonts.caption)
                                            .foregroundColor(exercise.bodyPart.themeColor)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .listRowBackground(Theme.Colors.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if exercise.isUserCreated {
                                    Button(role: .destructive) {
                                        exerciseToDelete = exercise
                                        showDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("选择动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        showCreateSheet = true
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExerciseView { name, bodyPart in
                    saveExercise(name: name, bodyPart: bodyPart)
                    showCreateSheet = false
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        deleteExercise(exercise)
                    }
                }
            } message: {
                Text("确定要删除这个动作吗？")
            }
            .searchable(text: $searchText, prompt: "搜索动作")
        }
        .onAppear {
            loadExercises()
        }
    }

    private var bodyPartFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "全部", isSelected: selectedBodyPart == nil) {
                    selectedBodyPart = nil
                }

                ForEach(BodyPart.allCases, id: \.self) { bp in
                    FilterChip(
                        title: bp.displayName,
                        color: bp.themeColor,
                        isSelected: selectedBodyPart == bp
                    ) {
                        if selectedBodyPart == bp {
                            selectedBodyPart = nil
                        } else {
                            selectedBodyPart = bp
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func loadExercises() {
        do {
            try db.connect()
            exercises = try db.getAllExercises()
        } catch {
            print("Error loading exercises: \(error)")
            exercises = []
        }
    }

    private func saveExercise(name: String, bodyPart: BodyPart) {
        do {
            try db.connect()
            try db.saveUserExercise(name: name, bodyPart: bodyPart)
            exercises = try db.getAllExercises()
            Haptic.success.trigger()
        } catch {
            print("Error saving exercise: \(error)")
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        do {
            try db.connect()
            try db.deleteExercise(exercise.id)
            exercises = try db.getAllExercises()
            Haptic.medium.trigger()
        } catch {
            print("Error deleting exercise: \(error)")
        }
    }
}

// MARK: - CreateExerciseView
struct CreateExerciseView: View {
    let onSave: (String, BodyPart) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var selectedBodyPart: BodyPart = .chest

    var body: some View {
        NavigationStack {
            Form {
                Section("动作名称") {
                    TextField("输入动作名称", text: $exerciseName)
                }

                Section("选择部位（必选）") {
                    ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                        Button(action: {
                            selectedBodyPart = bodyPart
                        }) {
                            HStack {
                                Circle()
                                    .fill(bodyPart.themeColor)
                                    .frame(width: 12, height: 12)
                                Text(bodyPart.displayName)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                if selectedBodyPart == bodyPart {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建新动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(exerciseName, selectedBodyPart)
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = Theme.Colors.accent
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.2))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
