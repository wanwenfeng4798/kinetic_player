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
    /// Initial playback rate from shared `KineticUiConfig.speed`.
    let speed: Float
    /// Initial looping from shared `KineticUiConfig.looping`.
    let looping: Bool
    /// ARGB accent color (default Bilibili pink).
    let accentColor: Int
    /// Chrome language from `KineticUiConfig.locale` (`ui.locale`).
    var locale: String
    /// Resolved chrome copy from Dart `KineticChromeStrings` (`ui.strings`).
    var strings: [String: String]

    /// SGPlayer uses a custom video renderer; system PiP (AVPictureInPictureController) is unavailable.
    static var isPictureInPictureSupported: Bool { false }

    static let defaultAccentColor: Int = 0xFFFB7299

    static func parseStrings(_ raw: Any?) -> [String: String] {
        guard let map = raw as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        out.reserveCapacity(map.count)
        for (key, value) in map {
            if let text = value as? String {
                out[key] = text
            }
        }
        return out
    }

    static func fromCreationParams(_ params: [String: Any]?) -> SgUiConfig {
        let ui = params?["ui"] as? [String: Any]
        let enableNativeControls =
            ui?["enableNativeControls"] as? Bool
            ?? params?["enableNativeControls"] as? Bool
            ?? true
        let speedNumber =
            (ui?["speed"] as? NSNumber)
            ?? (params?["speed"] as? NSNumber)
        let accentNumber =
            (ui?["accentColor"] as? NSNumber)
            ?? (params?["accentColor"] as? NSNumber)
        return SgUiConfig(
            enableNativeControls: enableNativeControls,
            showVolumeToolbar:
                ui?["showVolumeToolbar"] as? Bool
                ?? params?["showVolumeToolbar"] as? Bool
                ?? true,
            showSettingsButton:
                ui?["showSettingsButton"] as? Bool
                ?? params?["showSettingsButton"] as? Bool
                ?? true,
            pictureInPictureEnabled:
                ui?["pictureInPictureEnabled"] as? Bool
                ?? params?["pictureInPictureEnabled"] as? Bool
                ?? true,
            showFullscreenButton:
                ui?["showFullscreenButton"] as? Bool
                ?? params?["showFullscreenButton"] as? Bool
                ?? true,
            showLockButton:
                ui?["showLockButton"] as? Bool
                ?? params?["showLockButton"] as? Bool
                ?? true,
            dismissControlTimeMs:
                ui?["dismissControlTime"] as? Int
                ?? params?["dismissControlTime"] as? Int
                ?? 2500,
            keepLastFrameWhenComplete:
                ui?["keepLastFrameWhenComplete"] as? Bool
                ?? params?["keepLastFrameWhenComplete"] as? Bool
                ?? false,
            coverUrl:
                ui?["coverUrl"] as? String
                ?? params?["coverUrl"] as? String,
            speed: speedNumber?.floatValue ?? 1,
            looping:
                ui?["looping"] as? Bool
                ?? params?["looping"] as? Bool
                ?? false,
            accentColor: accentNumber?.intValue ?? defaultAccentColor,
            locale: ui?["locale"] as? String ?? "zh",
            strings: parseStrings(ui?["strings"]),
        )
    }
}
