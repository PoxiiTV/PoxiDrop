import Testing
import CoreGraphics
@testable import PoxiDropCore

/// Trayectoria en zigzag entre 0 y `amplitude`, muestreada a 60 Hz.
func zigzag(amplitude: CGFloat, segments: Int, secondsPerSegment: Double) -> [(x: CGFloat, t: Double)] {
    let fps = 60.0
    let steps = max(1, Int(secondsPerSegment * fps))
    var points: [(x: CGFloat, t: Double)] = []
    var t = 0.0
    for segment in 0..<segments {
        let from: CGFloat = segment % 2 == 0 ? 0 : amplitude
        let to: CGFloat = segment % 2 == 0 ? amplitude : 0
        for step in 0..<steps {
            points.append((from + (to - from) * CGFloat(step) / CGFloat(steps), t))
            t += 1 / fps
        }
    }
    points.append((segments % 2 == 0 ? 0 : amplitude, t))
    return points
}

func detections(_ points: [(x: CGFloat, t: Double)], _ settings: ShakeDetector.Settings = .sensitivity(1)) -> Int {
    var detector = ShakeDetector(settings: settings)
    var count = 0
    for point in points where detector.add(x: point.x, time: point.t) {
        count += 1
    }
    return count
}

@Suite("Detector de agitado")
struct ShakeDetectorTests {
    @Test func agitadoRapidoSeDetectaUnaVez() {
        #expect(detections(zigzag(amplitude: 120, segments: 4, secondsPerSegment: 0.12)) == 1)
    }

    @Test func arrastreRectoNoEsAgitado() {
        let points = (0..<60).map { (x: CGFloat($0) * 10, t: Double($0) / 60) }
        #expect(detections(points) == 0)
    }

    @Test func agitadoLentoNoCuenta() {
        #expect(detections(zigzag(amplitude: 120, segments: 4, secondsPerSegment: 0.5)) == 0)
    }

    @Test func temblorPequenoNoCuenta() {
        #expect(detections(zigzag(amplitude: 12, segments: 8, secondsPerSegment: 0.05)) == 0)
    }

    @Test func sensibilidadAltaNecesitaMenos() {
        let corto = zigzag(amplitude: 80, segments: 3, secondsPerSegment: 0.1)
        #expect(detections(corto, .sensitivity(1)) == 0)
        #expect(detections(corto, .sensitivity(2)) == 1)
    }

    @Test func sensibilidadBajaNecesitaMas() {
        #expect(detections(zigzag(amplitude: 120, segments: 4, secondsPerSegment: 0.12), .sensitivity(0)) == 0)
        #expect(detections(zigzag(amplitude: 120, segments: 5, secondsPerSegment: 0.12), .sensitivity(0)) == 1)
    }

    @Test func reiniciarOlvidaLoAnterior() {
        var detector = ShakeDetector()
        for point in zigzag(amplitude: 120, segments: 3, secondsPerSegment: 0.12) {
            _ = detector.add(x: point.x, time: point.t)
        }
        detector.reset()
        #expect(detector.add(x: 0, time: 1) == false)
        #expect(detector.add(x: 120, time: 1.1) == false)
    }
}
