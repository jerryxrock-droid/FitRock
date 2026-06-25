import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var viewModel = ExerciseLibraryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    MuscleMapSectionView(selectedBodyPart: $viewModel.selectedBodyPart)
                        .padding(.horizontal)
                        .padding(.top, Theme.Spacing.sm)

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
                    } else if viewModel.filteredExercises.isEmpty {
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
            .navigationTitle("动作库")
            .searchable(text: $viewModel.searchText, prompt: "搜索动作名称")
        }
        .onAppear {
            viewModel.loadExercises()
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.filteredExercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise, viewModel: viewModel)) {
                        exerciseCard(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    Label(exercise.bodyPart.displayName, systemImage: "circle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(exercise.bodyPart.themeColor)
                        .labelStyle(.titleOnly)

                    Text(exercise.unit.displayName)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textMuted)

                    if exercise.isUserCreated {
                        Text("自定义")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.accent.opacity(0.2))
                            .cornerRadius(4)
                    }
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
}
