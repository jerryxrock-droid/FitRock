import SwiftUI
import UIKit

/// Loads an exercise image from Bundle (device) or local filesystem (dev).
struct AsyncExerciseImageView: View {
    let imagePath: String

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    /// imagePath is like "Wide-Grip_Lat_Pulldown/0.jpg"
    private var subdirectory: String {
        let parts = imagePath.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return "" }
        return "ExerciseImages/\(parts[0])"
    }

    private var filename: String {
        let parts = imagePath.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return imagePath }
        return String(parts[1])
    }

    private var extensionName: String {
        (filename as NSString).pathExtension
    }

    private var basename: String {
        ((filename as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Theme.Colors.surface2
                    ProgressView()
                        .tint(Theme.Colors.accent)
                }
            } else if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: 280, height: 200)
        .clipped()
        .cornerRadius(Theme.CornerRadius.small)
        .task(priority: .background) {
            let loaded = await Task(priority: .background) { () -> UIImage? in
                // 1. Try Bundle (device production builds)
                if let url = Bundle.main.url(forResource: basename, withExtension: extensionName, subdirectory: subdirectory) {
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                }
                // 2. Fallback: local filesystem (simulator development)
                let base = "/Users/jerry/IOS_App/FitRock/FitRock/free-exercise-db-main/exercises"
                let url = URL(fileURLWithPath: "\(base)/\(imagePath)")
                return UIImage(contentsOfFile: url.path)
            }.value
            await MainActor.run {
                uiImage = loaded
                isLoading = false
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.Colors.surface2
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.textMuted)
                Text("暂无图片")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
