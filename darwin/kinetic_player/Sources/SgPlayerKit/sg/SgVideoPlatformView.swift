#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
import ObjectiveC
#endif

import Network

final class SgVideoPlatformView: NSObject {
#if os(iOS)
    private let container = UIView()
#elseif os(macOS)
    private let container = NSView()
#endif
    private let player: SgNativePlayer
    private let channel: FlutterMethodChannel
    private let fullscreenPresenter = SgFullscreenPresenter()
    private let channelCallbacks: SgChannelCallbacks
    private var isPlaying = false
    private var keepLastFrameWhenComplete = false
    private var latestState: CommonPlayerState = .idle
    private var playlist: [String] = []
    private var playlistIndex = 0

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: Any?,
    ) {
        let params = args as? [String: Any]
        let uiConfig = SgUiConfig.fromCreationParams(params)
        keepLastFrameWhenComplete = uiConfig.keepLastFrameWhenComplete

        channel = FlutterMethodChannel(
            name: PlayerConstants.sgChannelName(viewId: Int(viewId)),
            binaryMessenger: messenger,
        )
        channelCallbacks = SgChannelCallbacks(channel: channel)
        player = SgNativePlayer(callbacks: channelCallbacks)
        super.init()

        channelCallbacks.attach(host: self)
        player.setDismissFullscreenHandler { [weak self] in
            guard let self, self.fullscreenPresenter.isFullscreen else { return }
            self.fullscreenPresenter.exitFullscreen()
            self.forceContainerLayout()
            self.player.applyRenderTransform()
        }

        container.frame = frame
#if os(iOS)
        container.backgroundColor = .black
        container.clipsToBounds = true
#elseif os(macOS)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.masksToBounds = true
#endif

        player.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(player.view)

        player.setCoverUrl(uiConfig.coverUrl)

        player.configureControls(
            enabled: uiConfig.enableNativeControls,
            autoHide: Double(uiConfig.dismissControlTimeMs) / 1000
        ) { [weak self] in
            guard let self else { return }
            self.fullscreenPresenter.toggleFullscreen(container: self.container)
            self.forceContainerLayout()
            self.player.applyRenderTransform()
        }

        NSLayoutConstraint.activate([
            player.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            player.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            player.view.topAnchor.constraint(equalTo: container.topAnchor),
            player.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let playlistArgs = (params?["playlist"] as? [String]) ?? []
        let startIndex = params?["playlistStartIndex"] as? Int ?? 0
        applyHttpFromCreationParams(params)
        let autoPlay = params?["autoPlay"] as? Bool ?? false
        player.setAutomaticAdvance(params?["autoPlayNext"] as? Bool ?? true)
        if !playlistArgs.isEmpty {
            setPlaylist(playlistArgs, startIndex: startIndex, autoPlay: autoPlay)
        } else if let url = params?["url"] as? String, !url.isEmpty {
            player.switchVideoSource(url, autoPlay: autoPlay)
        }
        player.setLooping(uiConfig.looping)
        if abs(uiConfig.speed - 1) > 0.001 {
            player.setRate(Double(uiConfig.speed))
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

#if os(iOS)
    func view() -> UIView { container }
#elseif os(macOS)
    func view() -> NSView { container }
#endif

    /// UIView.layoutIfNeeded() / NSView.layoutSubtreeIfNeeded() equivalent.
    private func forceContainerLayout() {
#if os(iOS)
        container.layoutIfNeeded()
#elseif os(macOS)
        container.layoutSubtreeIfNeeded()
#endif
    }

    func onProgressChanged(positionMs: Int64, durationMs: Int64, bufferedMs: Int64) {
        _ = bufferedMs
    }

    func onPlayerError(message: String?, code: Int) {
        _ = message
        _ = code
    }

    func onPlayerStateChanged(_ state: CommonPlayerState) {
        latestState = state
        isPlaying = state == .playing
    }

    private func setPlaylist(_ urls: [String], startIndex: Int, autoPlay: Bool) {
        playlist = urls.filter { !$0.isEmpty }
        guard !playlist.isEmpty else { return }
        playlistIndex = min(max(0, startIndex), playlist.count - 1)
        _ = player.setPlaylist(playlist, startIndex: playlistIndex, autoPlay: autoPlay)
    }

    private func applyHttpFromCreationParams(_ params: [String: Any]?) {
        guard let params else { return }
        var options: [String: Any] = [:]
        if let userAgent = params["userAgent"] as? String, !userAgent.isEmpty {
            options["userAgent"] = userAgent
        }
        if let headers = params["headers"] as? [String: Any], !headers.isEmpty {
            options["headers"] = headers
        }
        guard !options.isEmpty else { return }
        player.setHttpRequestOptions(options)
    }

    @discardableResult
    private func playNextInPlaylist() -> Bool {
        player.playNext()
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
            result(nil)
        case "setMute":
            let args = call.arguments as? [String: Any]
            let muted = args?["muted"] as? Bool ?? false
            player.setMute(muted)
            result(nil)
        case "switchVideoSource":
            let args = call.arguments as? [String: Any]
            let url = args?["url"] as? String ?? ""
            let autoPlay = args?["autoPlay"] as? Bool ?? true
            if let idx = playlist.firstIndex(of: url) {
                playlistIndex = idx
            }
            player.switchVideoSource(url, autoPlay: autoPlay)
            latestState = .idle
                result(nil)
        case "gsySetPlaylist":
            let args = call.arguments as? [String: Any]
            let urls = args?["urls"] as? [String] ?? []
            let startIndex = args?["startIndex"] as? Int ?? 0
            setPlaylist(urls, startIndex: startIndex, autoPlay: args?["autoPlay"] as? Bool ?? false)
            result(nil)
        case "gsyPlayNextInPlaylist":
            result(playNextInPlaylist())
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
            if let data = player.captureFrame() {
                result(FlutterStandardTypedData(bytes: data))
            } else {
                result(nil)
            }
        case "sgSetAutoPlayNext":
            let args = call.arguments as? [String: Any] ?? [:]
            player.setAutomaticAdvance(args["enabled"] as? Bool ?? true)
            result(nil)
        case "sgSetUiConfig":
            let config = SgUiConfig.fromCreationParams(call.arguments as? [String: Any])
            player.configureControls(enabled: config.enableNativeControls, autoHide: Double(config.dismissControlTimeMs) / 1000) { [weak self] in
                guard let self else { return }
                self.fullscreenPresenter.toggleFullscreen(container: self.container)
                self.forceContainerLayout()
                self.player.applyRenderTransform()
            }
            player.setRate(Double(config.speed))
            player.setLooping(config.looping)
            player.setCoverUrl(config.coverUrl)
            keepLastFrameWhenComplete = config.keepLastFrameWhenComplete
            result(nil)
        case "sgEnterFullscreen", "sgStartFullscreen":
            if !fullscreenPresenter.isFullscreen {
                fullscreenPresenter.enterFullscreen(container: container)
                forceContainerLayout()
                player.applyRenderTransform()
            }
            result(nil)
        case "sgExitFullscreen":
            if fullscreenPresenter.isFullscreen {
                fullscreenPresenter.exitFullscreen()
                forceContainerLayout()
                player.applyRenderTransform()
            }
            result(nil)
        case "sgIsFullscreen":
            result(fullscreenPresenter.isFullscreen)
        case "sgSetVRMode":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? false
            player.setSgVRMode(enabled: enabled)
            result(nil)
        case "sgSetDisplayMode":
            let args = call.arguments as? [String: Any]
            let mode = args?["mode"] as? Int ?? 0
            player.setDisplayMode(mode)
            result(nil)
        case "sgGetDisplayMode":
            result(player.displayMode())
        case "sgSetVrViewport":
            let args = call.arguments as? [String: Any] ?? [:]
            player.setVrViewport(args)
            result(nil)
        case "sgGetVrViewport":
            result(player.vrViewport())
        case "sgSetPitch":
            let args = call.arguments as? [String: Any]
            let pitch = args?["pitch"] as? Double ?? 1.0
            player.setPitch(pitch)
            result(nil)
        case "sgGetPitch":
            result(player.currentPitch())
        case "sgGetVideoTracks":
            result(player.getVideoTracks())
        case "sgSelectVideoTrack":
            let args = call.arguments as? [String: Any]
            let index = args?["index"] as? Int ?? 0
            if player.selectVideoTrack(index) {
                result(nil)
            } else {
                result(FlutterError(code: "TRACK", message: "Video track not found", details: nil))
            }
        case "sgSetDemuxerOptions":
            let args = call.arguments as? [String: Any] ?? [:]
            player.setDemuxerOptions(args)
            result(nil)
        case "sgReplaceWithSegments":
            let args = call.arguments as? [String: Any]
            let segments = args?["segments"] as? [[String: Any]] ?? []
            let autoPlay = args?["autoPlay"] as? Bool ?? true
            let ok = player.replaceWithSegments(segments, autoPlay: autoPlay)
            latestState = .idle
                result(ok)
        case "sgSetBackgroundPlaybackPolicy":
            let args = call.arguments as? [String: Any] ?? [:]
            player.setBackgroundPlaybackPolicy(args)
            result(nil)
        case "sgGetBackgroundPlaybackPolicy":
            result(player.backgroundPlaybackPolicy())
        case "sgGetBufferedPosition":
            result(player.bufferedPositionMs())
        case "sgGetLastError":
            result([
                "message": player.lastErrorMessage() as Any,
                "code": player.lastErrorCode(),
            ])
        case "sgIsSeekable":
            result(player.isSeekable())
        case "sgSetRenderRotation":
            let args = call.arguments as? [String: Any]
            let degrees = args?["degrees"] as? Int ?? 0
            player.setRenderRotation(degrees: degrees)
            result(nil)
        case "sgSetMirrorHorizontal":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? false
            player.setMirrorHorizontal(enabled: enabled)
            result(nil)
        case "sgSetMirrorVertical":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? false
            player.setMirrorVertical(enabled: enabled)
            result(nil)
        case "sgSetKeepLastFrameWhenComplete":
            result(FlutterError(code: "UNSUPPORTED", message: "Completion cover policy belongs to SGPlayer native controls", details: nil))
        case "sgSetCoverUrl":
            let args = call.arguments as? [String: Any]
            player.setCoverUrl(args?["url"] as? String)
            result(nil)
        case "setLocale":
            result(FlutterError(code: "UNSUPPORTED", message: "SGPlayer 2 native controls do not expose runtime localization", details: nil))
        case "setHttpRequestOptions":
            let args = call.arguments as? [String: Any] ?? [:]
            player.setHttpRequestOptions(args)
            result(nil)
        case "sgFeature":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let operation = args["operation"] as? String else {
                result(FlutterError(code: "ARGUMENT", message: "operation required", details: nil))
                return
            }
            let raw = args["arguments"] as? [String: Any] ?? [:]
            func decode(_ value: Any) -> Any {
                if let data = value as? FlutterStandardTypedData { return data.data }
                if let map = value as? [String: Any] { return map.mapValues(decode) }
                if let list = value as? [Any] { return list.map(decode) }
                return value
            }
            player.performOperation(operation, arguments: raw.mapValues(decode)) { value, error in
                DispatchQueue.main.async {
                    if let error {
                        result(FlutterError(code: "SG_FEATURE", message: error.localizedDescription, details: ["domain": (error as NSError).domain, "code": (error as NSError).code]))
                    } else {
                        func encode(_ value: Any) -> Any {
                            if let data = value as? Data { return FlutterStandardTypedData(bytes: data) }
                            if let map = value as? [String: Any] { return map.mapValues(encode) }
                            if let list = value as? [Any] { return list.map(encode) }
                            return value
                        }
                        result(value.map(encode))
                    }
                }
            }
        case "sgNetworkDiagnostics":
            let monitor = NWPathMonitor()
            var finished = false
            monitor.pathUpdateHandler = { path in
                let data: [String: Any] = [
                    "status": String(describing: path.status),
                    "reason": String(describing: path.unsatisfiedReason),
                    "supportsDNS": path.supportsDNS,
                    "supportsIPv4": path.supportsIPv4,
                    "supportsIPv6": path.supportsIPv6,
                    "wifi": path.usesInterfaceType(.wifi),
                    "cellular": path.usesInterfaceType(.cellular),
                ]
                DispatchQueue.main.async {
                    guard !finished else { return }
                    finished = true
                    monitor.pathUpdateHandler = nil
                    monitor.cancel()
                    result(data)
                }
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                guard !finished else { return }
                finished = true
                monitor.pathUpdateHandler = nil
                monitor.cancel()
                result(FlutterError(code: "NETWORK_DIAGNOSTICS", message: "Network path query timed out", details: nil))
            }
        case "sgDiagnostics":
            result(player.diagnostics())
        case "sgStartPictureInPicture":
            result(player.startPictureInPicture())
        case "sgStopPictureInPicture":
            player.stopPictureInPicture()
            result(nil)
        case "sgIsPictureInPictureActive":
            result(player.isPictureInPictureActive())
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

    func onPositionChanged(positionMs: Int64, durationMs: Int64, bufferedMs: Int64) {
        host?.onProgressChanged(positionMs: positionMs, durationMs: durationMs, bufferedMs: bufferedMs)
        channel.invokeMethod(
            "onPositionChanged",
            arguments: [
                "position": positionMs,
                "duration": durationMs,
                "buffered": bufferedMs,
            ],
        )
    }

    func onNativeFeatureEvent(_ event: [AnyHashable: Any]) {
        channel.invokeMethod("onSgFeatureEvent", arguments: event)
    }

    func onPlayerError(message: String?, code: Int) {
        host?.onPlayerError(message: message, code: code)
        channel.invokeMethod(
            "onPlayerError",
            arguments: [
                "message": message as Any,
                "code": code,
            ],
        )
    }
}

#if os(iOS)
extension SgVideoPlatformView: FlutterPlatformView {}
#endif

final class SgVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

#if os(iOS)
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
    ) -> FlutterPlatformView {
        SgVideoPlatformView(frame: frame, viewId: viewId, messenger: messenger, args: args)
    }
#elseif os(macOS)
    // macOS factory returns NSView directly (no FlutterPlatformView protocol).
    // Retain the controller on the view so channel handlers stay alive.
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let platformView = SgVideoPlatformView(
            frame: .zero,
            viewId: viewId,
            messenger: messenger,
            args: args,
        )
        let view = platformView.view()
        objc_setAssociatedObject(
            view,
            &SgVideoPlatformViewAssociationKey,
            platformView,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC,
        )
        return view
    }
#endif

#if os(iOS)
    // iOS headers use NS_ASSUME_NONNULL: implemented createArgsCodec must be non-optional.
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
#elseif os(macOS)
    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }
#endif
}

#if os(macOS)
private var SgVideoPlatformViewAssociationKey: UInt8 = 0
#endif
