package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.keepwan.kinetic_player.R
import com.shuyu.gsyvideoplayer.utils.CommonUtil
import com.shuyu.gsyvideoplayer.utils.Debuger
import com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer
import com.shuyu.gsyvideoplayer.video.base.GSYBaseVideoPlayer
import moe.codeest.enviews.ENDownloadView
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

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

    private var overlayDanmaku: GsyDanmakuController? = null
    private var overlayDanmakuUrl: String? = null
    private var overlayDanmakuVisible = false
    private var overlayWatermarkUrl: String? = null
    private var overlayWatermarkBitmap: android.graphics.Bitmap? = null
    private var overlayEffectName: String = "none"
    private var overlayRenderRotation = 0
    private var overlayMirrorHorizontal = false
    private var overlayMirrorVertical = false
    private var overlaySubtitleUrl: String? = null
    private var overlaySubtitleMime: String? = null
    private var overlaySubtitleEnabled = true
    private var overlayAdPlaying = false
    private var overlayAdSkipAfterMs = 5_000L
    private var overlayOnAdSkip: (() -> Unit)? = null

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
    private var audioPanelVolumeValue: TextView? = null
    private var settingsPanelTrackList: LinearLayout? = null
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var volumeUiSyncing = false
    private var volumeDragging = false
    private var gestureDownPlayerVolume = 1f
    internal var volumeToolbarMuted = false
    internal var volumeToolbarLevel = 1f

    private var keepLastFrameWhenComplete = false
    private var lastAutoCompleteRetainedSurface = false
    private var coverUrl: String? = null
    private var coverLoadGeneration = 0
    private val coverMainHandler = Handler(Looper.getMainLooper())
    private val coverExecutor = Executors.newSingleThreadExecutor()

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
        audioPanelVolumeValue = findViewById(R.id.audio_panel_volume_value)
        audioPanelVolumeSeekBar?.progress = (volumeToolbarLevel * 100).toInt()
        updateVolumeIcon()
        (audioPanel as? ViewGroup)?.apply {
            clipChildren = false
            clipToPadding = false
        }
        audioPanel?.setOnTouchListener { view, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN ||
                event.actionMasked == MotionEvent.ACTION_MOVE
            ) {
                view.parent?.requestDisallowInterceptTouchEvent(true)
            }
            false
        }
        audioPanelVolumeSeekBar?.setOnTouchListener { view, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN ||
                event.actionMasked == MotionEvent.ACTION_MOVE
            ) {
                view.parent?.requestDisallowInterceptTouchEvent(true)
            }
            false
        }
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
                    updateVolumeValueLabel(progress)
                    if (progress > 0 && volumeToolbarMuted) {
                        volumeToolbarMuted = false
                        onMuteToggle?.invoke(false)
                    }
                    onVolumeChanged?.invoke(volumeToolbarLevel)
                }

                override fun onStartTrackingTouch(seekBar: SeekBar?) {
                    volumeDragging = true
                    val progress = seekBar?.progress ?: 0
                    showVolumeValueLabel(progress)
                }

                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    volumeDragging = false
                    hideVolumeValueLabel()
                }
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
        positionPanelCenteredAboveAnchor(
            panel = audioPanel,
            anchor = volumeTrigger,
            panelWidthRes = R.dimen.kinetic_audio_panel_width,
        )
        audioPanel?.bringToFront()
        syncGestureVolumeDuringPanelInteraction()
    }

    fun hideAudioPanel() {
        audioPanel?.visibility = View.GONE
        audioPanelVisible = false
        volumeDragging = false
        hideVolumeValueLabel()
        syncGestureVolumeDuringPanelInteraction()
    }

    private fun showSettingsPanel() {
        refreshSettingsTracks()
        settingsPanel?.visibility = View.VISIBLE
        settingsPanelVisible = true
        positionSettingsPanelAboveBottomBar()
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
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    setTextColor(if (selected) activeColor else Color.WHITE)
                    layoutParams =
                        LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        )
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
        if (volumeDragging) {
            updateVolumeValueLabel(
                audioPanelVolumeSeekBar?.progress ?: (volumeToolbarLevel * 100).toInt(),
            )
        } else {
            hideVolumeValueLabel()
        }
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

    private fun showVolumeValueLabel(progress: Int) {
        audioPanelVolumeValue?.apply {
            text = formatVolumePercent(progress)
            visibility = View.VISIBLE
        }
    }

    private fun updateVolumeValueLabel(progress: Int) {
        if (audioPanelVolumeValue?.visibility != View.VISIBLE) return
        audioPanelVolumeValue?.text = formatVolumePercent(progress)
    }

    private fun hideVolumeValueLabel() {
        audioPanelVolumeValue?.visibility = View.GONE
    }

    private fun formatVolumePercent(progress: Int): String =
        "${progress.coerceIn(0, 100)}%"

    private fun wireNativeControls() {
        // Keep GSY default video_enlarge / video_shrink so icon size matches stock chrome.
        fullscreenButton?.scaleType = ImageView.ScaleType.CENTER
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
        setThumbPlay(config.thumbPlay)
        setKeepLastFrameWhenComplete(config.keepLastFrameWhenComplete)
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
        setCoverUrl(config.coverUrl)
        syncGestureVolumeDuringPanelInteraction()
        applyEmbeddedChrome()
        fixControlOverlayLayering()
    }

    fun setKeepLastFrameWhenComplete(enabled: Boolean) {
        keepLastFrameWhenComplete = enabled
    }

    fun isKeepLastFrameWhenComplete(): Boolean = keepLastFrameWhenComplete

    fun setCoverUrl(url: String?) {
        if (url.isNullOrBlank()) {
            coverUrl = null
            coverLoadGeneration++
            clearThumbImageView()
            return
        }
        if (url == coverUrl && thumbImageView != null) {
            return
        }
        coverUrl = url
        val imageView =
            ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                layoutParams =
                    ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
            }
        setThumbImageView(imageView)
        val generation = ++coverLoadGeneration
        coverExecutor.execute {
            val bitmap =
                try {
                    decodeCoverBitmap(url)
                } catch (_: Exception) {
                    null
                }
            if (bitmap == null) return@execute
            coverMainHandler.post {
                if (generation != coverLoadGeneration) {
                    bitmap.recycle()
                    return@post
                }
                (thumbImageView as? ImageView)?.setImageBitmap(bitmap)
            }
        }
    }

    private fun decodeCoverBitmap(url: String) =
        when {
            url.startsWith("http://", ignoreCase = true) ||
                url.startsWith("https://", ignoreCase = true) -> {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.connect()
                connection.inputStream.use { BitmapFactory.decodeStream(it) }
            }
            url.startsWith("file://", ignoreCase = true) -> {
                val path = android.net.Uri.parse(url).path ?: return null
                BitmapFactory.decodeFile(path)
            }
            java.io.File(url).isFile -> BitmapFactory.decodeFile(url)
            else ->
                context.contentResolver
                    .openInputStream(android.net.Uri.parse(url))
                    ?.use { BitmapFactory.decodeStream(it) }
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
            positionPanelCenteredAboveAnchor(
                panel = audioPanel,
                anchor = volumeTrigger,
                panelWidthRes = R.dimen.kinetic_audio_panel_width,
            )
        }
        if (settingsPanelVisible) {
            settingsPanel?.bringToFront()
            positionSettingsPanelAboveBottomBar()
        }
        syncBottomChromeTouchPassthrough()
    }

    /** Centers popup horizontally over an anchor in the bottom control row. */
    private fun positionPanelCenteredAboveAnchor(
        panel: View?,
        anchor: View?,
        panelWidthRes: Int,
    ) {
        val panelView = panel ?: return
        val anchorView = anchor ?: return
        val host = panelView.parent as? RelativeLayout ?: return
        val panelWidthPx = resources.getDimensionPixelSize(panelWidthRes)
        val bottomMarginPx =
            resources.getDimensionPixelSize(R.dimen.kinetic_panel_popup_margin_bottom)
        panelView.post {
            if (!panelView.isShown) return@post
            if (host.width == 0 || anchorView.width == 0) {
                panelView.post {
                    positionPanelCenteredAboveAnchor(panel, anchor, panelWidthRes)
                }
                return@post
            }
            val measuredWidth = if (panelView.width > 0) panelView.width else panelWidthPx
            val hostLoc = IntArray(2)
            val anchorLoc = IntArray(2)
            host.getLocationInWindow(hostLoc)
            anchorView.getLocationInWindow(anchorLoc)
            val anchorLeft = anchorLoc[0] - hostLoc[0]
            val centeredLeft = anchorLeft + (anchorView.width - measuredWidth) / 2
            val maxLeft = (host.width - measuredWidth).coerceAtLeast(0)
            val lp = panelView.layoutParams as RelativeLayout.LayoutParams
            lp.width = panelWidthPx
            lp.addRule(RelativeLayout.ABOVE, R.id.layout_bottom)
            lp.addRule(RelativeLayout.ALIGN_PARENT_START)
            lp.removeRule(RelativeLayout.ALIGN_START)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_END)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_LEFT)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_RIGHT)
            lp.leftMargin = centeredLeft.coerceIn(0, maxLeft)
            lp.rightMargin = 0
            lp.bottomMargin = bottomMarginPx
            panelView.layoutParams = lp
            panelView.requestLayout()
        }
    }

    /** Matches iOS: settings sheet trailing inset 12dp, above bottom bar. */
    private fun positionSettingsPanelAboveBottomBar() {
        val panelView = settingsPanel ?: return
        val host = panelView.parent as? RelativeLayout ?: return
        val panelWidthPx =
            resources.getDimensionPixelSize(R.dimen.kinetic_settings_panel_width)
        val marginEndPx = CommonUtil.dip2px(context, 12f)
        val bottomMarginPx =
            resources.getDimensionPixelSize(R.dimen.kinetic_panel_popup_margin_bottom)
        panelView.post {
            if (!panelView.isShown) return@post
            val lp = panelView.layoutParams as RelativeLayout.LayoutParams
            lp.width = panelWidthPx
            lp.addRule(RelativeLayout.ABOVE, R.id.layout_bottom)
            lp.addRule(RelativeLayout.ALIGN_PARENT_END)
            lp.removeRule(RelativeLayout.ALIGN_START)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_START)
            lp.leftMargin = 0
            lp.rightMargin = marginEndPx
            lp.bottomMargin = bottomMarginPx
            panelView.layoutParams = lp
            panelView.requestLayout()
        }
    }

    /**
     * GSY keeps the bottom bar INVISIBLE when controls hide, but it still intercepts touches
     * on the lower-right region. Forward those taps to [onClickUiToggle].
     */
    private fun syncBottomChromeTouchPassthrough() {
        val bottom = mBottomContainer ?: return
        val controlsVisible = bottom.visibility == View.VISIBLE
        if (controlsVisible) {
            bottom.setOnTouchListener(null)
            bottom.isClickable = true
            return
        }
        bottom.isClickable = false
        bottom.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                onClickUiToggle(event)
            }
            true
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
        syncBottomChromeTouchPassthrough()
    }

    override fun changeUiToPauseShow() {
        super.changeUiToPauseShow()
        fixControlOverlayLayering()
    }

    override fun changeUiToPauseClear() {
        hideAudioPanel()
        hideSettingsPanel()
        super.changeUiToPauseClear()
        syncBottomChromeTouchPassthrough()
    }

    override fun onClickUiToggle(event: MotionEvent) {
        hideAudioPanel()
        hideSettingsPanel()
        super.onClickUiToggle(event)
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
        if (!keepLastFrameWhenComplete) {
            lastAutoCompleteRetainedSurface = false
            super.onAutoCompletion()
            onDanmakuPlaybackComplete?.invoke()
            return
        }

        lastAutoCompleteRetainedSurface =
            mTextureViewContainer != null && mTextureViewContainer.childCount > 0

        setStateAndUi(CURRENT_STATE_AUTO_COMPLETE)

        mSaveChangeViewTIme = 0
        mCurrentPosition = 0

        if (!mIfCurrentIsFullscreen) {
            gsyVideoManager.setLastListener(null)
        }

        mAudioFocusManager?.abandonAudioFocus()
        if (mContext is Activity) {
            try {
                (mContext as Activity).window.clearFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                )
            } catch (_: Exception) {
                // ignore
            }
        }
        releaseNetWorkState()

        if (mVideoAllCallBack != null && isCurrentMediaListener) {
            Debuger.printfLog("onAutoComplete keepLastFrame")
            mVideoAllCallBack.onAutoComplete(mOriginUrl, mTitle, this)
        }
        mHadPlay = false
        onDanmakuPlaybackComplete?.invoke()
    }

    override fun onCompletion() {
        lastAutoCompleteRetainedSurface = false
        super.onCompletion()
    }

    override fun startButtonLogic() {
        lastAutoCompleteRetainedSurface = false
        super.startButtonLogic()
    }

    override fun changeUiToCompleteShow() {
        if (!keepLastFrameWhenComplete) {
            super.changeUiToCompleteShow()
            return
        }

        Debuger.printfLog("changeUiToCompleteShow keepLastFrame")

        setViewShowState(mTopContainer, VISIBLE)
        setViewShowState(mBottomContainer, VISIBLE)
        setViewShowState(mStartButton, VISIBLE)
        setViewShowState(mLoadingProgressBar, INVISIBLE)
        setViewShowState(mThumbImageViewLayout, INVISIBLE)
        setViewShowState(mBottomProgressBar, INVISIBLE)
        setViewShowState(
            mLockScreen,
            if (mIfCurrentIsFullscreen && mNeedLockFull) VISIBLE else GONE,
        )

        (mLoadingProgressBar as? ENDownloadView)?.reset()
        updateStartImage()
        fixControlOverlayLayering()
    }

    override fun touchSurfaceMoveFullLogic(absDeltaX: Float, absDeltaY: Float) {
        val wasChangingVolume = mChangeVolume
        super.touchSurfaceMoveFullLogic(absDeltaX, absDeltaY)
        if (shouldBlockGestureVolume()) {
            mChangeVolume = false
            dismissVolumeDialog()
            return
        }
        if (isCustomVolumeToolbarEnabled() && mChangeVolume && !wasChangingVolume) {
            gestureDownPlayerVolume =
                if (volumeToolbarMuted) {
                    0f
                } else {
                    volumeToolbarLevel
                }
        }
    }

    override fun touchSurfaceMove(
        deltaX: Float,
        deltaY: Float,
        y: Float,
    ) {
        if (shouldBlockGestureVolume()) {
            if (mChangeVolume) {
                mChangeVolume = false
                dismissVolumeDialog()
            }
            super.touchSurfaceMove(deltaX, deltaY, y)
            return
        }
        if (isCustomVolumeToolbarEnabled() && mChangeVolume) {
            applyPlayerVolumeGesture(deltaY)
            return
        }
        super.touchSurfaceMove(deltaX, deltaY, y)
    }

    /**
     * Custom volume toolbar uses player volume; map swipe gestures to the same path
     * instead of system [android.media.AudioManager] volume.
     */
    private fun applyPlayerVolumeGesture(deltaY: Float) {
        val curHeight =
            if (getActivityContext() != null) {
                val activity = getActivityContext() as Activity
                if (CommonUtil.getCurrentScreenLand(activity)) mScreenWidth else mScreenHeight
            } else {
                mScreenHeight
            }
        if (curHeight <= 0) return
        val adjustedDeltaY = -deltaY
        val volumePercent =
            (
                gestureDownPlayerVolume * 100 + adjustedDeltaY * 3 * 100 / curHeight
            ).toInt().coerceIn(0, 100)
        onVolumeChanged?.invoke(volumePercent / 100f)
        showVolumeDialog(-adjustedDeltaY, volumePercent)
    }

    /** Block swipe volume only while the vertical volume popup is open or being dragged. */
    private fun shouldBlockGestureVolume(): Boolean = audioPanelVisible || volumeDragging

    private fun isCustomVolumeToolbarEnabled(): Boolean = uiConfig.showVolumeToolbar

    private fun syncGestureVolumeDuringPanelInteraction() {
        if (shouldBlockGestureVolume()) {
            mChangeVolume = false
            dismissVolumeDialog()
        }
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

    fun setOverlayDanmakuUrl(url: String?) {
        overlayDanmakuUrl = url
        ensureDanmakuController()
        if (!url.isNullOrEmpty()) {
            overlayDanmaku?.loadFromUrl(url)
            overlayDanmaku?.setVisible(overlayDanmakuVisible)
        }
    }

    fun setOverlayDanmakuVisible(visible: Boolean) {
        overlayDanmakuVisible = visible
        ensureDanmakuController()
        overlayDanmaku?.setVisible(visible)
    }

    fun getOverlayDanmaku(): GsyDanmakuController? {
        ensureDanmakuController()
        return overlayDanmaku
    }

    fun setOverlayWatermarkUrl(url: String?) {
        overlayWatermarkUrl = url
        val image = findViewById<ImageView>(R.id.kinetic_watermark) ?: return
        if (url.isNullOrEmpty()) {
            overlayWatermarkBitmap = null
            image.setImageBitmap(null)
            image.visibility = View.GONE
            return
        }
        image.visibility = View.VISIBLE
        coverExecutor.execute {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.connect()
                val bitmap = BitmapFactory.decodeStream(connection.inputStream)
                coverMainHandler.post {
                    if (overlayWatermarkUrl != url) return@post
                    overlayWatermarkBitmap = bitmap
                    image.setImageBitmap(bitmap)
                    image.visibility = View.VISIBLE
                }
            } catch (_: Exception) {
                // ignore
            }
        }
    }

    fun setOverlayEffectName(name: String) {
        overlayEffectName = name
        setEffectFilter(GsyEffectRegistry.resolve(name))
    }

    fun setOverlayRenderTransform(
        rotation: Int,
        mirrorH: Boolean,
        mirrorV: Boolean,
    ) {
        overlayRenderRotation = ((rotation % 360) + 360) % 360
        overlayMirrorHorizontal = mirrorH
        overlayMirrorVertical = mirrorV
        applyOverlayRenderTransform()
    }

    fun setOverlaySubtitle(
        url: String?,
        mimeType: String?,
        enabled: Boolean,
    ) {
        overlaySubtitleUrl = url
        overlaySubtitleMime = mimeType
        overlaySubtitleEnabled = enabled
        if (!url.isNullOrEmpty()) {
            val builder = com.shuyu.gsyvideoplayer.subtitle.GSYSubtitleSource.Builder(url)
            if (!mimeType.isNullOrEmpty()) {
                builder.setMimeType(mimeType)
            }
            setSubtitleSource(builder.build())
        }
        setSubtitleEnabled(enabled)
    }

    fun showAdChrome(
        skipAfterMs: Long,
        onSkip: () -> Unit,
    ) {
        overlayAdPlaying = true
        overlayAdSkipAfterMs = skipAfterMs
        overlayOnAdSkip = onSkip
        val overlay = findViewById<View>(R.id.kinetic_ad_overlay) ?: return
        val skip = findViewById<TextView>(R.id.kinetic_ad_skip)
        val countdown = findViewById<TextView>(R.id.kinetic_ad_countdown)
        overlay.visibility = View.VISIBLE
        skip?.visibility = View.GONE
        countdown?.visibility = View.VISIBLE
        skip?.setOnClickListener {
            overlayOnAdSkip?.invoke()
        }
        val startedAt = System.currentTimeMillis()
        val ticker =
            object : Runnable {
                override fun run() {
                    if (!overlayAdPlaying) return
                    val elapsed = System.currentTimeMillis() - startedAt
                    val remain = ((skipAfterMs - elapsed) / 1000L).coerceAtLeast(0L)
                    if (remain > 0) {
                        countdown?.text = context.getString(R.string.kinetic_ad_countdown, remain)
                        countdown?.visibility = View.VISIBLE
                        skip?.visibility = View.GONE
                        coverMainHandler.postDelayed(this, 250L)
                    } else {
                        countdown?.visibility = View.GONE
                        skip?.visibility = View.VISIBLE
                    }
                }
            }
        coverMainHandler.post(ticker)
    }

    fun hideAdChrome() {
        overlayAdPlaying = false
        overlayOnAdSkip = null
        findViewById<View>(R.id.kinetic_ad_overlay)?.visibility = View.GONE
        findViewById<TextView>(R.id.kinetic_ad_skip)?.visibility = View.GONE
        findViewById<TextView>(R.id.kinetic_ad_countdown)?.visibility = View.GONE
    }

    private fun ensureDanmakuController() {
        if (overlayDanmaku != null) return
        overlayDanmaku = GsyDanmakuController(this).also { it.attachIfNeeded() }
    }

    private fun applyOverlayRenderTransform() {
        val proxy = getRenderProxy() ?: return
        val renderView = proxy.showView ?: return
        if (renderView.width <= 0 || renderView.height <= 0) {
            post { applyOverlayRenderTransform() }
            return
        }
        proxy.setTransform(android.graphics.Matrix())
        renderView.pivotX = renderView.width / 2f
        renderView.pivotY = renderView.height / 2f
        proxy.setRotation(overlayRenderRotation.toFloat())
        renderView.scaleX = if (overlayMirrorHorizontal) -1f else 1f
        renderView.scaleY = if (overlayMirrorVertical) -1f else 1f
    }

    override fun cloneParams(
        from: GSYBaseVideoPlayer?,
        to: GSYBaseVideoPlayer?,
    ) {
        super.cloneParams(from, to)
        val fromPlayer = from as? KineticGSYVideoPlayer ?: return
        val toPlayer = to as? KineticGSYVideoPlayer ?: return
        toPlayer.keepLastFrameWhenComplete = fromPlayer.keepLastFrameWhenComplete
        toPlayer.lastAutoCompleteRetainedSurface = fromPlayer.lastAutoCompleteRetainedSurface
        toPlayer.uiConfig = fromPlayer.uiConfig
        toPlayer.onVolumeChanged = fromPlayer.onVolumeChanged
        toPlayer.onMuteToggle = fromPlayer.onMuteToggle
        toPlayer.onRequestAudioTracks = fromPlayer.onRequestAudioTracks
        toPlayer.onAudioTrackSelected = fromPlayer.onAudioTrackSelected
        toPlayer.onDanmakuPlaybackStart = fromPlayer.onDanmakuPlaybackStart
        toPlayer.onDanmakuPlaybackPause = fromPlayer.onDanmakuPlaybackPause
        toPlayer.onDanmakuPlaybackComplete = fromPlayer.onDanmakuPlaybackComplete
        toPlayer.syncVolumeToolbar(fromPlayer.volumeToolbarLevel, fromPlayer.volumeToolbarMuted)
        toPlayer.setKeepLastFrameWhenComplete(fromPlayer.keepLastFrameWhenComplete)
        toPlayer.setCoverUrl(fromPlayer.coverUrl)

        toPlayer.overlayDanmakuVisible = fromPlayer.overlayDanmakuVisible
        toPlayer.overlayDanmakuUrl = fromPlayer.overlayDanmakuUrl
        toPlayer.overlayWatermarkUrl = fromPlayer.overlayWatermarkUrl
        toPlayer.overlayWatermarkBitmap = fromPlayer.overlayWatermarkBitmap
        toPlayer.overlayEffectName = fromPlayer.overlayEffectName
        toPlayer.overlayRenderRotation = fromPlayer.overlayRenderRotation
        toPlayer.overlayMirrorHorizontal = fromPlayer.overlayMirrorHorizontal
        toPlayer.overlayMirrorVertical = fromPlayer.overlayMirrorVertical
        toPlayer.overlaySubtitleUrl = fromPlayer.overlaySubtitleUrl
        toPlayer.overlaySubtitleMime = fromPlayer.overlaySubtitleMime
        toPlayer.overlaySubtitleEnabled = fromPlayer.overlaySubtitleEnabled
        toPlayer.overlayAdPlaying = fromPlayer.overlayAdPlaying
        toPlayer.overlayAdSkipAfterMs = fromPlayer.overlayAdSkipAfterMs
        toPlayer.overlayOnAdSkip = fromPlayer.overlayOnAdSkip

        toPlayer.post {
            toPlayer.ensureDanmakuController()
            toPlayer.overlayDanmaku?.rebindToPlayer()
            fromPlayer.overlayDanmakuUrl?.let { toPlayer.setOverlayDanmakuUrl(it) }
            toPlayer.setOverlayDanmakuVisible(fromPlayer.overlayDanmakuVisible)
            val wm = toPlayer.findViewById<ImageView>(R.id.kinetic_watermark)
            if (fromPlayer.overlayWatermarkBitmap != null) {
                wm?.setImageBitmap(fromPlayer.overlayWatermarkBitmap)
                wm?.visibility = View.VISIBLE
            } else if (!fromPlayer.overlayWatermarkUrl.isNullOrEmpty()) {
                toPlayer.setOverlayWatermarkUrl(fromPlayer.overlayWatermarkUrl)
            }
            toPlayer.setOverlayEffectName(fromPlayer.overlayEffectName)
            toPlayer.applyOverlayRenderTransform()
            toPlayer.setOverlaySubtitle(
                fromPlayer.overlaySubtitleUrl,
                fromPlayer.overlaySubtitleMime,
                fromPlayer.overlaySubtitleEnabled,
            )
            if (fromPlayer.overlayAdPlaying) {
                toPlayer.showAdChrome(fromPlayer.overlayAdSkipAfterMs, fromPlayer.overlayOnAdSkip ?: {})
            }
            toPlayer.fixControlOverlayLayering()
        }
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
        post {
            applyEmbeddedChrome()
            // Rebind overlays on the embedded player after leaving fullscreen.
            ensureDanmakuController()
            overlayDanmaku?.rebindToPlayer()
            overlayDanmakuUrl?.let { setOverlayDanmakuUrl(it) }
            setOverlayDanmakuVisible(overlayDanmakuVisible)
            if (overlayWatermarkBitmap != null) {
                findViewById<ImageView>(R.id.kinetic_watermark)?.apply {
                    setImageBitmap(overlayWatermarkBitmap)
                    visibility = View.VISIBLE
                }
            } else if (!overlayWatermarkUrl.isNullOrEmpty()) {
                setOverlayWatermarkUrl(overlayWatermarkUrl)
            }
            applyOverlayRenderTransform()
            if (overlayAdPlaying) {
                showAdChrome(overlayAdSkipAfterMs, overlayOnAdSkip ?: {})
            }
        }
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
