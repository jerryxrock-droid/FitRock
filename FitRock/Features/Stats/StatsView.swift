import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    overviewCards
                    personalRecordsSection
                    muscleHeatmapSection
                    trainingPlanReviewSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Theme.Colors.background)
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .accessibilityLabel("设置")
                }
            }
        }
        .onAppear {
            viewModel.loadStats(for: .all)
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            StatsCard(title: "训练次数", value: "\(viewModel.workoutCount)", icon: "figure.run")
            StatsCard(title: "平均单次", value: String(format: "%.1f", viewModel.workoutCount > 0 ? viewModel.totalVolume / Double(viewModel.workoutCount) / 1000 : 0.0) + "T", icon: "scalemass")
            StatsCard(title: "总时长", value: viewModel.formattedTotalDuration, icon: "clock")
            StatsCard(title: "总组数", value: "\(viewModel.totalSets)", icon: "number")
        }
        .frame(maxWidth: .infinity)
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Theme.Colors.warning)
                Text("个人纪录")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            if viewModel.personalRecords.isEmpty {
                Text("暂无纪录")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let grouped = Dictionary(grouping: viewModel.personalRecords) { $0.exerciseName }
                let bestRecords: [PersonalRecord] = grouped.values.compactMap { records in
                    // Priority: maxWeight > exerciseVolume > duration
                    if let mw = records.first(where: { $0.prType == .maxWeight }) { return mw }
                    if let vol = records.first(where: { $0.prType == .exerciseVolume }) { return vol }
                    if let dur = records.first(where: { $0.prType == .duration }) { return dur }
                    return nil
                }.sorted { $0.prType.priority < $1.prType.priority }

                ForEach(bestRecords) { pr in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: pr.prType.icon)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.warning)
                                Text(pr.exerciseName)
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                            }
                            if !pr.detailText.isEmpty {
                                Text(pr.detailText)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        Text(pr.formattedValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                            .lineLimit(1)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if pr.id != bestRecords.last?.id {
                        Divider()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var muscleHeatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("肌肉热力图")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Picker("范围", selection: Binding(
                    get: { viewModel.heatmapPeriod },
                    set: { viewModel.setHeatmapPeriod($0) }
                )) {
                    ForEach(HeatmapPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
            }

            if viewModel.muscleHeatmapSummary.intensities.isEmpty {
                Text(viewModel.workoutCount == 0 ? "完成第一次训练后生成肌肉热力图" : "暂无肌肉训练量数据")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                heatmapBodyViews

                heatmapSummaryRows
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var heatmapBodyViews: some View {
        HStack(spacing: Theme.Spacing.md) {
            heatmapBodyView(title: "正面", side: .front)
            heatmapBodyView(title: "背面", side: .back)
        }
        .accessibilityElement(children: .contain)
    }

    private func heatmapBodyView(title: String, side: BodySide) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            BodyView(gender: .male, side: side)
                .heatmap(viewModel.muscleHeatmapSummary.intensities)
                .frame(height: 260)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("heatmap-\(title)")
    }

    private var heatmapSummaryRows: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if !viewModel.muscleHeatmapSummary.overloaded.isEmpty {
                Text("偏重：" + viewModel.muscleHeatmapSummary.overloaded.map(displayName).joined(separator: "、"))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.warning)
            }
            if !viewModel.muscleHeatmapSummary.missing.isEmpty {
                Text("遗漏：" + viewModel.muscleHeatmapSummary.missing.map(displayName).joined(separator: "、"))
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    private var trainingPlanReviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("计划复盘")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
            }

            if let plan = viewModel.activeTrainingPlan {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("\(formattedDate(plan.startDate)) 开始 · 4 周训练池")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                        Spacer()
                        Text("\(Int(viewModel.planCompletion.completionRate * 100))%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                    }

                    ProgressView(value: viewModel.planCompletion.completionRate)
                        .tint(Theme.Colors.accent)

                    planConfigurationSummary(plan)

                    Text(plan.recommendationReason)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .lineSpacing(3)

                    planFocusSummary(plan)

                    ForEach(plan.weeks) { week in
                        planWeekView(week)
                    }
                }
            } else {
                emptyPlanContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var emptyPlanContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundColor(Theme.Colors.textMuted)
            Text(viewModel.workoutCount == 0 ? "可在训练页生成 4 周计划，让每天训练更明确" : "基于历史训练、肌肉热力图和可选健康数据复盘计划完成情况")
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)

        }
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity)
    }

    private func planConfigurationSummary(_ plan: TrainingPlan) -> some View {
        HStack(spacing: 8) {
            planSummaryChip(plan.goal.displayName)
            planSummaryChip("每周 \(plan.trainingDaysPerWeek) 天")
            if let minutes = plan.recommendedSessionMinutes {
                planSummaryChip("\(minutes) 分钟")
            }
            planSummaryChip((plan.equipmentPreference ?? .noPreference).displayName)
        }
    }

    private func planSummaryChip(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.accent.opacity(0.12))
            .cornerRadius(6)
    }

    private func planFocusSummary(_ plan: TrainingPlan) -> some View {
        let notes = Array(Set(plan.weeks.flatMap { $0.days.compactMap(\.note) }))
        return VStack(alignment: .leading, spacing: 4) {
            Text("本周期重点")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
            Text(notes.prefix(3).joined(separator: " "))
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(3)
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planWeekView(_ week: TrainingPlanWeek) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("第 \(week.weekIndex) 周")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)

            let trainingSessions = week.days.filter(\.isTrainingSession)
            let completed = trainingSessions.filter { $0.status == .completed }.count
            Text("完成 \(completed)/\(trainingSessions.count)")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)

            ForEach(trainingSessions) { day in
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("第 \(day.sequenceIndex ?? 1) 练 · \(day.title)")
                                .font(Theme.Fonts.body)
                                .foregroundColor(day.status == .rest ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                            planSummaryChip(strategyLabel(for: day))
                        }
                        if !day.suggestedExerciseNames.isEmpty {
                            Text(day.suggestedExerciseNames.prefix(4).joined(separator: " / "))
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                                .lineLimit(1)
                        }
                        if let note = day.note {
                            Text(note)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("标记完成") { viewModel.updatePlanDay(day, status: .completed) }
                        Button("跳过") { viewModel.updatePlanDay(day, status: .skipped) }
                        Button("调整") { viewModel.updatePlanDay(day, status: .moved) }
                        Button("计划中") { viewModel.updatePlanDay(day, status: .planned) }
                    } label: {
                        Text(day.status.displayName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(color(for: day.status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color(for: day.status).opacity(0.12))
                            .cornerRadius(6)
                    }
                    .disabled(day.status == .rest)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private func displayName(for muscle: Muscle) -> String {
        switch muscle {
        case .abs, .upperAbs, .lowerAbs: return "腹肌"
        case .biceps: return "肱二头肌"
        case .calves: return "小腿"
        case .chest, .upperChest, .lowerChest: return "胸部"
        case .deltoids, .frontDeltoid, .rearDeltoid: return "肩部"
        case .forearm: return "前臂"
        case .gluteal: return "臀部"
        case .hamstring: return "腘绳肌"
        case .lowerBack: return "下背部"
        case .obliques: return "腹斜肌"
        case .quadriceps, .innerQuad, .outerQuad: return "股四头肌"
        case .trapezius, .upperTrapezius, .lowerTrapezius: return "斜方肌"
        case .triceps: return "肱三头肌"
        case .upperBack, .rhomboids: return "上背部"
        case .adductors: return "内收肌"
        case .hipFlexors: return "髋屈肌"
        default: return muscle.rawValue
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E M/d"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        return formatter.string(from: date)
    }

    private func color(for status: TrainingPlanDayStatus) -> Color {
        switch status {
        case .completed: return Theme.Colors.success
        case .skipped: return Theme.Colors.error
        case .moved: return Theme.Colors.warning
        case .rest: return Theme.Colors.textMuted
        case .planned: return Theme.Colors.accent
        }
    }

    private func strategyLabel(for day: TrainingPlanDay) -> String {
        guard let note = day.note else { return "计划" }
        if note.contains("适应") { return "适应" }
        if note.contains("容量") { return "容量" }
        if note.contains("强度") { return "强度" }
        if note.contains("Deload") || note.contains("deload") { return "Deload" }
        return "计划"
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

#Preview {
    StatsView()
}
