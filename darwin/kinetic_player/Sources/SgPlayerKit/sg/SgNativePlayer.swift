#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SgNativePlayerBridge

protocol SgPlayerCallbacks: AnyObject {
    func onPlayerStateChanged(_ state: CommonPlayerState)
    func onPositionChanged(positionMs: Int64, durationMs: Int64, bufferedMs: Int64)
    func onNativeFeatureEvent(_ event: [AnyHashable: Any])
    func onPlayerError(message: String?, code: Int)
}

/// SGPlayer master bridge (wanwenfeng4798/SGPlayer).
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
            progressHandler: { [weak callbacks] positionMs, durationMs, bufferedMs in
                callbacks?.onPositionChanged(
                    positionMs: positionMs,
                    durationMs: durationMs,
                    bufferedMs: bufferedMs,
                )
            },
            errorHandler: { [weak callbacks] message, code in
                callbacks?.onPlayerError(message: message, code: Int(code))
            },
        )
        super.init()
        bridge.setFeatureEventHandler { [weak callbacks] event in
            callbacks?.onNativeFeatureEvent(event)
        }

#if SWIFT_PACKAGE
        let resourceBundle = Bundle.module
#else
        let hostBundle = Bundle(for: SgNativePlayer.self)
        let resourceBundle = hostBundle.url(forResource: "kinetic_player_sgplayer", withExtension: "bundle")
            .flatMap(Bundle.init(url:)) ?? hostBundle
#endif
        if let font = resourceBundle.url(forResource: "NotoSansCJKsc-Regular", withExtension: "otf", subdirectory: "SGPlayer/Fonts") {
            bridge.performOperation("effects.configure", arguments: ["subtitleFallbackFontURL": font.absoluteString]) { _, _ in }
        }
        let renderView = bridge.view
        renderView.translatesAutoresizingMaskIntoConstraints = false
        transformHost.contentView.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: transformHost.contentView.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: transformHost.contentView.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: transformHost.contentView.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: transformHost.contentView.bottomAnchor),
        ])
        bridge.setPresentationView(transformHost)
    }

#if os(iOS)
    var view: UIView { transformHost }
#elseif os(macOS)
    var view: NSView { transformHost }
#endif

    func configureControls(enabled: Bool, autoHide: Double, fullscreen: @escaping () -> Void) {
        bridge.configureControls(enabled, autoHide: autoHide, fullscreen: fullscreen)
    }

    func setPlaylist(_ urls: [String], startIndex: Int, autoPlay: Bool) -> Bool {
        bridge.setPlaylist(urls, start: startIndex, autoPlay: autoPlay)
    }
    func playNext() -> Bool { bridge.playNext() }
    func setAutomaticAdvance(_ enabled: Bool) { bridge.setAutomaticAdvance(enabled) }
    func diagnostics() -> [AnyHashable: Any] { bridge.diagnostics() }
    func startPictureInPicture() -> Bool { bridge.startPictureInPicture() }
    func stopPictureInPicture() { bridge.stopPictureInPicture() }
    func isPictureInPictureActive() -> Bool { bridge.isPictureInPictureActive() }

    func setDismissFullscreenHandler(_ handler: @escaping () -> Void) { bridge.setDismissFullscreenHandler(handler) }

    func setCoverUrl(_ url: String?) {
        bridge.performOperation("controls.cover", arguments: url.map { ["url": $0] } ?? [:]) { _, _ in }
    }

    func performOperation(_ operation: String, arguments: [String: Any], completion: @escaping (Any?, Error?) -> Void) {
        bridge.performOperation(operation, arguments: arguments, completion: completion)
    }

    func play() { bridge.play() }
    func pause() { bridge.pause() }
    func stop() { bridge.stop() }
    func seek(positionMs: Int) { bridge.seek(toMs: positionMs) }
    func setRate(_ rate: Double) { bridge.setRate(rate) }
    func setVolume(_ volume: Double) { bridge.setVolume(volume) }
    func setMute(_ muted: Bool) { bridge.setMuted(muted) }
    func setPitch(_ pitch: Double) { bridge.setPitch(pitch) }
    func currentPitch() -> Double { bridge.currentPitch() }

    func switchVideoSource(_ urlString: String, autoPlay: Bool) {
        bridge.switchVideoSource(urlString, autoPlay: autoPlay)
    }

    @discardableResult
    func replaceWithSegments(_ segments: [[String: Any]], autoPlay: Bool) -> Bool {
        bridge.replace(withSegments: segments, autoPlay: autoPlay)
    }

    func getAudioTracks() -> [[String: Any]] {
        bridge.getAudioTracks() as? [[String: Any]] ?? []
    }

    func selectAudioTrack(_ index: Int) -> Bool {
        bridge.selectAudioTrack(index)
    }

    func getVideoTracks() -> [[String: Any]] {
        bridge.getVideoTracks() as? [[String: Any]] ?? []
    }

    func selectVideoTrack(_ index: Int) -> Bool {
        bridge.selectVideoTrack(index)
    }

    func getVideoSize() -> [String: Int]? {
        guard let map = bridge.getVideoSize() as? [String: NSNumber] else { return nil }
        let width = map["width"]?.intValue ?? 0
        let height = map["height"]?.intValue ?? 0
        guard width > 0, height > 0 else { return nil }
        return ["width": width, "height": height]
    }

    func setLooping(_ looping: Bool) { bridge.setLooping(looping) }
    func captureFrame() -> Data? { bridge.captureFrame() }
    func currentVolume() -> Double { bridge.currentVolume() }
    func isMuted() -> Bool { bridge.isMuted() }
    func setRenderMode(_ mode: Int) { bridge.setRenderMode(mode) }

    func setDisplayMode(_ mode: Int) { bridge.setDisplayMode(mode) }
    func displayMode() -> Int { Int(bridge.displayMode()) }

    func setSgVRMode(enabled: Bool) { bridge.setVrModeEnabled(enabled) }

    func setVrViewport(_ viewport: [String: Any]) {
        bridge.setVrViewport(viewport)
    }

    func vrViewport() -> [String: Any] {
        bridge.vrViewport() as? [String: Any] ?? [:]
    }

    func setDemuxerOptions(_ options: [String: Any]) {
        bridge.setDemuxerOptions(options)
    }

    func setHttpRequestOptions(_ options: [String: Any]) {
        bridge.setHttpRequestOptions(options)
    }

    func setBackgroundPlaybackPolicy(_ policy: [String: Any]) {
        bridge.setBackgroundPlaybackPolicy(policy)
    }

    func backgroundPlaybackPolicy() -> [String: Any] {
        bridge.backgroundPlaybackPolicy() as? [String: Any] ?? [:]
    }

    func lastErrorMessage() -> String? { bridge.lastErrorMessage() }
    func lastErrorCode() -> Int { Int(bridge.lastErrorCode()) }
    func bufferedPositionMs() -> Int64 { bridge.bufferedPositionMs() }
    func isSeekable() -> Bool { bridge.isSeekable() }

    func setRenderRotation(degrees: Int) {
        let normalized = ((degrees % 360) + 360) % 360
        renderRotationDegrees = normalized
        applyRenderTransform()
    }

    func setMirrorHorizontal(enabled: Bool) {
        mirrorHorizontal = enabled
        applyRenderTransform()
    }

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
