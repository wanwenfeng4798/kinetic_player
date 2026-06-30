import UIKit

protocol SgPlayerCallbacks: AnyObject {
    func onPlayerStateChanged(_ state: CommonPlayerState)
    func onPositionChanged(positionMs: Int64, durationMs: Int64)
}

/// SGPlayer master bridge (libobjc/SGPlayer).
final class SgNativePlayer: NSObject {
    private let bridge: SgNativePlayerBridge
    private weak var callbacks: SgPlayerCallbacks?

    init(callbacks: SgPlayerCallbacks) {
        self.callbacks = callbacks
        bridge = SgNativePlayerBridge(
            stateHandler: { [weak callbacks] stateIndex in
                guard let callbacks,
                      stateIndex >= 0,
                      stateIndex < CommonPlayerState.allCases.count else { return }
                callbacks.onPlayerStateChanged(CommonPlayerState.allCases[stateIndex])
            },
            progressHandler: { [weak callbacks] positionMs, durationMs in
                callbacks?.onPositionChanged(positionMs: positionMs, durationMs: durationMs)
            },
        )
        super.init()
    }

    var view: UIView { bridge.view }

    func setUrl(_ urlString: String) {
        bridge.setUrl(urlString)
    }

    func play() {
        bridge.play()
    }

    func pause() {
        bridge.pause()
    }

    func seek(positionMs: Int) {
        bridge.seek(toMs: positionMs)
    }

    func setRenderMode(_ mode: Int) {
        bridge.setRenderMode(mode)
    }

    func setSgVRMode(enabled: Bool) {
        bridge.setVrModeEnabled(enabled)
    }

    func setSyncGroupId(_ id: String) {
        bridge.setSyncGroupId(id)
    }

    func release() {
        bridge.releasePlayer()
    }
}

private extension CommonPlayerState {
    static var allCases: [CommonPlayerState] {
        [.idle, .buffering, .ready, .playing, .paused, .completed, .error]
    }
}
