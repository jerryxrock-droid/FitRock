import Foundation

protocol WorkoutTiming: AnyObject {
    var onTick: ((TimeInterval) -> Void)? { get set }
    func start(from startTime: Date)
    func stop()
}

final class WorkoutTimer: WorkoutTiming {
    var onTick: ((TimeInterval) -> Void)?

    private var timer: Timer?
    private var startTime: Date?

    func start(from startTime: Date) {
        stop()
        self.startTime = startTime
        onTick?(Date().timeIntervalSince(startTime))
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            self.onTick?(Date().timeIntervalSince(startTime))
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
}
