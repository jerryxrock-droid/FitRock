import SwiftUI

struct ExerciseCatalogSearchView: View {
    let onSelect: (ExerciseCatalogItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var catalogItems: [ExerciseCatalogItem] = []
    @State private var selectedBodyPart: BodyPart?
    @State private var selectedMuscle: Muscle?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var showDeleteAlert = false
    @State private var itemToDelete: ExerciseCatalogItem?

    private let db = DatabaseManager.shared
    private let filter = ExerciseCatalogSearchFilter()

    private var filteredItems: [ExerciseCatalogItem] {
        filter.filter(
            catalogItems,
            searchText: searchText,
            selectedBodyPart: selectedBodyPart,
            selectedMuscle: selectedMuscle
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    bodyPartFilter
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.accent)
                        Spacer()
                    } else if let errorMessage {
                        Spacer()
                        Text(errorMessage)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.error)
                            .padding()
                        Spacer()
                    } else {
                        catalogList
                    }
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
                    if let itemToDelete {
                        deleteExercise(itemToDelete)
                    }
                }
            } message: {
                Text("确定要删除这个动作吗？")
            }
            .searchable(text: $searchText, prompt: "搜索动作、肌肉或器械")
        }
        .onAppear(perform: loadCatalog)
    }

    private var catalogList: some View {
        List {
            if filteredItems.isEmpty {
                Text("没有找到匹配的动作")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Theme.Colors.background)
            } else {
                ForEach(filteredItems) { item in
                    Button {
                        onSelect(item)
                        dismiss()
                    } label: {
                        catalogRow(item)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.nameZh)
                    .accessibilityAddTraits(.isButton)
                    .listRowBackground(Theme.Colors.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if item.source == .user {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var bodyPartFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "全部", isSelected: selectedBodyPart == nil && selectedMuscle == nil) {
                    selectedBodyPart = nil
                    selectedMuscle = nil
                }

                ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                    FilterChip(
                        title: bodyPart.displayName,
                        color: bodyPart.themeColor,
                        isSelected: selectedBodyPart == bodyPart && selectedMuscle == nil
                    ) {
                        if selectedBodyPart == bodyPart && selectedMuscle == nil {
                            selectedBodyPart = nil
                        } else {
                            selectedBodyPart = bodyPart
                            selectedMuscle = nil
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func catalogRow(_ item: ExerciseCatalogItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.nameZh)
                        .font(Theme.Fonts.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    sourceBadge(item.source)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if let bodyPart = item.bodyPart {
                        Text(bodyPart.displayName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(bodyPart.themeColor)
                    }
                    Text(item.unit.displayName)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    if let equipmentName = item.equipmentNameZh {
                        Text(equipmentName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }

                if !item.primaryMuscles.isEmpty {
                    Text("主练：" + item.primaryMuscles.prefix(3).map(\.displayName).joined(separator: "、"))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "plus.circle")
                .foregroundColor(Theme.Colors.accent)
        }
    }

    private func sourceBadge(_ source: ExerciseCatalogSource) -> some View {
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

    private func loadCatalog() {
        isLoading = true
        errorMessage = nil
        do {
            catalogItems = try ExerciseCatalogService().loadCatalogItems()
            isLoading = false
        } catch {
            catalogItems = []
            errorMessage = "加载动作失败：\(error.localizedDescription)"
            isLoading = false
        }
    }

    private func saveExercise(name: String, bodyPart: BodyPart) {
        do {
            try db.connect()
            try db.saveUserExercise(name: name, bodyPart: bodyPart)
            catalogItems = try ExerciseCatalogService().loadCatalogItems()
            Haptic.success.trigger()
        } catch {
            errorMessage = "保存动作失败：\(error.localizedDescription)"
        }
    }

    private func deleteExercise(_ item: ExerciseCatalogItem) {
        guard let dbExerciseId = item.dbExerciseId else { return }
        do {
            try db.connect()
            try db.deleteExercise(dbExerciseId)
            catalogItems = try ExerciseCatalogService().loadCatalogItems()
            Haptic.medium.trigger()
        } catch {
            errorMessage = "删除动作失败：\(error.localizedDescription)"
        }
    }
}
