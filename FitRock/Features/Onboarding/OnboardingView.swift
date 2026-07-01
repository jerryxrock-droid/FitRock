import SwiftUI

struct OnboardingView: View {
    let onStartFirstWorkout: () -> Void
    let onFinish: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.allCases

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("FitRock")
                        .font(Theme.Fonts.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Button("跳过") {
                        onFinish()
                    }
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.md)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingCard(page: page)
                            .tag(index)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if selectedPage == pages.count - 1 {
                        onStartFirstWorkout()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPage += 1
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedPage == pages.count - 1 ? "开始第一次训练" : "继续")
                        Image(systemName: selectedPage == pages.count - 1 ? "figure.strengthtraining.traditional" : "chevron.right")
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }
}

private enum OnboardingPage: CaseIterable {
    case record
    case progress
    case heatmap
    case plan
    case localFirst

    var title: String {
        switch self {
        case .record: return "快速记录每一组"
        case .progress: return "看见动作进步"
        case .heatmap: return "发现训练偏重"
        case .plan: return "每周灵活完成计划"
        case .localFirst: return "本地优先"
        }
    }

    var subtitle: String {
        switch self {
        case .record: return "训练中只保留重量、次数、完成状态这些关键操作。"
        case .progress: return "每个动作都有历史、PR 和最近表现，知道自己是否真的变强。"
        case .heatmap: return "训练量会映射到具体肌肉，遗漏肌群会进入下周补强。"
        case .plan: return "每周给出训练任务池，动作会随适应、容量、强度和 deload 周轮换。"
        case .localFirst: return "无需账号。训练数据保存在本机，示例预览不会写入数据库。"
        }
    }

    var icon: String {
        switch self {
        case .record: return "checklist"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .heatmap: return "figure.strengthtraining.traditional"
        case .plan: return "calendar.badge.clock"
        case .localFirst: return "iphone.and.lock"
        }
    }
}

private struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: page.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                Text(page.title)
                    .font(Theme.Fonts.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(page.subtitle)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .lineSpacing(3)
            }

            preview

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    @ViewBuilder
    private var preview: some View {
        switch page {
        case .record:
            sampleWorkoutCard
        case .progress:
            progressCard
        case .heatmap:
            heatmapCard
        case .plan:
            planCard
        case .localFirst:
            localFirstCard
        }
    }

    private var sampleWorkoutCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            previewBadge
            ForEach(SamplePreviewData.workout.exercises.prefix(2)) { exercise in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(exercise.exerciseName)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(exercise.sets.prefix(3).map { set in
                        String(format: "%.0fkg x %d", set.weight, set.reps)
                    }.joined(separator: "  "))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface2)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }

    private var progressCard: some View {
        let history = SamplePreviewData.exerciseHistory
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            previewBadge
            Text(history.exerciseName)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            HStack {
                metric("训练", "\(history.workoutCount) 次")
                metric("总组数", "\(history.totalSets)")
                metric("容量", String(format: "%.1fT", history.totalVolume / 1000))
            }
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private var heatmapCard: some View {
        let summary = SamplePreviewData.muscleHeatmapSummary
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            previewBadge
            BodyView(gender: .male, side: .front)
                .heatmap(summary.intensities)
                .frame(height: 240)
            Text("偏重：胸部、上胸")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.warning)
            Text("遗漏：腘绳肌、小腿、下背部")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private var planCard: some View {
        let plan = SamplePreviewData.trainingPlan
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            previewBadge
            Text(plan.name)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("不必按具体日期，错过一天也不会打乱本周计划。")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            ForEach(plan.weeks.first?.days.filter { $0.status != .rest }.prefix(3) ?? []) { day in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第 \(day.sequenceIndex ?? 1) 练 · \(day.title)")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(day.note?.components(separatedBy: "：").first ?? "动作轮换")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Spacer()
                    Text(day.suggestedExerciseNames.prefix(2).joined(separator: " / "))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
                .padding()
                .background(Theme.Colors.surface2)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }

    private var localFirstCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            previewBadge
            Label("无账号也能记录训练", systemImage: "person.crop.circle.badge.checkmark")
            Label("示例预览只读，不进入统计", systemImage: "eye")
            Label("真实训练保存在本机数据库", systemImage: "internaldrive")
        }
        .font(Theme.Fonts.body)
        .foregroundColor(Theme.Colors.textPrimary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private var previewBadge: some View {
        Text("示例预览")
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.accent.opacity(0.12))
            .cornerRadius(6)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.accent)
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
