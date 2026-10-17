import AppKit
import PoxiDropCore

/// Vigila los arrastres de todo el sistema y avisa cuando hay que abrir una estantería.
@MainActor
final class DragWatcher {
    enum Trigger {
        case shake, modifier, notch
    }

    var onTrigger: ((CGPoint, Trigger) -> Void)?
    var onDragEnded: (() -> Void)?

    private let settings: AppSettings
    private var monitor: Any?
    private var timer: Timer?
    private var detector = ShakeDetector()
    private var baselineChangeCount = 0
    private var dragging = false
    private var triggered = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.startPolling() }
        }
    }

    private func startPolling() {
        guard timer == nil else { return }
        baselineChangeCount = NSPasteboard(name: .drag).changeCount
        detector = ShakeDetector(settings: .sensitivity(settings.shakeSensitivity))
        dragging = false
        triggered = false
        // Hasta que empieza un arrastre con contenido basta con mirar 20 veces por segundo;
        // durante el arrastre se sube a 60 para detectar bien el agitado.
        schedule(every: 1.0 / 20)
    }

    private func schedule(every interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 == 1 else {
            stop()
            return
        }
        if !dragging {
            guard NSPasteboard(name: .drag).changeCount != baselineChangeCount else { return }
            dragging = true
            schedule(every: 1.0 / 60)
        }
        guard !triggered else { return }

        let point = NSEvent.mouseLocation
        let trigger: Trigger?
        if settings.modifierEnabled && NSEvent.modifierFlags.contains(settings.modifierKey.flag) {
            trigger = .modifier
        } else if settings.notchEnabled && NotchZone.contains(point) {
            trigger = .notch
        } else if settings.shakeEnabled && detector.add(x: point.x, time: ProcessInfo.processInfo.systemUptime) {
            trigger = .shake
        } else {
            trigger = nil
        }
        if let trigger {
            triggered = true
            onTrigger?(point, trigger)
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        if dragging { onDragEnded?() }
        dragging = false
    }
}
