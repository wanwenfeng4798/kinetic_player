import Foundation

enum PlayerConstants {
    static let sgViewType = "com.example.player/sg_view_ui"

    static func sgChannelName(viewId: Int) -> String {
        "com.example.player/sg_\(viewId)"
    }
}

enum CommonPlayerState: Int {
    case idle = 0
    case buffering = 1
    case ready = 2
    case playing = 3
    case paused = 4
    case completed = 5
    case error = 6
}

final class ThrottledProgressReporter {
    private let minIntervalMs: TimeInterval
    private let emit: (_ positionMs: Int64, _ durationMs: Int64) -> Void
    private var lastEmitMs: TimeInterval = 0

    init(minIntervalMs: TimeInterval = 250, emit: @escaping (_ positionMs: Int64, _ durationMs: Int64) -> Void) {
        self.minIntervalMs = minIntervalMs
        self.emit = emit
    }

    func report(positionMs: Int64, durationMs: Int64, force: Bool = false) {
        let now = Date().timeIntervalSince1970 * 1000
        if force || now - lastEmitMs >= minIntervalMs {
            lastEmitMs = now
            emit(positionMs, durationMs)
        }
    }

    func reset() {
        lastEmitMs = 0
    }
}
