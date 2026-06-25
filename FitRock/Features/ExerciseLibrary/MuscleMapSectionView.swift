import SwiftUI

/// Unified muscle group selection section.
/// On iOS 17+, uses the interactive MuscleMap body diagram.
/// On iOS 16, falls back to simple body part buttons.
struct MuscleMapSectionView: View {
    @Binding var selectedBodyPart: BodyPart?

    var body: some View {
        if #available(iOS 17.0, *) {
            MuscleMapInteractiveView(selectedBodyPart: $selectedBodyPart)
        } else {
            MuscleMapFallbackView(selectedBodyPart: $selectedBodyPart)
        }
    }
}

@available(iOS 17.0, *)
private struct MuscleMapInteractiveView: View {
    @Binding var selectedBodyPart: BodyPart?
    @State private var showBack = false

    private var displayedName: String {
        MuscleGroupMapper.displayName(for: selectedBodyPart)
    }

    private var highlightColor: Color {
        guard let bp = selectedBodyPart else { return .clear }
        return bp.themeColor
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Top row: prompt + front/back toggle
            HStack {
                Text("点击人体部位筛选动作")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBack.toggle()
                    }
                } label: {
                    Image(systemName: showBack ? "figure.stand" : "figure.stand.dress")
                        .font(.body)
                        .foregroundColor(Theme.Colors.accent)
                    Text(showBack ? "正面" : "背面")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, 4)

            // Body diagram with highlights
            let bodyView = BodyView(gender: .male, side: showBack ? .back : .front)
                .onMuscleSelected { muscle, _ in
                    if let bp = MuscleGroupMapper.bodyPart(for: muscle) {
                        if selectedBodyPart == bp {
                            selectedBodyPart = nil
                        } else {
                            selectedBodyPart = bp
                        }
                    }
                }

            if let bp = selectedBodyPart {
                bodyView
                    .highlight(MuscleGroupMapper.muscles(for: bp), color: bp.themeColor, opacity: 0.85)
                    .frame(height: 320)
                    .padding(.horizontal, 8)
            } else {
                bodyView
                    .frame(height: 320)
                    .padding(.horizontal, 8)
            }

            // Selection display row
            HStack {
                // Selected body part name
                Text(displayedName)
                    .font(Theme.Fonts.headline)
                    .foregroundColor(selectedBodyPart != nil ? highlightColor : Theme.Colors.textMuted)

                Spacer()

                // Clear button (only visible when something is selected)
                if selectedBodyPart != nil {
                    Button {
                        selectedBodyPart = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                            Text("清除")
                                .font(Theme.Fonts.caption)
                        }
                        .foregroundColor(Theme.Colors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}
