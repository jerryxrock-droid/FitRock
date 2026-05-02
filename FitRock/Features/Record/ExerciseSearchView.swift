import SwiftUI

struct ExerciseSearchView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var exercises: [Exercise] = []
    @State private var selectedBodyPart: BodyPart?

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
                                        Text(exercise.name)
                                            .font(Theme.Fonts.headline)
                                            .foregroundColor(Theme.Colors.textPrimary)
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
    }
}
