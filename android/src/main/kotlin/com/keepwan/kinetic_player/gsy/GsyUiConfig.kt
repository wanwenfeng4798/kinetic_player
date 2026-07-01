package com.keepwan.kinetic_player.gsy

/**
 * Mirrors [com.shuyu.gsyvideoplayer.builder.GSYVideoOptionBuilder] defaults for
 * [com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer].
 */
data class GsyUiConfig(
    val enableNativeControls: Boolean = true,
    val enableNativeControlsFullscreen: Boolean = true,
    val videoTitle: String = "",
    val previewVttUrl: String? = null,
    val showFullscreenButton: Boolean = true,
    val showLockButton: Boolean = true,
    val showVolumeToolbar: Boolean = true,
    val showSettingsButton: Boolean = true,
    val pictureInPictureEnabled: Boolean = true,
    val rotateViewAuto: Boolean = true,
    val rotateWithSystem: Boolean = true,
    val lockLand: Boolean = false,
    val needOrientationUtils: Boolean = true,
    val showFullAnimation: Boolean = true,
    val hideVirtualKey: Boolean = true,
    val showPauseCover: Boolean = true,
    val needShowWifiTip: Boolean = true,
    val surfaceErrorPlay: Boolean = true,
    val releaseWhenLossAudio: Boolean = true,
    val showDragProgressTextOnSeekBar: Boolean = false,
    val dismissControlTime: Int = 2500,
    val seekRatio: Float = 1f,
    val speed: Float = 1f,
    val looping: Boolean = false,
    val seekOnStartMs: Long = -1,
    val cacheWithPlay: Boolean = true,
    val startAfterPrepared: Boolean = true,
    val autoFullWithSize: Boolean = false,
    val fullHideActionBar: Boolean = true,
    val fullHideStatusBar: Boolean = true,
) {
    companion object {
        fun fromCreationParams(params: Map<String, Any?>?): GsyUiConfig {
            @Suppress("UNCHECKED_CAST")
            val ui = params?.get("gsyUi") as? Map<String, Any?> ?: emptyMap()
            return GsyUiConfig(
                enableNativeControls = ui["enableNativeControls"] as? Boolean ?: true,
                enableNativeControlsFullscreen =
                    ui["enableNativeControlsFullscreen"] as? Boolean ?: true,
                videoTitle = ui["videoTitle"] as? String ?: "",
                previewVttUrl = ui["previewVttUrl"] as? String,
                showFullscreenButton = ui["showFullscreenButton"] as? Boolean ?: true,
                showLockButton = ui["showLockButton"] as? Boolean ?: true,
                showVolumeToolbar =
                    ui["showVolumeToolbar"] as? Boolean
                        ?: params?.get("showVolumeToolbar") as? Boolean ?: true,
                showSettingsButton =
                    ui["showSettingsButton"] as? Boolean
                        ?: params?.get("showSettingsButton") as? Boolean ?: true,
                pictureInPictureEnabled =
                    ui["pictureInPictureEnabled"] as? Boolean
                        ?: params?.get("pictureInPictureEnabled") as? Boolean ?: true,
                rotateViewAuto = ui["rotateViewAuto"] as? Boolean ?: true,
                rotateWithSystem = ui["rotateWithSystem"] as? Boolean ?: true,
                lockLand = ui["lockLand"] as? Boolean ?: false,
                needOrientationUtils = ui["needOrientationUtils"] as? Boolean ?: true,
                showFullAnimation = ui["showFullAnimation"] as? Boolean ?: true,
                hideVirtualKey = ui["hideVirtualKey"] as? Boolean ?: true,
                showPauseCover = ui["showPauseCover"] as? Boolean ?: true,
                needShowWifiTip = ui["needShowWifiTip"] as? Boolean ?: true,
                surfaceErrorPlay = ui["surfaceErrorPlay"] as? Boolean ?: true,
                releaseWhenLossAudio = ui["releaseWhenLossAudio"] as? Boolean ?: true,
                showDragProgressTextOnSeekBar =
                    ui["showDragProgressTextOnSeekBar"] as? Boolean ?: false,
                dismissControlTime = ui["dismissControlTime"] as? Int ?: 2500,
                seekRatio = (ui["seekRatio"] as? Number)?.toFloat() ?: 1f,
                speed = (ui["speed"] as? Number)?.toFloat() ?: 1f,
                looping = ui["looping"] as? Boolean ?: false,
                seekOnStartMs = (ui["seekOnStartMs"] as? Number)?.toLong() ?: -1,
                cacheWithPlay = ui["cacheWithPlay"] as? Boolean ?: true,
                startAfterPrepared = ui["startAfterPrepared"] as? Boolean ?: true,
                autoFullWithSize = ui["autoFullWithSize"] as? Boolean ?: false,
                fullHideActionBar = ui["fullHideActionBar"] as? Boolean ?: true,
                fullHideStatusBar = ui["fullHideStatusBar"] as? Boolean ?: true,
            )
        }
    }
}
