import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var showDeleteAlert = false
    @State private var workoutToDelete: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    periodPicker
                    overviewCards
                    personalRecordsSection
                    bodyPartChart
                    exerciseRanking
                    workoutHistory
                }
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
                }
            }
        }
        .onAppear {
            viewModel.loadStats(for: selectedPeriod)
        }
        .onChange(of: selectedPeriod) { newValue in
            viewModel.loadStats(for: newValue)
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let workout = workoutToDelete {
                    viewModel.deleteWorkout(workout.id)
                }
            }
        } message: {
            Text("确定要删除这次训练记录吗？")
        }
    }

    private var periodPicker: some View {
        Picker("时间范围", selection: $selectedPeriod) {
            ForEach(StatsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            StatsCard(title: "训练次数", value: "\(viewModel.workoutCount)", icon: "figure.run")
            StatsCard(title: "平均单次", value: String(format: "%.1f", viewModel.workoutCount > 0 ? viewModel.totalVolume / Double(viewModel.workoutCount) / 1000 : 0.0) + "T", icon: "scalemass")
            StatsCard(title: "总时长", value: viewModel.formattedTotalDuration, icon: "clock")
            StatsCard(title: "总组数", value: "\(viewModel.totalSets)", icon: "number")
        }
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
                            }
                            if !pr.detailText.isEmpty {
                                Text(pr.detailText)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                        }
                        Spacer()
                        Text(pr.formattedValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    if pr.id != bestRecords.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var bodyPartChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("部位分布")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            if viewModel.bodyPartData.isEmpty {
                Text("暂无数据")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                PieChartView(data: viewModel.bodyPartData)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var exerciseRanking: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("动作排行榜")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            if viewModel.exerciseRanking.isEmpty {
                Text("暂无数据")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
            } else {
                ForEach(Array(viewModel.exerciseRanking.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text("\(index + 1)")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                            .frame(width: 20)
                        Text(item.name)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(item.volume))kg")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    if index < viewModel.exerciseRanking.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var workoutHistory: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("训练历史")
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            if viewModel.workouts.isEmpty {
                Text("暂无数据")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textMuted)
            } else {
                ForEach(viewModel.workouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack {
                                Text(workout.formattedDate)
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text(workout.formattedDuration)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.surface2)
                        .cornerRadius(Theme.CornerRadius.small)

                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(Theme.Colors.error.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                workoutToDelete = workout
                                showDeleteAlert = true
                            }
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
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

// MARK: - PieChartView
struct PieChartView: View {
    let data: [BodyPartStat]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.45

            ZStack {
                // Pie slices
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    PieSlice(startAngle: slice.startAngle, endAngle: slice.endAngle)
                        .fill(data[index].bodyPart.themeColor)
                }

                // Center circle (donut hole)
                Circle()
                    .fill(Theme.Colors.background)
                    .frame(width: radius * 1.2, height: radius * 1.2)

                // Labels outside slices
                ForEach(Array(sliceMidAngles.enumerated()), id: \.offset) { index, midAngle in
                    let labelRadius = radius * 1.6
                    let x = center.x + labelRadius * cos(CGFloat(midAngle) * .pi / 180)
                    let y = center.y + labelRadius * sin(CGFloat(midAngle) * .pi / 180)

                    if data[index].percentage >= 8 {
                        VStack(spacing: 1) {
                            Text(data[index].bodyPart.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("\(Int(data[index].percentage))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(data[index].bodyPart.themeColor)
                        }
                        .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private var sliceMidAngles: [Double] {
        slices.map { ($0.startAngle.degrees + $0.endAngle.degrees) / 2 }
    }

    private var slices: [(startAngle: Angle, endAngle: Angle)] {
        var result: [(startAngle: Angle, endAngle: Angle)] = []
        let total = data.reduce(0) { $0 + $1.volume }
        var currentAngle: Double = -90

        for item in data {
            let percentage = total > 0 ? item.volume / total : 0
            let angleSize = percentage * 360
            result.append((
                startAngle: Angle(degrees: currentAngle),
                endAngle: Angle(degrees: currentAngle + angleSize)
            ))
            currentAngle += angleSize
        }

        return result
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}
