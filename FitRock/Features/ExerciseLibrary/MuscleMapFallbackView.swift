import SwiftUI

/// Fallback view for iOS 16: simple horizontal body part buttons.
struct MuscleMapFallbackView: View {
    @Binding var selectedBodyPart: BodyPart?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Selected display name
            HStack {
                Text(MuscleGroupMapper.displayName(for: selectedBodyPart))
                    .font(Theme.Fonts.headline)
                    .foregroundColor(selectedBodyPart != nil ? selectedBodyPart!.themeColor : Theme.Colors.textMuted)

                Spacer()

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

            // Body part buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    bodyPartButton(title: "全部", bodyPart: nil, color: Theme.Colors.accent)
                    bodyPartButton(title: "胸", bodyPart: .chest, color: BodyPart.chest.themeColor)
                    bodyPartButton(title: "背", bodyPart: .back, color: BodyPart.back.themeColor)
                    bodyPartButton(title: "肩", bodyPart: .shoulders, color: BodyPart.shoulders.themeColor)
                    bodyPartButton(title: "手臂", bodyPart: .arms, color: BodyPart.arms.themeColor)
                    bodyPartButton(title: "腿", bodyPart: .legs, color: BodyPart.legs.themeColor)
                    bodyPartButton(title: "核心", bodyPart: .core, color: BodyPart.core.themeColor)
                }
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private func bodyPartButton(title: String, bodyPart: BodyPart?, color: Color) -> some View {
        Button {
            if selectedBodyPart == bodyPart {
                selectedBodyPart = nil
            } else {
                selectedBodyPart = bodyPart
            }
        } label: {
            Text(title)
                .font(Theme.Fonts.body)
                .fontWeight(selectedBodyPart == bodyPart ? .semibold : .regular)
                .foregroundColor(selectedBodyPart == bodyPart ? .white : color)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(selectedBodyPart == bodyPart ? color : color.opacity(0.15))
                .cornerRadius(20)
        }
    }
}
