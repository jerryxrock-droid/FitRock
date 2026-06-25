import SwiftUI

struct TemplateListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplateViewModel()
    @State private var showDeleteAlert = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var editorTemplate: WorkoutTemplate?

    private let db = DatabaseManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("管理模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("新建") {
                        editorTemplate = WorkoutTemplate(name: "")
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
            .sheet(item: $editorTemplate) { template in
                TemplateEditorView(template: template) {
                    viewModel.loadTemplates()
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let template = templateToDelete {
                        viewModel.deleteTemplate(template)
                    }
                }
            } message: {
                Text("确定要删除这个模板吗？删除后不可恢复。")
            }
        }
        .onAppear {
            viewModel.loadTemplates()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 60))
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
            .padding(.top, Theme.Spacing.md)
        }
    }

    private var templateList: some View {
        List {
            ForEach(viewModel.templates) { template in
                TemplateRowView(
                    template: template,
                    exerciseCount: viewModel.getTemplateExerciseCount(template.id),
                    onEdit: {
                        editorTemplate = template
                    }
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

struct TemplateRowView: View {
    let template: WorkoutTemplate
    let exerciseCount: Int
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(Theme.Fonts.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("\(exerciseCount) 个动作")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("编辑")
                }
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surface2)
                .cornerRadius(8)

                Text(formatDate(template.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
