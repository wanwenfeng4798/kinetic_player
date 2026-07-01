package com.keepwan.kinetic_player.gsy

import com.shuyu.gsyvideoplayer.utils.GSYVideoType

object GsyScaleModeMapper {
    /** Maps [GsyShowType] index to [GSYVideoType] constants. */
    fun toGsyShowType(mode: Int): Int =
        when (mode) {
            0 -> GSYVideoType.SCREEN_TYPE_DEFAULT
            1 -> GSYVideoType.SCREEN_TYPE_16_9
            2 -> GSYVideoType.SCREEN_TYPE_4_3
            3 -> GSYVideoType.SCREEN_TYPE_FULL
            4 -> GSYVideoType.SCREEN_MATCH_FULL
            5 -> GSYVideoType.SCREEN_TYPE_18_9
            else -> GSYVideoType.SCREEN_TYPE_DEFAULT
        }

    fun setCustomRatio(ratio: Float) {
        GSYVideoType.setScreenScaleRatio(ratio)
        GSYVideoType.setShowType(GSYVideoType.SCREEN_TYPE_CUSTOM)
    }
}
