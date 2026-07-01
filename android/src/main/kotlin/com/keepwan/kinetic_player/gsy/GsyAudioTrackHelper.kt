package com.keepwan.kinetic_player.gsy

import com.shuyu.gsyvideoplayer.GSYVideoManager
import com.shuyu.gsyvideoplayer.player.IjkPlayerManager
import tv.danmaku.ijk.media.exo2.Exo2PlayerManager
import tv.danmaku.ijk.media.exo2.IjkExo2MediaPlayer
import tv.danmaku.ijk.media.player.IjkMediaPlayer
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
        val ijkPlayer = manager.mediaPlayer as? IjkMediaPlayer ?: return emptyList()
        val trackInfos =
            try {
                ijkPlayer.trackInfo
            } catch (_: Exception) {
                return emptyList()
            } ?: return emptyList()
        val selectedAudioStream = ijkPlayer.getSelectedTrack(ITrackInfo.MEDIA_TRACK_TYPE_AUDIO)
        val result = mutableListOf<AudioTrack>()
        var audioIndex = 0
        for ((streamIndex, trackInfo) in trackInfos.withIndex()) {
            if (trackInfo.trackType != ITrackInfo.MEDIA_TRACK_TYPE_AUDIO) continue
            val inline = trackInfo.infoInline?.takeIf { it.isNotBlank() }
            val language = trackInfo.language?.takeIf { it.isNotBlank() }
            result.add(
                AudioTrack(
                    index = audioIndex++,
                    label = inline ?: language ?: "audio",
                    language = language,
                    selected = streamIndex == selectedAudioStream,
                ),
            )
        }
        return result
    }

    private fun selectIjkAudioTrack(index: Int): Boolean {
        val manager = GSYVideoManager.instance().curPlayerManager as? IjkPlayerManager ?: return false
        val ijkPlayer = manager.mediaPlayer as? IjkMediaPlayer ?: return false
        val trackInfos =
            try {
                ijkPlayer.trackInfo
            } catch (_: Exception) {
                return false
            } ?: return false
        var audioIndex = 0
        for ((streamIndex, trackInfo) in trackInfos.withIndex()) {
            if (trackInfo.trackType != ITrackInfo.MEDIA_TRACK_TYPE_AUDIO) continue
            if (audioIndex == index) {
                ijkPlayer.selectTrack(streamIndex)
                return true
            }
            audioIndex++
        }
        return false
    }
}
