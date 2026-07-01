package com.keepwan.kinetic_player.gsy

import com.shuyu.gsyvideoplayer.GSYVideoManager
import com.shuyu.gsyvideoplayer.player.IjkPlayerManager
import tv.danmaku.ijk.media.exo2.Exo2PlayerManager
import tv.danmaku.ijk.media.exo2.IjkExo2MediaPlayer
import tv.danmaku.ijk.media.player.misc.ITrackInfo

object GsyAudioTrackHelper {
    data class AudioTrack(
        val index: Int,
        val label: String,
        val language: String?,
        val selected: Boolean,
    )

    fun listAudioTracks(): List<AudioTrack> {
        listExoAudioTracks().takeIf { it.isNotEmpty() }?.let { return it }
        return listIjkAudioTracks()
    }

    fun selectAudioTrack(index: Int): Boolean {
        if (selectExoAudioTrack(index)) return true
        return selectIjkAudioTrack(index)
    }

    private fun listExoAudioTracks(): List<AudioTrack> {
        val manager = GSYVideoManager.instance().curPlayerManager as? Exo2PlayerManager ?: return emptyList()
        val exo = manager.mediaPlayer as? IjkExo2MediaPlayer ?: return emptyList()
        val tracks = exo.currentTracks ?: return emptyList()
        val result = mutableListOf<AudioTrack>()
        var index = 0
        for (group in tracks.groups) {
            if (group.type != androidx.media3.common.C.TRACK_TYPE_AUDIO) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                result.add(
                    AudioTrack(
                        index = index++,
                        label = format.label ?: format.language ?: "audio",
                        language = format.language,
                        selected = group.isTrackSelected(i),
                    ),
                )
            }
        }
        return result
    }

    private fun selectExoAudioTrack(index: Int): Boolean {
        val manager = GSYVideoManager.instance().curPlayerManager as? Exo2PlayerManager ?: return false
        val exo = manager.mediaPlayer as? IjkExo2MediaPlayer ?: return false
        val selector = exo.trackSelector ?: return false
        val tracks = exo.currentTracks ?: return false
        var targetIndex = 0
        for (group in tracks.groups) {
            if (group.type != androidx.media3.common.C.TRACK_TYPE_AUDIO) continue
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

    private fun listIjkAudioTracks(): List<AudioTrack> {
        val manager = GSYVideoManager.instance().curPlayerManager as? IjkPlayerManager ?: return emptyList()
        val mediaPlayer = manager.mediaPlayer ?: return emptyList()
        val trackInfos =
            try {
                mediaPlayer.trackInfo
            } catch (_: Exception) {
                return emptyList()
            } ?: return emptyList()
        val result = mutableListOf<AudioTrack>()
        var audioIndex = 0
        for (trackInfo in trackInfos) {
            if (trackInfo.trackType != ITrackInfo.MEDIA_TRACK_TYPE_AUDIO) continue
            result.add(
                AudioTrack(
                    index = audioIndex++,
                    label = trackInfo.info ?: "audio",
                    language = null,
                    selected = false,
                ),
            )
        }
        return result
    }

    private fun selectIjkAudioTrack(index: Int): Boolean {
        val manager = GSYVideoManager.instance().curPlayerManager as? IjkPlayerManager ?: return false
        val mediaPlayer = manager.mediaPlayer ?: return false
        val trackInfos =
            try {
                mediaPlayer.trackInfo
            } catch (_: Exception) {
                return false
            } ?: return false
        var audioIndex = 0
        for ((trackIndex, trackInfo) in trackInfos.withIndex()) {
            if (trackInfo.trackType != ITrackInfo.MEDIA_TRACK_TYPE_AUDIO) continue
            if (audioIndex == index) {
                mediaPlayer.selectTrack(trackIndex)
                return true
            }
            audioIndex++
        }
        return false
    }
}
