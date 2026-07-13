import Foundation

struct SgUiConfig {
    /// Native chrome + pan gestures (seek / volume / brightness).
    /// Mapped from `enableNativeControls` / legacy `showNativeControls`.
    let enableNativeControls: Bool
    let showVolumeToolbar: Bool
    let showSettingsButton: Bool
    let pictureInPictureEnabled: Bool
    let showFullscreenButton: Bool
    let dismissControlTimeMs: Int

    /// SGPlayer uses a custom video renderer; system PiP (AVPictureInPictureController) is unavailable.
    static var isPictureInPictureSupported: Bool { false }

    static func fromCreationParams(_ params: [String: Any]?) -> SgUiConfig {
        let gsyUi = params?["gsyUi"] as? [String: Any]
        // Prefer enableNativeControls; keep showNativeControls / enableGestureControls as aliases.
        let enableNativeControls =
            gsyUi?["enableNativeControls"] as? Bool
            ?? params?["enableNativeControls"] as? Bool
            ?? params?["showNativeControls"] as? Bool
            ?? gsyUi?["enableGestureControls"] as? Bool
            ?? params?["enableGestureControls"] as? Bool
            ?? true
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
            dismissControlTimeMs:
                params?["dismissControlTime"] as? Int
                ?? gsyUi?["dismissControlTime"] as? Int
                ?? 2500,
        )
    }
}
