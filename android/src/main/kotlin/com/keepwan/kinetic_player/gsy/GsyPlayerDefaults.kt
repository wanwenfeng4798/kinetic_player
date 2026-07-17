package com.keepwan.kinetic_player.gsy

import com.shuyu.gsyvideoplayer.GSYVideoManager
import com.shuyu.gsyvideoplayer.model.VideoOptionModel
import com.shuyu.gsyvideoplayer.player.IjkPlayerManager
import com.shuyu.gsyvideoplayer.player.PlayerFactory
import tv.danmaku.ijk.media.player.IjkMediaPlayer

/** Global GSY defaults applied when the Flutter plugin attaches. */
object GsyPlayerDefaults {
    fun applyPluginDefaults(ijkEnableAccurateSeek: Boolean = true) {
        PlayerFactory.setPlayManager(IjkPlayerManager::class.java)
        applyIjkOptions(ijkEnableAccurateSeek)
    }

    /** IJK-only FFmpeg options; ignored by Exo / System cores. */
    fun applyIjkOptions(enableAccurateSeek: Boolean) {
        val options =
            if (enableAccurateSeek) {
                listOf(
                    VideoOptionModel(
                        IjkMediaPlayer.OPT_CATEGORY_PLAYER,
                        "enable-accurate-seek",
                        1,
                    ),
                )
            } else {
                emptyList()
            }
        GSYVideoManager.instance().setOptionModelList(options)
    }
}
