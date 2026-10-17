import AppKit
import Foundation

@main
enum PoxiDropMain {
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshot"), arguments.count > index + 1 {
            MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: arguments[index + 1])) }
            exit(0)
        }
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}
