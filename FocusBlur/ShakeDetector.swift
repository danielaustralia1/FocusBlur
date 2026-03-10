import AppKit

/// Detects rapid horizontal mouse "shaking" and fires `onShakeDetected`.
///
/// Sensitivity is configurable from 1.0 (hard to trigger) to 3.0 (easy to trigger).
/// Uses a cooldown after each detection to prevent the tail end of the shake
/// gesture from immediately re-triggering.
final class ShakeDetector {
    var onShakeDetected: (() -> Void)?

    private var monitor: Any?
    private var samples: [(x: CGFloat, time: TimeInterval)] = []
    private var lastShakeTime: TimeInterval = 0

    /// Update detection parameters based on sensitivity (1.0–3.0).
    /// Lower sensitivity = stricter thresholds (harder to trigger).
    var sensitivity: Double = 2.0 {
        didSet { sensitivity = max(1.0, min(3.0, sensitivity)) }
    }

    // Derived thresholds from sensitivity
    private var timeWindow: TimeInterval {
        // Low=0.4s, Medium=0.6s, High=0.8s
        0.2 + sensitivity * 0.2
    }

    private var minReversals: Int {
        // Low=5, Medium=4, High=3
        Int(6.0 - sensitivity)
    }

    private var minTotalDistance: CGFloat {
        // Low=350, Medium=250, High=150
        CGFloat(450.0 - sensitivity * 100.0)
    }

    private var cooldown: TimeInterval {
        // Low=2.5s, Medium=2.0s, High=1.5s
        3.0 - sensitivity * 0.5
    }

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

        // Ignore mouse events during cooldown
        if now - lastShakeTime < cooldown { return }

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
                if (lastDelta > 0 && delta < 0) || (lastDelta < 0 && delta > 0) {
                    reversals += 1
                }
            }
            if delta != 0 {
                lastDelta = delta
            }
        }

        if reversals >= minReversals && totalDistance >= minTotalDistance {
            lastShakeTime = now
            samples.removeAll()
            onShakeDetected?()
        }
    }
}
