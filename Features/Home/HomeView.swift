import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    statCards
                    calendarSection
                    selectedDateWorkouts
                }
                .padding()
            }
            .background(Theme.Colors.background)
            .navigationTitle("FitRock")
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
            viewModel.loadData(for: displayedMonth)
        }
    }

    private var statCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(title: "本月训练", value: "\(viewModel.monthWorkoutCount)", icon: "figure.run")
            StatCard(title: "连续打卡", value: "\(viewModel.streakDays)", icon: "flame")
            StatCard(title: "平均单次", value: String(format: "%.1f", viewModel.monthWorkoutCount > 0 ? viewModel.monthVolume / Double(viewModel.monthWorkoutCount) / 1000 : 0.0) + "T", icon: "scalemass")
        }
    }

    private var calendarSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.Colors.accent)
                }
                Spacer()
                Text(monthYearString)
                    .font(Theme.Fonts.headline)
                Spacer()
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isToday: Calendar.current.isDateInToday(date),
                            isSelected: selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!),
                            hasWorkout: viewModel.hasWorkout(on: date),
                            onTap: {
                                if selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!) {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                                viewModel.selectDate(date)
                            }
                        )
                    } else {
                        Color.clear.id("placeholder-" + String(index))
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    @ViewBuilder
    private var selectedDateWorkouts: some View {
        if let selected = selectedDate {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("\(formatDate(selected))的训练")
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                if viewModel.selectedDateWorkouts.isEmpty {
                    EmptyStateView(
                        icon: "figure.run",
                        title: "暂无训练记录",
                        message: "开始第一次训练吧！"
                    )
                } else {
                    ForEach(viewModel.selectedDateWorkouts) { workout in
                        WorkoutSummaryCard(workout: workout)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.medium)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: selectedDate)
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        var days: [Date?] = []
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
            selectedDate = nil
            viewModel.loadData(for: newMonth)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.accent)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

struct CalendarDayView: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasWorkout: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 选中背景
                if isSelected {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.3))
                }

                // 有训练时橙色圆圈
                if hasWorkout {
                    Circle()
                        .stroke(Theme.Colors.accent, lineWidth: 2)
                }

                // 今日标记（无训练时）
                if isToday && !isSelected && !hasWorkout {
                    Circle()
                        .stroke(Theme.Colors.accent, lineWidth: 2)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(Theme.Fonts.body)
                    .foregroundColor(isSelected ? .white : (isToday ? Theme.Colors.accent : Theme.Colors.textPrimary))
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutSummaryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(workout.formattedDate)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text(workout.formattedDuration)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Text(formatExerciseList())
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .lineLimit(2)

            HStack(spacing: Theme.Spacing.md) {
                Label(String(format: "%.1f", Double(workout.totalVolume) / 1000) + "T", systemImage: "scalemass")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Label("\(workout.totalSets)组", systemImage: "number")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding()
        .background(Theme.Colors.surface2)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private func formatExerciseList() -> String {
        let names = workout.exercises.prefix(4).map { $0.exerciseName }
        let result = names.joined(separator: " · ")
        if workout.exercises.count > 4 {
            return result + " ..."
        }
        return result
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.textMuted)
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

#Preview {
    HomeView()
}
