import CoreGraphics

/// Detecta el gesto de agitar el ratón: varios cambios de dirección horizontal seguidos y rápidos.
public struct ShakeDetector: Sendable {
    public struct Settings: Equatable, Sendable {
        /// Cambios de dirección necesarios.
        public var reversals: Int
        /// Recorrido mínimo de cada tramo, en puntos.
        public var minSegment: CGFloat
        /// Segundos en los que tienen que caber todos los cambios.
        public var window: Double

        public init(reversals: Int, minSegment: CGFloat, window: Double) {
            self.reversals = reversals
            self.minSegment = minSegment
            self.window = window
        }

        /// 0 = baja, 1 = media, 2 = alta.
        public static func sensitivity(_ level: Int) -> Settings {
            switch level {
            case ..<1: return Settings(reversals: 4, minSegment: 60, window: 0.9)
            case 1: return Settings(reversals: 3, minSegment: 40, window: 0.8)
            default: return Settings(reversals: 2, minSegment: 30, window: 0.6)
            }
        }
    }

    public var settings: Settings
    private var lastX: CGFloat?
    private var direction: CGFloat = 0
    private var segmentStart: CGFloat = 0
    private var reversalTimes: [Double] = []

    public init(settings: Settings = .sensitivity(1)) {
        self.settings = settings
    }

    public mutating func reset() {
        lastX = nil
        direction = 0
        reversalTimes = []
    }

    /// Añade una posición horizontal del cursor. Devuelve `true` justo cuando se completa un agitado.
    public mutating func add(x: CGFloat, time: Double) -> Bool {
        guard let previous = lastX else {
            lastX = x
            segmentStart = x
            return false
        }
        let dx = x - previous
        guard abs(dx) >= 1 else { return false }
        lastX = x

        let newDirection: CGFloat = dx > 0 ? 1 : -1
        if direction == 0 {
            direction = newDirection
        } else if newDirection != direction {
            if abs(previous - segmentStart) >= settings.minSegment {
                reversalTimes.append(time)
            }
            direction = newDirection
            segmentStart = previous
        }

        reversalTimes.removeAll { time - $0 > settings.window }
        guard reversalTimes.count >= settings.reversals else { return false }

        reversalTimes = []
        direction = 0
        segmentStart = x
        return true
    }
}
