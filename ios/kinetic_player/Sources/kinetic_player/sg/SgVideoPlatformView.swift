import Flutter
import UIKit

final class SgVideoPlatformView: NSObject, FlutterPlatformView {
    private let container = UIView()
    private let player: SgNativePlayer
    private let channel: FlutterMethodChannel
    private let volumeToolbar = SgVolumeToolbarView()

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: Any?,
    ) {
        channel = FlutterMethodChannel(
            name: PlayerConstants.sgChannelName(viewId: Int(viewId)),
            binaryMessenger: messenger,
        )
        player = SgNativePlayer(
            callbacks: SgChannelCallbacks(channel: channel),
        )
        super.init()

        let params = args as? [String: Any]
        let gsyUi = params?["gsyUi"] as? [String: Any]
        let showVolumeToolbar =
            params?["showVolumeToolbar"] as? Bool
            ?? gsyUi?["showVolumeToolbar"] as? Bool
            ?? true

        container.frame = frame
        container.backgroundColor = .black
        player.view.frame = container.bounds
        player.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(player.view)

        volumeToolbar.translatesAutoresizingMaskIntoConstraints = false
        volumeToolbar.isHidden = !showVolumeToolbar
        container.addSubview(volumeToolbar)
        NSLayoutConstraint.activate([
            volumeToolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            volumeToolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            volumeToolbar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        volumeToolbar.onVolumeChanged = { [weak self] volume in
            guard let self else { return }
            self.player.setVolume(volume)
            self.volumeToolbar.sync(
                volume: self.player.currentVolume(),
                muted: self.player.isMuted(),
            )
        }
        volumeToolbar.onMuteToggle = { [weak self] muted in
            guard let self else { return }
            self.player.setMute(muted)
            self.volumeToolbar.sync(
                volume: self.player.currentVolume(),
                muted: self.player.isMuted(),
            )
        }

        if let url = params?["url"] as? String {
            player.switchVideoSource(url, autoPlay: false)
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    func view() -> UIView { container }

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
            volumeToolbar.sync(volume: player.currentVolume(), muted: player.isMuted())
            result(nil)
        case "setMute":
            let args = call.arguments as? [String: Any]
            let muted = args?["muted"] as? Bool ?? false
            player.setMute(muted)
            volumeToolbar.sync(volume: player.currentVolume(), muted: player.isMuted())
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

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func onPlayerStateChanged(_ state: CommonPlayerState) {
        channel.invokeMethod("onPlayerStateChanged", arguments: ["state": state.rawValue])
    }

    func onPositionChanged(positionMs: Int64, durationMs: Int64) {
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
