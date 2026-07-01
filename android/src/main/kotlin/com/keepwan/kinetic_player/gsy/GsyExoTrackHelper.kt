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
                        label = format.label ?: "${format.width}x${format.height}",
                        width = format.width,
                        height = format.height,
                        bitrate = format.bitrate,
                        selected = group.isTrackSelected(i),
                    ),
                )
            }
        }
        return result
    }

    fun selectVideoTrack(index: Int): Boolean {
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
                    return true
                }
                targetIndex++
            }
        }
        return false
    }
}
