import AppKit

/// Detects rapid horizontal mouse "shaking" (3+ direction reversals within 0.5s
/// covering sufficient distance) and fires `onShakeDetected`.
final class ShakeDetector {
    var onShakeDetected: (() -> Void)?

    private var monitor: Any?
    private var samples: [(x: CGFloat, time: TimeInterval)] = []

    private let timeWindow: TimeInterval = 0.5
    private let minReversals = 3
    private let minTotalDistance: CGFloat = 200

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        samples.removeAll()
    }

    private func handleMouseMove(_ event: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        let x = event.locationInWindow.x

        samples.append((x: x, time: now))

        // Trim samples outside the time window
        samples.removeAll { now - $0.time > timeWindow }

        guard samples.count >= 4 else { return }

        // Count horizontal direction reversals and total distance
        var reversals = 0
        var totalDistance: CGFloat = 0
        var lastDelta: CGFloat = 0

        for i in 1..<samples.count {
            let delta = samples[i].x - samples[i - 1].x
            totalDistance += abs(delta)

            if lastDelta != 0 && delta != 0 {
                // A reversal is when the sign flips
                if (lastDelta > 0 && delta < 0) || (lastDelta < 0 && delta > 0) {
                    reversals += 1
                }
            }
            if delta != 0 {
                lastDelta = delta
            }
        }

        if reversals >= minReversals && totalDistance >= minTotalDistance {
            samples.removeAll()
            onShakeDetected?()
        }
    }
}
