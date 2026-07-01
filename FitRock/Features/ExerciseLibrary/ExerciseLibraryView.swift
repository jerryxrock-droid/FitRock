import SwiftUI

enum LibraryMode: String, CaseIterable {
    case muscle = "按肌肉"
    case equipment = "按器械"
}

struct ExerciseLibraryView: View {
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var libraryMode: LibraryMode = .muscle

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    modePicker

                    if libraryMode == .muscle {
                        muscleModeContent
                    } else {
                        equipmentModeContent
                    }
                }
            }
            .navigationTitle("动作库")
            .searchable(text: $viewModel.searchText, prompt: "搜索动作名称")
        }
        .onAppear {
            viewModel.loadExercises()
            LocalExerciseDataService.shared.loadIfNeeded()
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("模式", selection: $libraryMode) {
            ForEach(LibraryMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Muscle Mode (existing)

    private var muscleModeContent: some View {
        VStack(spacing: 0) {
            MuscleMapSectionView(selectedBodyPart: $viewModel.selectedBodyPart, selectedMuscle: $viewModel.selectedMuscle)
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)

            bodyPartFilter
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.xs)

            activeFilterSummary
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.xs)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(Theme.Colors.accent)
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Theme.Colors.error)
                    Text(error)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.loadExercises()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
                .padding()
                Spacer()
            } else if viewModel.filteredCatalogItems.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(Theme.Colors.textMuted)
                    Text("没有找到匹配的动作")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
            } else {
                exerciseList
            }
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.filteredCatalogItems) { item in
                    NavigationLink(destination: destination(for: item)) {
                        catalogExerciseCard(item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var bodyPartFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "全部", isSelected: viewModel.selectedBodyPart == nil && viewModel.selectedMuscle == nil) {
                    viewModel.clearMuscleFilters()
                }

                ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                    FilterChip(
                        title: bodyPart.displayName,
                        color: bodyPart.themeColor,
                        isSelected: viewModel.selectedBodyPart == bodyPart && viewModel.selectedMuscle == nil
                    ) {
                        if viewModel.selectedBodyPart == bodyPart && viewModel.selectedMuscle == nil {
                            viewModel.clearMuscleFilters()
                        } else {
                            viewModel.selectedBodyPart = bodyPart
                            viewModel.selectedMuscle = nil
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var activeFilterSummary: some View {
        if let selectedMuscle = viewModel.selectedMuscle {
            HStack {
                Text("具体肌肉：\(selectedMuscle.displayName)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.accent)
                Spacer()
                Button("清除") {
                    viewModel.clearMuscleFilters()
                }
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    @ViewBuilder
    private func destination(for item: ExerciseCatalogItem) -> some View {
        if item.source == .json,
           let jsonExerciseId = item.jsonExerciseId,
           let exerciseInfo = LocalExerciseDataService.shared.exercise(by: jsonExerciseId) {
            ExerciseDetailView(exerciseInfo: exerciseInfo)
        } else if let exercise = exercise(for: item) {
            ExerciseDetailView(exercise: exercise, viewModel: viewModel)
        } else {
            ExerciseHistoryView(catalogItem: item)
        }
    }

    private func exercise(for item: ExerciseCatalogItem) -> Exercise? {
        if let dbExerciseId = item.dbExerciseId,
           let existing = viewModel.exercises.first(where: { $0.id == dbExerciseId }) {
            return existing
        }
        guard let bodyPart = item.bodyPart else { return nil }
        return Exercise(
            id: item.recordExerciseId,
            name: item.nameZh,
            bodyPart: bodyPart,
            isUserCreated: item.isUserCreated,
            unit: item.unit
        )
    }

    private func catalogExerciseCard(_ item: ExerciseCatalogItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.nameZh)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    if let bodyPart = item.bodyPart {
                        Label(bodyPart.displayName, systemImage: "circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(bodyPart.themeColor)
                            .labelStyle(.titleOnly)
                    }

                    Text(item.unit.displayName)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    catalogSourceBadge(item.source)
                }

                if !item.primaryMuscles.isEmpty {
                    Text("主练：" + item.primaryMuscles.prefix(3).map(\.displayName).joined(separator: "、"))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                if let equipmentName = item.equipmentNameZh {
                    Text(equipmentName)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.textMuted)
                .font(.caption)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func catalogSourceBadge(_ source: ExerciseCatalogSource) -> some View {
        let title: String
        switch source {
        case .db: title = "内置"
        case .user: title = "我的动作"
        case .json: title = "器械教学"
        }
        return Text(title)
            .font(.system(size: 10))
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Colors.accent.opacity(0.2))
            .cornerRadius(4)
    }

    // MARK: - Equipment Mode

    @ViewBuilder
    private var equipmentModeContent: some View {
        let filtered = viewModel.filteredEquipments
        if filtered.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(Theme.Colors.textMuted)
                Text("没有找到匹配的器械")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(filtered) { equipment in
                        NavigationLink(destination: EquipmentDetailView(equipment: equipment)) {
                            equipmentCard(equipment)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func equipmentCard(_ equipment: Equipment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(equipment.nameZh)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    if !equipment.targetMusclesZh.isEmpty {
                        Label(equipment.targetMusclesZh.prefix(2).joined(separator: "、"), systemImage: "circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.accent)
                            .labelStyle(.titleOnly)
                    }

                    let count = LocalExerciseDataService.shared.equipmentExerciseCount(equipment.id)
                    Text("\(count) 个动作")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }

                // Difficulty
                Text(equipment.difficulty)
                    .font(.system(size: 11))
                    .foregroundColor(difficultyColor(equipment.difficulty))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.textMuted)
                .font(.caption)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "新手友好": return Theme.Colors.success
        case "中级": return Theme.Colors.warning
        default: return Theme.Colors.error
        }
    }
}
