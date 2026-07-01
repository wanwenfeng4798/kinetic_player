package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.util.AttributeSet
import android.view.View
import com.shuyu.gsyvideoplayer.utils.CommonUtil
import com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer
import com.shuyu.gsyvideoplayer.video.base.GSYBaseVideoPlayer

/**
 * [StandardGSYVideoPlayer] for Flutter PlatformView with native-default behavior.
 */
open class KineticGSYVideoPlayer : StandardGSYVideoPlayer {

    constructor(context: Context) : super(context)

    constructor(context: Context, fullFlag: Boolean) : super(context, fullFlag)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    var uiConfig: GsyUiConfig = GsyUiConfig()
        set(value) {
            field = value
            applyUiConfig()
        }

    override fun init(context: Context) {
        super.init(context)
        wireNativeControls()
        applyUiConfig()
    }

    private fun wireNativeControls() {
        fullscreenButton?.setOnClickListener {
            toggleWindowFullscreen()
        }
    }

    fun applyUiConfig() {
        setIsTouchWiget(uiConfig.enableNativeControls)
        setIsTouchWigetFull(uiConfig.enableNativeControlsFullscreen)
        setRotateViewAuto(uiConfig.rotateViewAuto)
        setRotateWithSystem(uiConfig.rotateWithSystem)
        setLockLand(uiConfig.lockLand)
        setNeedOrientationUtils(uiConfig.needOrientationUtils)
        setShowFullAnimation(uiConfig.showFullAnimation)
        setHideKey(uiConfig.hideVirtualKey)
        setShowPauseCover(uiConfig.showPauseCover)
        setNeedShowWifiTip(uiConfig.needShowWifiTip)
        setSurfaceErrorPlay(uiConfig.surfaceErrorPlay)
        setReleaseWhenLossAudio(uiConfig.releaseWhenLossAudio)
        setShowDragProgressTextOnSeekBar(uiConfig.showDragProgressTextOnSeekBar)
        setDismissControlTime(uiConfig.dismissControlTime)
        setSeekRatio(uiConfig.seekRatio)
        setSpeed(uiConfig.speed, false)
        setLooping(uiConfig.looping)
        setAutoFullWithSize(uiConfig.autoFullWithSize)
        setNeedLockFull(uiConfig.showLockButton)
        if (uiConfig.seekOnStartMs >= 0) {
            setSeekOnStart(uiConfig.seekOnStartMs)
        }
        titleTextView?.text = uiConfig.videoTitle
        applyEmbeddedChrome()
    }

    fun toggleWindowFullscreen() {
        val activity = CommonUtil.scanForActivity(context) as? Activity ?: return
        if (isIfCurrentIsFullscreen) {
            clearFullscreenLayout()
        } else {
            startWindowFullscreen(
                activity,
                uiConfig.fullHideActionBar,
                uiConfig.fullHideStatusBar,
            )
        }
    }

    fun dispatchConfigurationChanged(
        activity: Activity,
        newConfig: Configuration,
    ) {
        onConfigurationChanged(
            activity,
            newConfig,
            mOrientationUtils,
            uiConfig.fullHideActionBar,
            uiConfig.fullHideStatusBar,
        )
    }

    override fun cloneParams(
        from: GSYBaseVideoPlayer?,
        to: GSYBaseVideoPlayer?,
    ) {
        super.cloneParams(from, to)
        val fromPlayer = from as? KineticGSYVideoPlayer ?: return
        val toPlayer = to as? KineticGSYVideoPlayer ?: return
        toPlayer.uiConfig = fromPlayer.uiConfig
    }

    override fun startWindowFullscreen(
        context: Context,
        actionBar: Boolean,
        statusBar: Boolean,
    ): GSYBaseVideoPlayer? {
        val player = super.startWindowFullscreen(context, actionBar, statusBar) ?: return null
        (player as? KineticGSYVideoPlayer)?.applyUiConfig()
        return player
    }

    override fun clearFullscreenLayout() {
        super.clearFullscreenLayout()
        post { applyEmbeddedChrome() }
    }

    private fun applyEmbeddedChrome() {
        if (!isIfCurrentIsFullscreen) {
            backButton?.visibility = View.GONE
        }
        fullscreenButton?.visibility =
            if (uiConfig.showFullscreenButton) View.VISIBLE else View.GONE
    }
}
