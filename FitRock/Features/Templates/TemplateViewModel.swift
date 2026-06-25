import Foundation
import Combine

final class TemplateViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = DatabaseManager.shared

    func loadTemplates() {
        isLoading = true
        do {
            try db.connect()
            templates = try db.getWorkoutTemplates()
            errorMessage = nil
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            templates = []
        }
        isLoading = false
    }

    func deleteTemplate(_ template: WorkoutTemplate) {
        do {
            try db.connect()
            try db.deleteWorkoutTemplate(template.id)
            templates.removeAll { $0.id == template.id }
            Haptic.medium.trigger()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    func getTemplateExerciseCount(_ templateId: String) -> Int {
        do {
            try db.connect()
            if let detail = try db.getWorkoutTemplateDetail(templateId: templateId) {
                return detail.1.count
            }
        } catch { }
        return 0
    }
}