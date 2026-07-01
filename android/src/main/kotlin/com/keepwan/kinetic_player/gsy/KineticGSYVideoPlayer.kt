package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.graphics.Color
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.shuyu.gsyvideoplayer.utils.CommonUtil
import com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer
import com.shuyu.gsyvideoplayer.video.base.GSYBaseVideoPlayer
import com.keepwan.kinetic_player.R

/**
 * [StandardGSYVideoPlayer] for Flutter PlatformView with native-default behavior.
 */
open class KineticGSYVideoPlayer : StandardGSYVideoPlayer {

    constructor(context: Context) : super(context)

    constructor(context: Context, fullFlag: Boolean) : super(context, fullFlag)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    protected var storedUiConfig: GsyUiConfig? = null

    /** Wired by [GsyNativePlayer] to keep danmaku in sync with native play/pause/replay. */
    var onDanmakuPlaybackStart: (() -> Unit)? = null
    var onDanmakuPlaybackPause: (() -> Unit)? = null
    var onDanmakuPlaybackComplete: (() -> Unit)? = null

    /** Invoked when the native volume toolbar changes volume (0.0–1.0). */
    var onVolumeChanged: ((Float) -> Unit)? = null

    /** Invoked when the native volume icon toggles mute. */
    var onMuteToggle: ((Boolean) -> Unit)? = null

    /** Supplies audio tracks when the settings panel opens. */
    var onRequestAudioTracks: (() -> List<Map<String, Any?>>)? = null

    /** Invoked when the user picks an audio track in the settings panel. */
    var onAudioTrackSelected: ((Int) -> Unit)? = null

    private var audioPanel: View? = null
    private var settingsPanel: View? = null
    private var volumeTrigger: ImageView? = null
    private var settingsTrigger: ImageView? = null
    private var audioPanelVolumeSeekBar: SeekBar? = null
    private var settingsPanelTrackList: LinearLayout? = null
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var volumeUiSyncing = false
    internal var volumeToolbarMuted = false
    internal var volumeToolbarLevel = 1f

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
        wireAudioPanel()
        wireSettingsPanel()
        applyUiConfig()
    }

    private fun wireSettingsPanel() {
        settingsPanel = findViewById(R.id.settings_panel)
        settingsTrigger = findViewById(R.id.settings_trigger)
        settingsPanelTrackList = findViewById(R.id.settings_panel_track_list)
        settingsTrigger?.setOnClickListener { toggleSettingsPanel() }
    }

    private fun wireAudioPanel() {
        audioPanel = findViewById(R.id.audio_panel)
        volumeTrigger = findViewById(R.id.volume_trigger)
        audioPanelVolumeSeekBar = findViewById(R.id.audio_panel_volume)
        audioPanelVolumeSeekBar?.progress = (volumeToolbarLevel * 100).toInt()
        updateVolumeIcon()
        audioPanelVolumeSeekBar?.setOnSeekBarChangeListener(
            object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(
                    seekBar: SeekBar?,
                    progress: Int,
                    fromUser: Boolean,
                ) {
                    if (!fromUser || volumeUiSyncing) return
                    volumeToolbarMuted = progress == 0
                    volumeToolbarLevel = progress / 100f
                    updateVolumeIcon()
                    if (progress > 0 && volumeToolbarMuted) {
                        volumeToolbarMuted = false
                        onMuteToggle?.invoke(false)
                    }
                    onVolumeChanged?.invoke(volumeToolbarLevel)
                }

                override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit

                override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
            },
        )
        volumeTrigger?.setOnClickListener { toggleAudioPanel() }
    }

    private fun toggleAudioPanel() {
        if (audioPanelVisible) {
            hideAudioPanel()
        } else {
            hideSettingsPanel()
            showAudioPanel()
        }
    }

    private fun toggleSettingsPanel() {
        if (settingsPanelVisible) {
            hideSettingsPanel()
        } else {
            hideAudioPanel()
            showSettingsPanel()
        }
    }

    private fun showAudioPanel() {
        audioPanel?.visibility = View.VISIBLE
        audioPanelVisible = true
        audioPanel?.bringToFront()
    }

    fun hideAudioPanel() {
        audioPanel?.visibility = View.GONE
        audioPanelVisible = false
    }

    private fun showSettingsPanel() {
        refreshSettingsTracks()
        settingsPanel?.visibility = View.VISIBLE
        settingsPanelVisible = true
        settingsPanel?.bringToFront()
    }

    fun hideSettingsPanel() {
        settingsPanel?.visibility = View.GONE
        settingsPanelVisible = false
    }

    private fun refreshSettingsTracks() {
        val trackList = settingsPanelTrackList ?: return
        trackList.removeAllViews()
        val tracks = onRequestAudioTracks?.invoke().orEmpty()
        if (tracks.isEmpty()) {
            val empty =
                TextView(context).apply {
                    text = context.getString(R.string.kinetic_no_audio_tracks)
                    setTextColor(Color.parseColor("#99FFFFFF"))
                    textSize = 12f
                }
            trackList.addView(empty)
            return
        }
        val activeColor = ContextCompat.getColor(context, R.color.kinetic_seek_active)
        val padV = CommonUtil.dip2px(context, 8f)
        for (track in tracks) {
            val index = track["index"] as? Int ?: continue
            val label = track["label"] as? String ?: "Track $index"
            val language = track["language"] as? String
            val selected = track["selected"] as? Boolean == true
            val title = if (!language.isNullOrEmpty()) "$label ($language)" else label
            val item =
                TextView(context).apply {
                    text = title
                    setPadding(0, padV, 0, padV)
                    textSize = 13f
                    setTextColor(if (selected) activeColor else Color.WHITE)
                    setOnClickListener {
                        onAudioTrackSelected?.invoke(index)
                        refreshSettingsTracks()
                    }
                }
            trackList.addView(item)
        }
    }

    fun syncVolumeToolbar(
        volume: Float,
        muted: Boolean,
    ) {
        volumeToolbarLevel = volume.coerceIn(0f, 1f)
        volumeToolbarMuted = muted
        volumeUiSyncing = true
        audioPanelVolumeSeekBar?.progress =
            if (muted) {
                0
            } else {
                (volumeToolbarLevel * 100).toInt().coerceIn(0, 100)
            }
        updateVolumeIcon()
        volumeUiSyncing = false
    }

    private fun updateVolumeIcon() {
        val iconRes =
            if (volumeToolbarMuted || (audioPanelVolumeSeekBar?.progress ?: 0) == 0) {
                R.drawable.kinetic_ic_volume_off
            } else {
                R.drawable.kinetic_ic_volume_on
            }
        volumeTrigger?.setImageResource(iconRes)
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
        volumeTrigger?.visibility =
            if (config.showVolumeToolbar) View.VISIBLE else View.GONE
        settingsTrigger?.visibility =
            if (config.showSettingsButton) View.VISIBLE else View.GONE
        if (!config.showVolumeToolbar) {
            hideAudioPanel()
        }
        if (!config.showSettingsButton) {
            hideSettingsPanel()
        }
        applyEmbeddedChrome()
        fixControlOverlayLayering()
    }

    /** Keep play/pause chrome above GLSurfaceView and let taps reach GSY controls. */
    fun fixControlOverlayLayering() {
        val renderView = renderProxy?.showView
        if (renderView is GLSurfaceView) {
            renderView.setZOrderMediaOverlay(true)
            // GL surface otherwise intercepts taps so play/pause never toggles.
            renderView.isClickable = false
            renderView.isFocusable = false
            renderView.isFocusableInTouchMode = false
        }
        mTopContainer?.bringToFront()
        mBottomContainer?.bringToFront()
        mStartButton?.bringToFront()
        mLockScreen?.bringToFront()
        mLoadingProgressBar?.bringToFront()
        if (audioPanelVisible) {
            audioPanel?.bringToFront()
        }
        if (settingsPanelVisible) {
            settingsPanel?.bringToFront()
        }
    }

    override fun onLayout(
        changed: Boolean,
        left: Int,
        top: Int,
        right: Int,
        bottom: Int,
    ) {
        super.onLayout(changed, left, top, right, bottom)
        if (renderProxy?.showView is GLSurfaceView) {
            post { fixControlOverlayLayering() }
        }
    }

    override fun changeUiToPlayingShow() {
        super.changeUiToPlayingShow()
        fixControlOverlayLayering()
    }

    override fun changeUiToPlayingClear() {
        hideAudioPanel()
        hideSettingsPanel()
        super.changeUiToPlayingClear()
    }

    override fun changeUiToPauseShow() {
        super.changeUiToPauseShow()
        fixControlOverlayLayering()
    }

    override fun changeUiToPauseClear() {
        hideAudioPanel()
        hideSettingsPanel()
        super.changeUiToPauseClear()
    }

    override fun changeUiToCompleteShow() {
        super.changeUiToCompleteShow()
        fixControlOverlayLayering()
    }

    override fun onClickUiToggle() {
        hideAudioPanel()
        hideSettingsPanel()
        super.onClickUiToggle()
    }

    override fun startPlayLogic() {
        super.startPlayLogic()
        onDanmakuPlaybackStart?.invoke()
    }

    override fun onVideoPause() {
        super.onVideoPause()
        onDanmakuPlaybackPause?.invoke()
    }

    override fun onVideoResume() {
        super.onVideoResume()
        onDanmakuPlaybackStart?.invoke()
    }

    override fun onVideoResume(seek: Boolean) {
        super.onVideoResume(seek)
        onDanmakuPlaybackStart?.invoke()
    }

    override fun onAutoCompletion() {
        super.onAutoCompletion()
        onDanmakuPlaybackComplete?.invoke()
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
        toPlayer.onVolumeChanged = fromPlayer.onVolumeChanged
        toPlayer.onMuteToggle = fromPlayer.onMuteToggle
        toPlayer.onRequestAudioTracks = fromPlayer.onRequestAudioTracks
        toPlayer.onAudioTrackSelected = fromPlayer.onAudioTrackSelected
        toPlayer.syncVolumeToolbar(fromPlayer.volumeToolbarLevel, fromPlayer.volumeToolbarMuted)
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
