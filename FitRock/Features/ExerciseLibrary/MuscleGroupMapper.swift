import Foundation

/// Maps MuscleMap's Muscle enum values to FitRock's BodyPart.
enum MuscleGroupMapper {
    /// Maps a MuscleMap Muscle to the corresponding FitRock BodyPart.
    static func bodyPart(for muscle: Muscle) -> BodyPart? {
        switch muscle {
        case .chest, .upperChest, .lowerChest:
            return .chest
        case .upperBack, .lowerBack, .trapezius, .upperTrapezius, .lowerTrapezius, .rhomboids:
            return .back
        case .deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff:
            return .shoulders
        case .biceps, .triceps, .forearm:
            return .arms
        case .quadriceps, .hamstring, .gluteal, .calves, .innerQuad, .outerQuad, .adductors, .tibialis:
            return .legs
        case .abs, .obliques, .upperAbs, .lowerAbs, .serratus:
            return .core
        default:
            return nil
        }
    }

    /// Chinese display name for each body part.
    static func displayName(for bodyPart: BodyPart?) -> String {
        guard let bodyPart else { return "全部" }
        switch bodyPart {
        case .chest: return "胸部"
        case .back: return "背部"
        case .shoulders: return "肩部"
        case .arms: return "手臂"
        case .legs: return "腿部"
        case .core: return "核心"
        default: return "全部"
        }
    }

    /// All MuscleMap muscles belonging to a given BodyPart (for highlighting).
    static func muscles(for bodyPart: BodyPart) -> [Muscle] {
        switch bodyPart {
        case .chest:
            return [.chest, .upperChest, .lowerChest]
        case .back:
            return [.upperBack, .lowerBack, .trapezius, .upperTrapezius, .lowerTrapezius, .rhomboids]
        case .shoulders:
            return [.deltoids, .frontDeltoid, .rearDeltoid]
        case .arms:
            return [.biceps, .triceps, .forearm]
        case .legs:
            return [.quadriceps, .hamstring, .gluteal, .calves, .innerQuad, .outerQuad, .adductors, .tibialis]
        case .core:
            return [.abs, .obliques, .upperAbs, .lowerAbs, .serratus]
        default:
            return []
        }
    }
}
