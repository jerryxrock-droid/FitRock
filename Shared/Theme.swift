import SwiftUI

enum Theme {
    enum Colors {
        static let accent = Color(hex: "FF5722")
        static let accentLight = Color(hex: "FF8A65")
        static let background = Color(hex: "121212")
        static let surface = Color(hex: "1E1E1E")
        static let surface2 = Color(hex: "242424")
        static let surface3 = Color(hex: "2A2A2A")
        static let textPrimary = Color(hex: "F0ECE4")
        static let textSecondary = Color(hex: "8A8580")
        static let textMuted = Color(hex: "5A5550")
        static let divider = Color(hex: "2A2A2A")
        static let success = Color(hex: "4CAF50")
        static let warning = Color(hex: "FF9800")
        static let error = Color(hex: "F44336")

        static let chest = Color(hex: "FF5722")
        static let back = Color(hex: "2196F3")
        static let shoulders = Color(hex: "FF9800")
        static let arms = Color(hex: "9C27B0")
        static let legs = Color(hex: "4CAF50")
        static let core = Color(hex: "FFC107")
        static let cardio = Color(hex: "9E9E9E")
    }

    enum Fonts {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let mono = Font.system(size: 16, weight: .medium, design: .monospaced)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

extension BodyPart {
    var themeColor: Color {
        switch self {
        case .chest: return Theme.Colors.chest
        case .back: return Theme.Colors.back
        case .shoulders: return Theme.Colors.shoulders
        case .arms: return Theme.Colors.arms
        case .legs: return Theme.Colors.legs
        case .core: return Theme.Colors.core
        case .cardio: return Theme.Colors.cardio
        }
    }

    var displayName: String {
        switch self {
        case .chest: return "胸部"
        case .back: return "背部"
        case .shoulders: return "肩部"
        case .arms: return "手臂"
        case .legs: return "腿部"
        case .core: return "核心"
        case .cardio: return "有氧"
        }
    }
}
