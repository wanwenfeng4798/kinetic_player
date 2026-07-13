import UIKit
import SgNativePlayerBridge

protocol SgPlayerCallbacks: AnyObject {
    func onPlayerStateChanged(_ state: CommonPlayerState)
    func onPositionChanged(positionMs: Int64, durationMs: Int64)
}

/// SGPlayer master bridge (libobjc/SGPlayer).
final class SgNativePlayer: NSObject {
    private let bridge: SgNativePlayerBridge
    private weak var callbacks: SgPlayerCallbacks?
    private let transformHost = SgTransformHostView()
    private var renderRotationDegrees = 0
    private var mirrorHorizontal = false
    private var mirrorVertical = false

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

        let renderView = bridge.view
        renderView.translatesAutoresizingMaskIntoConstraints = false
        transformHost.contentView.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: transformHost.contentView.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: transformHost.contentView.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: transformHost.contentView.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: transformHost.contentView.bottomAnchor),
        ])
    }

    var view: UIView { transformHost }

    func play() {
        bridge.play()
    }

    func pause() {
        bridge.pause()
    }

    func stop() {
        bridge.stop()
    }

    func seek(positionMs: Int) {
        bridge.seek(toMs: positionMs)
    }

    func setRate(_ rate: Double) {
        bridge.setRate(rate)
    }

    func setVolume(_ volume: Double) {
        bridge.setVolume(volume)
    }

    func setMute(_ muted: Bool) {
        bridge.setMuted(muted)
    }

    func switchVideoSource(_ urlString: String, autoPlay: Bool) {
        bridge.switchVideoSource(urlString, autoPlay: autoPlay)
    }

    func getAudioTracks() -> [[String: Any]] {
        bridge.getAudioTracks() as? [[String: Any]] ?? []
    }

    func selectAudioTrack(_ index: Int) -> Bool {
        bridge.selectAudioTrack(index)
    }

    func getVideoSize() -> [String: Int]? {
        guard let map = bridge.getVideoSize() as? [String: NSNumber] else { return nil }
        let width = map["width"]?.intValue ?? 0
        let height = map["height"]?.intValue ?? 0
        guard width > 0, height > 0 else { return nil }
        return ["width": width, "height": height]
    }

    func setLooping(_ looping: Bool) {
        bridge.setLooping(looping)
    }

    func captureFrame() -> String? {
        bridge.captureFrame()
    }

    func currentVolume() -> Double {
        bridge.currentVolume()
    }

    func isMuted() -> Bool {
        bridge.isMuted()
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

    /// Rotate the rendered video (0 / 90 / 180 / 270). Chrome overlay is unaffected.
    func setRenderRotation(degrees: Int) {
        let normalized = ((degrees % 360) + 360) % 360
        renderRotationDegrees = normalized
        applyRenderTransform()
    }

    /// Horizontal (left-right) mirror of the rendered video.
    func setMirrorHorizontal(enabled: Bool) {
        mirrorHorizontal = enabled
        applyRenderTransform()
    }

    /// Vertical (up-down) mirror of the rendered video.
    func setMirrorVertical(enabled: Bool) {
        mirrorVertical = enabled
        applyRenderTransform()
    }

    func applyRenderTransform() {
        transformHost.setRenderTransform(
            rotationDegrees: renderRotationDegrees,
            mirrorHorizontal: mirrorHorizontal,
            mirrorVertical: mirrorVertical,
        )
    }

    func release() {
        transformHost.setRenderTransform(
            rotationDegrees: 0,
            mirrorHorizontal: false,
            mirrorVertical: false,
        )
        bridge.releasePlayer()
    }
}

private extension CommonPlayerState {
    static var allCases: [CommonPlayerState] {
        [.idle, .buffering, .ready, .playing, .paused, .completed, .error]
    }
}
