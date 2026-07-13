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
    /// Host that receives rotate/mirror transforms. The SGPlayer render target
    /// stays untransformed inside so Metal drawing is not distorted.
    private let transformHost = UIView()
    private var renderRotationDegrees = 0
    private var mirrorHorizontal = false
    private var mirrorVertical = false
    private var boundsObservation: NSKeyValueObservation?

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

        transformHost.backgroundColor = .black
        transformHost.clipsToBounds = true
        let renderView = bridge.view
        renderView.translatesAutoresizingMaskIntoConstraints = false
        transformHost.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: transformHost.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: transformHost.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: transformHost.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: transformHost.bottomAnchor),
        ])

        boundsObservation = transformHost.observe(\.bounds, options: [.new]) { [weak self] _, _ in
            self?.applyRenderTransform()
        }
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
        let bounds = transformHost.bounds
        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else {
            transformHost.transform = .identity
            return
        }

        // Build around the view center (UIView.transform default anchor).
        let sx: CGFloat = mirrorHorizontal ? -1 : 1
        let sy: CGFloat = mirrorVertical ? -1 : 1
        var transform = CGAffineTransform(scaleX: sx, y: sy)
        if renderRotationDegrees != 0 {
            let radians = CGFloat(renderRotationDegrees) * .pi / 180
            transform = transform.rotated(by: radians)
        }
        // 90/270: cover the host so the picture stays centered and fills.
        if renderRotationDegrees % 180 != 0 {
            let fillScale = max(w / h, h / w)
            transform = transform.scaledBy(x: fillScale, y: fillScale)
        }
        transformHost.transform = transform
    }

    func release() {
        boundsObservation?.invalidate()
        boundsObservation = nil
        transformHost.transform = .identity
        bridge.releasePlayer()
    }
}

private extension CommonPlayerState {
    static var allCases: [CommonPlayerState] {
        [.idle, .buffering, .ready, .playing, .paused, .completed, .error]
    }
}
