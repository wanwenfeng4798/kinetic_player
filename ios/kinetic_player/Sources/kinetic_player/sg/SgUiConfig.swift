import Foundation

struct SgUiConfig {
    let showNativeControls: Bool
    let showVolumeToolbar: Bool
    let showSettingsButton: Bool
    let pictureInPictureEnabled: Bool
    let showFullscreenButton: Bool
    let dismissControlTimeMs: Int

    /// SGPlayer uses a custom video renderer; system PiP (AVPictureInPictureController) is unavailable.
    static var isPictureInPictureSupported: Bool { false }

    static func fromCreationParams(_ params: [String: Any]?) -> SgUiConfig {
        let gsyUi = params?["gsyUi"] as? [String: Any]
        return SgUiConfig(
            showNativeControls:
                params?["showNativeControls"] as? Bool
                ?? gsyUi?["enableNativeControls"] as? Bool
                ?? true,
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
            dismissControlTimeMs:
                params?["dismissControlTime"] as? Int
                ?? gsyUi?["dismissControlTime"] as? Int
                ?? 2500,
        )
    }
}
