import Foundation

struct SgUiConfig {
    /// Native chrome + pan gestures (seek / volume / brightness).
    /// Mapped from `enableNativeControls`.
    let enableNativeControls: Bool
    let showVolumeToolbar: Bool
    let showSettingsButton: Bool
    let pictureInPictureEnabled: Bool
    let showFullscreenButton: Bool
    let showLockButton: Bool
    let dismissControlTimeMs: Int
    /// Keep last rendered frame on complete (hide cover overlay).
    let keepLastFrameWhenComplete: Bool
    /// Cover / poster image URL.
    let coverUrl: String?
    /// Initial playback rate from shared `GsyUiConfig.speed`.
    let speed: Float
    /// Initial looping from shared `GsyUiConfig.looping`.
    let looping: Bool
    /// ARGB accent color (default Bilibili pink).
    let accentColor: Int

    /// SGPlayer uses a custom video renderer; system PiP (AVPictureInPictureController) is unavailable.
    static var isPictureInPictureSupported: Bool { false }

    static let defaultAccentColor: Int = 0xFFFB7299

    static func fromCreationParams(_ params: [String: Any]?) -> SgUiConfig {
        let gsyUi = params?["gsyUi"] as? [String: Any]
        let enableNativeControls =
            gsyUi?["enableNativeControls"] as? Bool
            ?? params?["enableNativeControls"] as? Bool
            ?? true
        let speedNumber =
            (params?["speed"] as? NSNumber)
            ?? (gsyUi?["speed"] as? NSNumber)
        let accentNumber =
            (gsyUi?["accentColor"] as? NSNumber)
            ?? (params?["accentColor"] as? NSNumber)
        return SgUiConfig(
            enableNativeControls: enableNativeControls,
            showVolumeToolbar:
                params?["showVolumeToolbar"] as? Bool
                ?? gsyUi?["showVolumeToolbar"] as? Bool
                ?? true,
            showSettingsButton:
                params?["showSettingsButton"] as? Bool
                ?? gsyUi?["showSettingsButton"] as? Bool
                ?? true,
            pictureInPictureEnabled:
                params?["pictureInPictureEnabled"] as? Bool
                ?? gsyUi?["pictureInPictureEnabled"] as? Bool
                ?? true,
            showFullscreenButton:
                params?["showFullscreenButton"] as? Bool
                ?? gsyUi?["showFullscreenButton"] as? Bool
                ?? true,
            showLockButton:
                params?["showLockButton"] as? Bool
                ?? gsyUi?["showLockButton"] as? Bool
                ?? true,
            dismissControlTimeMs:
                params?["dismissControlTime"] as? Int
                ?? gsyUi?["dismissControlTime"] as? Int
                ?? 2500,
            keepLastFrameWhenComplete:
                params?["keepLastFrameWhenComplete"] as? Bool
                ?? gsyUi?["keepLastFrameWhenComplete"] as? Bool
                ?? false,
            coverUrl:
                params?["coverUrl"] as? String
                ?? gsyUi?["coverUrl"] as? String,
            speed: speedNumber?.floatValue ?? 1,
            looping:
                params?["looping"] as? Bool
                ?? gsyUi?["looping"] as? Bool
                ?? false,
            accentColor: accentNumber?.intValue ?? defaultAccentColor,
        )
    }
}
