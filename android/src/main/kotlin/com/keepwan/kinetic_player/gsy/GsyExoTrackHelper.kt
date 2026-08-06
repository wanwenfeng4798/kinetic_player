package com.keepwan.kinetic_player.gsy

import com.shuyu.gsyvideoplayer.GSYVideoManager
import tv.danmaku.ijk.media.exo2.Exo2PlayerManager
import tv.danmaku.ijk.media.exo2.IjkExo2MediaPlayer

object GsyExoTrackHelper {
    data class VideoTrack(
        val index: Int,
        val label: String,
        val width: Int,
        val height: Int,
        val bitrate: Int,
        val selected: Boolean,
    )

    /** True when no fixed video-track override is applied (ABR / Auto). */
    @Volatile
    private var autoMode = true

    fun isAutoMode(): Boolean = autoMode

    fun listVideoTracks(): List<VideoTrack> {
        val manager = GSYVideoManager.instance().curPlayerManager as? Exo2PlayerManager ?: return emptyList()
        val exo = manager.mediaPlayer as? IjkExo2MediaPlayer ?: return emptyList()
        val tracks = exo.currentTracks ?: return emptyList()
        val result = mutableListOf<VideoTrack>()
        var index = 0
        for (group in tracks.groups) {
            if (group.type != androidx.media3.common.C.TRACK_TYPE_VIDEO) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                result.add(
                    VideoTrack(
                        index = index++,
                        label = qualityLabel(format.width, format.height, format.label),
                        width = format.width,
                        height = format.height,
                        bitrate = format.bitrate,
                        selected = !autoMode && group.isTrackSelected(i),
                    ),
                )
            }
        }
        return result
    }

    fun qualityLabel(
        width: Int,
        height: Int,
        fallback: String?,
    ): String {
        val h = maxOf(width, height)
        return when {
            h >= 2160 -> "4K"
            h >= 1440 -> "1440P"
            h >= 1080 -> "1080P"
            h >= 720 -> "720P"
            h >= 480 -> "480P"
            h >= 360 -> "360P"
            !fallback.isNullOrBlank() -> fallback
            h > 0 -> "${h}P"
            else -> "视频"
        }
    }

    /** Select a fixed track by index, or pass `-1` to clear override (Auto). */
    fun selectVideoTrack(index: Int): Boolean {
        if (index < 0) {
            return clearVideoTrackOverride()
        }
        val manager = GSYVideoManager.instance().curPlayerManager as? Exo2PlayerManager ?: return false
        val exo = manager.mediaPlayer as? IjkExo2MediaPlayer ?: return false
        val selector = exo.trackSelector ?: return false
        val tracks = exo.currentTracks ?: return false
        var targetIndex = 0
        for (group in tracks.groups) {
            if (group.type != androidx.media3.common.C.TRACK_TYPE_VIDEO) continue
            for (i in 0 until group.length) {
                if (targetIndex == index) {
                    val parameters =
                        selector.parameters.buildUpon()
                            .setOverrideForType(
                                androidx.media3.common.TrackSelectionOverride(
                                    group.mediaTrackGroup,
                                    i,
                                ),
                            )
                            .build()
                    selector.parameters = parameters
                    autoMode = false
                    return true
                }
                targetIndex++
            }
        }
        return false
    }

    fun clearVideoTrackOverride(): Boolean {
        val manager = GSYVideoManager.instance().curPlayerManager as? Exo2PlayerManager ?: return false
        val exo = manager.mediaPlayer as? IjkExo2MediaPlayer ?: return false
        val selector = exo.trackSelector ?: return false
        selector.parameters =
            selector.parameters.buildUpon()
                .clearOverridesOfType(androidx.media3.common.C.TRACK_TYPE_VIDEO)
                .build()
        autoMode = true
        return true
    }
}
