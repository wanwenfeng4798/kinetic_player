import Flutter
import UIKit

final class SgVideoPlatformView: NSObject, FlutterPlatformView, SgPlayerChromeDelegate {
    private let container = UIView()
    private let player: SgNativePlayer
    private let channel: FlutterMethodChannel
    private let chrome: SgPlayerChromeView
    private let fullscreenPresenter = SgFullscreenPresenter()
    private let channelCallbacks: SgChannelCallbacks
    private var isPlaying = false

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: Any?,
    ) {
        let params = args as? [String: Any]
        let uiConfig = SgUiConfig.fromCreationParams(params)

        channel = FlutterMethodChannel(
            name: PlayerConstants.sgChannelName(viewId: Int(viewId)),
            binaryMessenger: messenger,
        )
        channelCallbacks = SgChannelCallbacks(channel: channel)
        chrome = SgPlayerChromeView(config: uiConfig)
        player = SgNativePlayer(callbacks: channelCallbacks)
        super.init()

        channelCallbacks.attach(host: self)

        container.frame = frame
        container.backgroundColor = .black

        player.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(player.view)

        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.delegate = self
        container.addSubview(chrome)

        NSLayoutConstraint.activate([
            player.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            player.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            player.view.topAnchor.constraint(equalTo: container.topAnchor),
            player.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if let url = params?["url"] as? String {
            player.switchVideoSource(url, autoPlay: false)
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    func view() -> UIView { container }

    func onProgressChanged(positionMs: Int64, durationMs: Int64) {
        chrome.updateProgress(positionMs: positionMs, durationMs: durationMs)
    }

    func onPlayerStateChanged(_ state: CommonPlayerState) {
        isPlaying = state == .playing
        chrome.updatePlayState(isPlaying: isPlaying)
        if state == .paused || state == .completed || state == .idle {
            chrome.setControlsVisible(true, animated: true)
        }
    }

    // MARK: - SgPlayerChromeDelegate

    func chromeDidTapPlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func chromeDidSeek(toMs: Int) {
        player.seek(positionMs: toMs)
    }

    func chromeDidTapFullscreen() {
        fullscreenPresenter.toggleFullscreen(container: container)
        chrome.updateFullscreenIcon(isFullscreen: fullscreenPresenter.isFullscreen)
    }

    func chromeDidChangeVolume(_ volume: Double) {
        player.setVolume(volume)
        chrome.syncVolume(volume: player.currentVolume(), muted: player.isMuted())
    }

    func chromeDidToggleMute(_ muted: Bool) {
        player.setMute(muted)
        chrome.syncVolume(volume: player.currentVolume(), muted: player.isMuted())
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            player.play()
            result(nil)
        case "pause":
            player.pause()
            result(nil)
        case "stop":
            player.stop()
            result(nil)
        case "seekTo":
            let args = call.arguments as? [String: Any]
            let position = args?["position"] as? Int ?? 0
            player.seek(positionMs: position)
            result(nil)
        case "setScaleMode":
            let args = call.arguments as? [String: Any]
            let mode = args?["mode"] as? Int ?? 0
            player.setRenderMode(mode)
            result(nil)
        case "setRate":
            let args = call.arguments as? [String: Any]
            let rate = args?["rate"] as? Double ?? 1.0
            player.setRate(rate)
            result(nil)
        case "setVolume":
            let args = call.arguments as? [String: Any]
            let volume = args?["volume"] as? Double ?? 1.0
            player.setVolume(volume)
            chrome.syncVolume(volume: player.currentVolume(), muted: player.isMuted())
            result(nil)
        case "setMute":
            let args = call.arguments as? [String: Any]
            let muted = args?["muted"] as? Bool ?? false
            player.setMute(muted)
            chrome.syncVolume(volume: player.currentVolume(), muted: player.isMuted())
            result(nil)
        case "switchVideoSource":
            let args = call.arguments as? [String: Any]
            let url = args?["url"] as? String ?? ""
            let autoPlay = args?["autoPlay"] as? Bool ?? true
            player.switchVideoSource(url, autoPlay: autoPlay)
            result(nil)
        case "getAudioTracks":
            result(player.getAudioTracks())
        case "selectAudioTrack":
            let args = call.arguments as? [String: Any]
            let index = args?["index"] as? Int ?? 0
            if player.selectAudioTrack(index) {
                result(nil)
            } else {
                result(FlutterError(code: "TRACK", message: "Audio track not found", details: nil))
            }
        case "getVideoSize":
            result(player.getVideoSize())
        case "setLooping":
            let args = call.arguments as? [String: Any]
            let looping = args?["looping"] as? Bool ?? false
            player.setLooping(looping)
            result(nil)
        case "captureFrame":
            result(player.captureFrame())
        case "sgStartFullscreen":
            if !fullscreenPresenter.isFullscreen {
                fullscreenPresenter.enterFullscreen(container: container)
                chrome.updateFullscreenIcon(isFullscreen: true)
            }
            result(nil)
        case "sgExitFullscreen":
            if fullscreenPresenter.isFullscreen {
                fullscreenPresenter.exitFullscreen()
                chrome.updateFullscreenIcon(isFullscreen: false)
            }
            result(nil)
        case "sgIsFullscreen":
            result(fullscreenPresenter.isFullscreen)
        case "sgSetVRMode":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? false
            player.setSgVRMode(enabled: enabled)
            result(nil)
        case "sgSetSyncGroupId":
            let args = call.arguments as? [String: Any]
            let id = args?["id"] as? String ?? ""
            player.setSyncGroupId(id)
            result(nil)
        case "dispose":
            if fullscreenPresenter.isFullscreen {
                fullscreenPresenter.exitFullscreen()
            }
            channel.setMethodCallHandler(nil)
            player.release()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

private final class SgChannelCallbacks: SgPlayerCallbacks {
    private let channel: FlutterMethodChannel
    private weak var host: SgVideoPlatformView?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func attach(host: SgVideoPlatformView) {
        self.host = host
    }

    func onPlayerStateChanged(_ state: CommonPlayerState) {
        host?.onPlayerStateChanged(state)
        channel.invokeMethod("onPlayerStateChanged", arguments: ["state": state.rawValue])
    }

    func onPositionChanged(positionMs: Int64, durationMs: Int64) {
        host?.onProgressChanged(positionMs: positionMs, durationMs: durationMs)
        channel.invokeMethod(
            "onPositionChanged",
            arguments: [
                "position": positionMs,
                "duration": durationMs,
            ],
        )
    }
}

final class SgVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
    ) -> FlutterPlatformView {
        SgVideoPlatformView(frame: frame, viewId: viewId, messenger: messenger, args: args)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
