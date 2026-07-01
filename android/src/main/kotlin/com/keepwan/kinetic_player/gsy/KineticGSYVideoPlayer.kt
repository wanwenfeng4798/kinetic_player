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

    protected var storedUiConfig: GsyUiConfig? = null

    var uiConfig: GsyUiConfig
        get() = storedUiConfig ?: DEFAULT_UI_CONFIG
        set(value) {
            storedUiConfig = value ?: DEFAULT_UI_CONFIG
            applyUiConfig()
        }

    override fun init(context: Context) {
        // GSY calls init() from its superclass constructor before Kotlin field
        // initializers run; ensure config exists before super.init() continues.
        if (storedUiConfig == null) {
            storedUiConfig = DEFAULT_UI_CONFIG
        }
        super.init(context)
        wireNativeControls()
        applyUiConfig()
    }

    private fun wireNativeControls() {
        fullscreenButton?.setOnClickListener {
            toggleWindowFullscreen()
        }
    }

    open fun applyUiConfig() {
        val config = storedUiConfig ?: DEFAULT_UI_CONFIG
        setIsTouchWiget(config.enableNativeControls)
        setIsTouchWigetFull(config.enableNativeControlsFullscreen)
        setRotateViewAuto(config.rotateViewAuto)
        setRotateWithSystem(config.rotateWithSystem)
        setLockLand(config.lockLand)
        setNeedOrientationUtils(config.needOrientationUtils)
        setShowFullAnimation(config.showFullAnimation)
        setHideKey(config.hideVirtualKey)
        setShowPauseCover(config.showPauseCover)
        setNeedShowWifiTip(config.needShowWifiTip)
        setSurfaceErrorPlay(config.surfaceErrorPlay)
        setReleaseWhenLossAudio(config.releaseWhenLossAudio)
        setShowDragProgressTextOnSeekBar(config.showDragProgressTextOnSeekBar)
        setDismissControlTime(config.dismissControlTime)
        setSeekRatio(config.seekRatio)
        setSpeed(config.speed, false)
        setLooping(config.looping)
        setAutoFullWithSize(config.autoFullWithSize)
        setNeedLockFull(config.showLockButton)
        if (config.seekOnStartMs >= 0) {
            setSeekOnStart(config.seekOnStartMs)
        }
        titleTextView?.text = config.videoTitle
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
        val config = storedUiConfig ?: DEFAULT_UI_CONFIG
        if (!isIfCurrentIsFullscreen) {
            backButton?.visibility = View.GONE
        }
        fullscreenButton?.visibility =
            if (config.showFullscreenButton) View.VISIBLE else View.GONE
    }

    companion object {
        private val DEFAULT_UI_CONFIG = GsyUiConfig()
    }
}
