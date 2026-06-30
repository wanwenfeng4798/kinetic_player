import Flutter
import UIKit

final class SgVideoPlatformView: NSObject, FlutterPlatformView {
    private let container = UIView()
    private let player: SgNativePlayer
    private let channel: FlutterMethodChannel

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

        container.frame = frame
        player.view.frame = container.bounds
        player.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(player.view)

        if let params = args as? [String: Any], let url = params["url"] as? String {
            player.setUrl(url)
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
        case "gsySwitchRenderCore", "gsyToggleDanmaku":
            result(FlutterMethodNotImplemented)
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
