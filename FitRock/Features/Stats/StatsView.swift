import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedPeriod: StatsPeriod = .week

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
            StatsCard(title: "总容量", value: "\(Int(viewModel.totalVolume))t", icon: "scalemass")
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
                ForEach(viewModel.personalRecords) { pr in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(pr.date)
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                        Spacer()
                        Text("\(String(format: "%.1f", pr.maxWeight))kg")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    if pr.id != viewModel.personalRecords.last?.id {
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
                if #available(iOS 17.0, *) {
                    Chart(viewModel.bodyPartData, id: \.bodyPart) { item in
                        SectorMark(
                            angle: .value("容量", item.volume),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(item.bodyPart.themeColor)
                    }
                    .frame(height: 200)
                } else {
                    HStack(spacing: 4) {
                        ForEach(viewModel.bodyPartData.prefix(7)) { item in
                            Rectangle()
                                .fill(item.bodyPart.themeColor)
                                .frame(height: CGFloat(item.percentage) * 1.5)
                        }
                    }
                    .frame(height: 150)
                }

                ForEach(viewModel.bodyPartData, id: \.bodyPart) { item in
                    HStack {
                        Circle()
                            .fill(item.bodyPart.themeColor)
                            .frame(width: 12, height: 12)
                        Text(item.bodyPart.displayName)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(item.percentage))%")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
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
                    .background(Theme.Colors.surface2)
                    .cornerRadius(Theme.CornerRadius.small)
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
