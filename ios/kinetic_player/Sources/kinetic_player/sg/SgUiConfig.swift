import Foundation

struct SgUiConfig {
    let showNativeControls: Bool
    let showVolumeToolbar: Bool
    let showFullscreenButton: Bool
    let dismissControlTimeMs: Int

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
