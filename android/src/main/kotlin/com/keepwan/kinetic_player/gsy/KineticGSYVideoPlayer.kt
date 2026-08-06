package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.AttributeSet
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.SeekBar
import android.widget.TextView
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

    /** Supplies Exo video tracks for the quality panel. */
    var onRequestVideoTracks: (() -> List<Map<String, Any?>>)? = null

    /** Invoked when the user picks a video track (`-1` = Auto). */
    var onVideoTrackSelected: ((Int) -> Unit)? = null

    /** Mirror / looping / auto-play / show-type / playlist-next / subtitle / danmaku from chrome. */
    var onMirrorHorizontalChanged: ((Boolean) -> Unit)? = null
    var onLoopingChanged: ((Boolean) -> Unit)? = null
    var onStartAfterPreparedChanged: ((Boolean) -> Unit)? = null
    var onAutoPlayNextChanged: ((Boolean) -> Unit)? = null
    var onShowTypeChanged: ((Int) -> Unit)? = null
    var onSubtitleEnabledChanged: ((Boolean) -> Unit)? = null
    var onDanmakuVisibleChanged: ((Boolean) -> Unit)? = null
    var onDanmakuSend: ((String) -> Unit)? = null

    private var audioPanel: View? = null
    private var settingsPanel: View? = null
    private var ratePanel: View? = null
    private var qualityPanel: View? = null
    private var volumeTrigger: ImageView? = null
    private var toolbarPlayButton: ImageView? = null
    private var settingsTrigger: ImageView? = null
    private var rateTrigger: TextView? = null
    private var qualityTrigger: TextView? = null
    private var audioPanelVolumeSeekBar: SeekBar? = null
    private var audioPanelVolumeValue: TextView? = null
    private var settingsPanelTrackList: LinearLayout? = null
    private var settingsLevel1: View? = null
    private var settingsLevel2: View? = null
    private var ratePanelList: LinearLayout? = null
    private var qualityPanelList: LinearLayout? = null
    private var danmakuBar: View? = null
    private var danmakuToggle: ImageView? = null
    private var subtitleToggle: ImageView? = null
    private var danmakuInput: EditText? = null
    private var danmakuSend: TextView? = null
    private var blackoutOverlay: View? = null
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var ratePanelVisible = false
    private var qualityPanelVisible = false
    private var volumeUiSyncing = false
    private var volumeDragging = false
    private var gestureDownPlayerVolume = 1f
    internal var volumeToolbarMuted = false
    internal var volumeToolbarLevel = 1f

    private var accentColor: Int = GsyUiConfig.DEFAULT_ACCENT_COLOR
    private var chromeRate: Float = 1f
    private var chromeMirrorHorizontal = false
    private var chromeLooping = false
    private var chromeStartAfterPrepared = true
    private var chromeAutoPlayNext = true
    private var chromeShowType = 0
    private var chromeHideBlackBars = false
    private var chromeBlackout = false
    private var chromeQualityAuto = true
    private var chromeQualityLabel = "自动"
    private var showDanmakuChrome = true

    private val rateOptions = floatArrayOf(0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f)

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
        wireRatePanel()
        wireQualityPanel()
        wireDanmakuBar()
        applyUiConfig()
    }

    private fun wireSettingsPanel() {
        settingsPanel = findViewById(R.id.settings_panel)
        settingsTrigger = findViewById(R.id.settings_trigger)
        settingsPanelTrackList = findViewById(R.id.settings_panel_track_list)
        settingsLevel1 = findViewById(R.id.settings_level1)
        settingsLevel2 = findViewById(R.id.settings_level2)
        settingsTrigger?.setOnClickListener { toggleSettingsPanel() }
        findViewById<View>(R.id.settings_row_mirror)?.setOnClickListener {
            chromeMirrorHorizontal = !chromeMirrorHorizontal
            onMirrorHorizontalChanged?.invoke(chromeMirrorHorizontal)
            refreshSettingsLevel1()
        }
        findViewById<View>(R.id.settings_row_loop)?.setOnClickListener {
            chromeLooping = !chromeLooping
            setLooping(chromeLooping)
            onLoopingChanged?.invoke(chromeLooping)
            refreshSettingsLevel1()
        }
        findViewById<View>(R.id.settings_row_auto_play)?.setOnClickListener {
            chromeStartAfterPrepared = !chromeStartAfterPrepared
            onStartAfterPreparedChanged?.invoke(chromeStartAfterPrepared)
            refreshSettingsLevel1()
        }
        findViewById<View>(R.id.settings_row_more)?.setOnClickListener {
            showSettingsLevel(2)
        }
        findViewById<View>(R.id.settings_more_back)?.setOnClickListener {
            showSettingsLevel(1)
        }
        findViewById<View>(R.id.settings_mode_pause)?.setOnClickListener {
            chromeAutoPlayNext = false
            onAutoPlayNextChanged?.invoke(false)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_mode_next)?.setOnClickListener {
            chromeAutoPlayNext = true
            onAutoPlayNextChanged?.invoke(true)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_aspect_auto)?.setOnClickListener {
            chromeShowType = 0
            chromeHideBlackBars = false
            onShowTypeChanged?.invoke(0)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_aspect_16_9)?.setOnClickListener {
            chromeShowType = 1
            chromeHideBlackBars = false
            onShowTypeChanged?.invoke(1)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_aspect_4_3)?.setOnClickListener {
            chromeShowType = 2
            chromeHideBlackBars = false
            onShowTypeChanged?.invoke(2)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_hide_black_bars)?.setOnClickListener {
            chromeHideBlackBars = !chromeHideBlackBars
            val mode = if (chromeHideBlackBars) 3 else chromeShowType
            onShowTypeChanged?.invoke(mode)
            refreshSettingsLevel2()
        }
        findViewById<View>(R.id.settings_blackout)?.setOnClickListener {
            chromeBlackout = !chromeBlackout
            blackoutOverlay?.visibility = if (chromeBlackout) View.VISIBLE else View.GONE
            refreshSettingsLevel2()
        }
    }

    private fun wireRatePanel() {
        ratePanel = findViewById(R.id.rate_panel)
        rateTrigger = findViewById(R.id.rate_trigger)
        ratePanelList = findViewById(R.id.rate_panel_list)
        rateTrigger?.setOnClickListener { toggleRatePanel() }
        updateRateTriggerLabel()
    }

    private fun wireQualityPanel() {
        qualityPanel = findViewById(R.id.quality_panel)
        qualityTrigger = findViewById(R.id.quality_trigger)
        qualityPanelList = findViewById(R.id.quality_panel_list)
        qualityTrigger?.setOnClickListener { toggleQualityPanel() }
        qualityTrigger?.text = chromeQualityLabel
    }

    private fun wireDanmakuBar() {
        danmakuBar = findViewById(R.id.danmaku_bar)
        danmakuToggle = findViewById(R.id.danmaku_toggle)
        subtitleToggle = findViewById(R.id.subtitle_toggle)
        danmakuInput = findViewById(R.id.danmaku_input)
        danmakuSend = findViewById(R.id.danmaku_send)
        blackoutOverlay = findViewById(R.id.kinetic_blackout_overlay)
        danmakuToggle?.setOnClickListener {
            val next = !overlayDanmakuVisible
            setOverlayDanmakuVisible(next)
            onDanmakuVisibleChanged?.invoke(next)
            refreshDanmakuBar()
        }
        subtitleToggle?.setOnClickListener {
            val next = !overlaySubtitleEnabled
            setOverlaySubtitle(overlaySubtitleUrl, overlaySubtitleMime, next)
            onSubtitleEnabledChanged?.invoke(next)
            refreshDanmakuBar()
        }
        danmakuSend?.setOnClickListener { sendDanmakuFromInput() }
        danmakuInput?.setOnEditorActionListener { _, actionId, event ->
            val enter =
                actionId == EditorInfo.IME_ACTION_SEND ||
                    (event?.keyCode == KeyEvent.KEYCODE_ENTER &&
                        event.action == KeyEvent.ACTION_DOWN)
            if (enter) {
                sendDanmakuFromInput()
                true
            } else {
                false
            }
        }
        refreshDanmakuBar()
    }

    private fun sendDanmakuFromInput() {
        val text = danmakuInput?.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return
        ensureDanmakuController()
        getOverlayDanmaku()?.addLiveDanmaku(text, accentColor)
        if (!overlayDanmakuVisible) {
            setOverlayDanmakuVisible(true)
            onDanmakuVisibleChanged?.invoke(true)
        }
        onDanmakuSend?.invoke(text)
        danmakuInput?.setText("")
        refreshDanmakuBar()
    }

    private fun wireAudioPanel() {
        audioPanel = findViewById(R.id.audio_panel)
        volumeTrigger = findViewById(R.id.volume_trigger)
        audioPanelVolumeSeekBar = findViewById(R.id.audio_panel_volume)
        audioPanelVolumeValue = findViewById(R.id.audio_panel_volume_value)
        audioPanelVolumeSeekBar?.progress = (volumeToolbarLevel * 100).toInt()
        updateVolumeIcon()
        showVolumeValueLabel((volumeToolbarLevel * 100).toInt())
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
                    updateVolumeValueLabel(progress)
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

                override fun onStartTrackingTouch(seekBar: SeekBar?) {
                    volumeDragging = true
                    val progress = seekBar?.progress ?: 0
                    showVolumeValueLabel(progress)
                }

                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    volumeDragging = false
                    // Keep percent visible at top.
                    showVolumeValueLabel(seekBar?.progress ?: 0)
                }
            },
        )
        volumeTrigger?.setOnClickListener { toggleAudioPanel() }
    }

    private fun hideAllPopups() {
        hideAudioPanel()
        hideSettingsPanel()
        hideRatePanel()
        hideQualityPanel()
    }

    private fun toggleAudioPanel() {
        if (audioPanelVisible) {
            hideAudioPanel()
        } else {
            hideSettingsPanel()
            hideRatePanel()
            hideQualityPanel()
            showAudioPanel()
        }
    }

    private fun toggleSettingsPanel() {
        if (settingsPanelVisible) {
            hideSettingsPanel()
        } else {
            hideAudioPanel()
            hideRatePanel()
            hideQualityPanel()
            showSettingsPanel()
        }
    }

    private fun toggleRatePanel() {
        if (ratePanelVisible) {
            hideRatePanel()
        } else {
            hideAudioPanel()
            hideSettingsPanel()
            hideQualityPanel()
            showRatePanel()
        }
    }

    private fun toggleQualityPanel() {
        if (qualityPanelVisible) {
            hideQualityPanel()
        } else {
            hideAudioPanel()
            hideSettingsPanel()
            hideRatePanel()
            showQualityPanel()
        }
    }

    private fun showAudioPanel() {
        audioPanel?.visibility = View.VISIBLE
        audioPanelVisible = true
        positionPanelAboveAnchor(
            panel = audioPanel,
            anchor = volumeTrigger,
            fixedWidthRes = R.dimen.kinetic_audio_panel_width,
        )
        audioPanel?.bringToFront()
        showVolumeValueLabel(audioPanelVolumeSeekBar?.progress ?: (volumeToolbarLevel * 100).toInt())
        syncGestureVolumeDuringPanelInteraction()
    }

    fun hideAudioPanel() {
        audioPanel?.visibility = View.GONE
        audioPanelVisible = false
        volumeDragging = false
        syncGestureVolumeDuringPanelInteraction()
    }

    private fun showSettingsPanel() {
        showSettingsLevel(1)
        refreshSettingsLevel1()
        refreshSettingsLevel2()
        refreshSettingsTracks()
        settingsPanel?.visibility = View.VISIBLE
        settingsPanelVisible = true
        positionPanelAboveAnchor(
            panel = settingsPanel,
            anchor = settingsTrigger,
            align = PanelHorizontalAlign.TRAILING,
        )
        settingsPanel?.bringToFront()
    }

    fun hideSettingsPanel() {
        settingsPanel?.visibility = View.GONE
        settingsPanelVisible = false
    }

    private fun showRatePanel() {
        refreshRateList()
        ratePanel?.visibility = View.VISIBLE
        ratePanelVisible = true
        positionPanelAboveAnchor(
            panel = ratePanel,
            anchor = rateTrigger,
            fixedWidthRes = R.dimen.kinetic_option_panel_width,
        )
        ratePanel?.bringToFront()
    }

    private fun hideRatePanel() {
        ratePanel?.visibility = View.GONE
        ratePanelVisible = false
    }

    private fun showQualityPanel() {
        refreshQualityList()
        qualityPanel?.visibility = View.VISIBLE
        qualityPanelVisible = true
        positionPanelAboveAnchor(
            panel = qualityPanel,
            anchor = qualityTrigger,
            fixedWidthRes = R.dimen.kinetic_option_panel_width,
        )
        qualityPanel?.bringToFront()
    }

    private fun hideQualityPanel() {
        qualityPanel?.visibility = View.GONE
        qualityPanelVisible = false
    }

    private fun showSettingsLevel(level: Int) {
        settingsLevel1?.visibility = if (level == 1) View.VISIBLE else View.GONE
        settingsLevel2?.visibility = if (level == 2) View.VISIBLE else View.GONE
        if (settingsPanelVisible) {
            settingsPanel?.requestLayout()
            positionPanelAboveAnchor(
                panel = settingsPanel,
                anchor = settingsTrigger,
                align = PanelHorizontalAlign.TRAILING,
            )
        }
    }

    private fun refreshSettingsLevel1() {
        setToggleLabel(R.id.settings_mirror_value, chromeMirrorHorizontal)
        setToggleLabel(R.id.settings_loop_value, chromeLooping)
        setToggleLabel(R.id.settings_auto_play_value, chromeStartAfterPrepared)
    }

    private fun setToggleLabel(
        id: Int,
        on: Boolean,
    ) {
        val view = findViewById<TextView>(id) ?: return
        view.text =
            context.getString(if (on) R.string.kinetic_settings_on else R.string.kinetic_settings_off)
        view.setTextColor(if (on) accentColor else Color.parseColor("#CCFFFFFF"))
    }

    private fun refreshSettingsLevel2() {
        styleOption(R.id.settings_mode_pause, !chromeAutoPlayNext)
        styleOption(R.id.settings_mode_next, chromeAutoPlayNext)
        styleOption(R.id.settings_aspect_auto, !chromeHideBlackBars && chromeShowType == 0)
        styleOption(R.id.settings_aspect_16_9, !chromeHideBlackBars && chromeShowType == 1)
        styleOption(R.id.settings_aspect_4_3, !chromeHideBlackBars && chromeShowType == 2)
        styleOption(R.id.settings_hide_black_bars, chromeHideBlackBars)
        styleOption(R.id.settings_blackout, chromeBlackout)
    }

    private fun styleOption(
        id: Int,
        selected: Boolean,
    ) {
        val view = findViewById<TextView>(id) ?: return
        view.setTextColor(if (selected) accentColor else Color.WHITE)
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
                    setTextColor(if (selected) accentColor else Color.WHITE)
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

    private fun refreshRateList() {
        val list = ratePanelList ?: return
        list.removeAllViews()
        val padV = CommonUtil.dip2px(context, 8f)
        for (rate in rateOptions) {
            val selected = kotlin.math.abs(chromeRate - rate) < 0.001f
            val item =
                TextView(context).apply {
                    text = formatRateLabel(rate)
                    setPadding(0, padV, 0, padV)
                    textSize = 13f
                    setTextColor(if (selected) accentColor else Color.WHITE)
                    setOnClickListener {
                        chromeRate = rate
                        setSpeed(rate, true)
                        updateRateTriggerLabel()
                        hideRatePanel()
                    }
                }
            list.addView(item)
        }
    }

    private fun refreshQualityList() {
        val list = qualityPanelList ?: return
        list.removeAllViews()
        val tracks = onRequestVideoTracks?.invoke().orEmpty()
        val padV = CommonUtil.dip2px(context, 8f)
        val autoItem =
            TextView(context).apply {
                text = context.getString(R.string.kinetic_quality_auto)
                setPadding(0, padV, 0, padV)
                textSize = 13f
                setTextColor(if (chromeQualityAuto) accentColor else Color.WHITE)
                setOnClickListener {
                    chromeQualityAuto = true
                    chromeQualityLabel = context.getString(R.string.kinetic_quality_auto)
                    qualityTrigger?.text = chromeQualityLabel
                    onVideoTrackSelected?.invoke(-1)
                    hideQualityPanel()
                }
            }
        list.addView(autoItem)
        if (tracks.isEmpty()) {
            qualityTrigger?.visibility = View.GONE
            return
        }
        qualityTrigger?.visibility = View.VISIBLE
        for (track in tracks) {
            val index = track["index"] as? Int ?: continue
            val label = track["label"] as? String ?: "Track $index"
            val selected = !chromeQualityAuto && track["selected"] as? Boolean == true
            val item =
                TextView(context).apply {
                    text = label
                    setPadding(0, padV, 0, padV)
                    textSize = 13f
                    setTextColor(if (selected) accentColor else Color.WHITE)
                    setOnClickListener {
                        chromeQualityAuto = false
                        chromeQualityLabel = label
                        qualityTrigger?.text = label
                        onVideoTrackSelected?.invoke(index)
                        hideQualityPanel()
                    }
                }
            list.addView(item)
        }
    }

    fun refreshQualityToolbar() {
        val tracks = onRequestVideoTracks?.invoke().orEmpty()
        if (tracks.isEmpty()) {
            qualityTrigger?.visibility = View.GONE
            hideQualityPanel()
            return
        }
        qualityTrigger?.visibility = View.VISIBLE
        chromeQualityAuto = GsyExoTrackHelper.isAutoMode()
        if (chromeQualityAuto) {
            chromeQualityLabel = context.getString(R.string.kinetic_quality_auto)
        } else {
            val selected = tracks.firstOrNull { it["selected"] as? Boolean == true }
            chromeQualityLabel =
                selected?.get("label") as? String
                    ?: context.getString(R.string.kinetic_quality_auto)
        }
        qualityTrigger?.text = chromeQualityLabel
    }

    private fun formatRateLabel(rate: Float): String {
        val text =
            if (rate == rate.toInt().toFloat()) {
                String.format("%.1f", rate)
            } else {
                rate.toString()
            }
        return "${text}x"
    }

    private fun updateRateTriggerLabel() {
        rateTrigger?.text = formatRateLabel(chromeRate)
    }

    private fun refreshDanmakuBar() {
        danmakuToggle?.setImageResource(
            if (overlayDanmakuVisible) {
                R.drawable.kinetic_ic_danmaku_on
            } else {
                R.drawable.kinetic_ic_danmaku_off
            },
        )
        subtitleToggle?.setImageResource(
            if (overlaySubtitleEnabled) {
                R.drawable.kinetic_ic_subtitle_on
            } else {
                R.drawable.kinetic_ic_subtitle_off
            },
        )
        // On = accent; off = white (Bilibili-style toggle).
        danmakuToggle?.imageTintList =
            ColorStateList.valueOf(if (overlayDanmakuVisible) accentColor else Color.WHITE)
        subtitleToggle?.imageTintList =
            ColorStateList.valueOf(if (overlaySubtitleEnabled) accentColor else Color.WHITE)
        danmakuSend?.setTextColor(accentColor)
        val showInput = overlayDanmakuVisible && showDanmakuChrome
        danmakuInput?.visibility = if (showInput) View.VISIBLE else View.GONE
        danmakuSend?.visibility = if (showInput) View.VISIBLE else View.GONE
        val danmakuVisible = if (showDanmakuChrome) View.VISIBLE else View.GONE
        danmakuToggle?.visibility = danmakuVisible
        subtitleToggle?.visibility = danmakuVisible
        danmakuBar?.visibility =
            if ((storedUiConfig?.enableNativeControls != false) && showDanmakuChrome) {
                View.VISIBLE
            } else {
                View.GONE
            }
    }

    fun syncVolumeToolbar(
        volume: Float,
        muted: Boolean,
    ) {
        volumeToolbarLevel = volume.coerceIn(0f, 1f)
        volumeToolbarMuted = muted
        volumeUiSyncing = true
        val progress =
            if (muted) {
                0
            } else {
                (volumeToolbarLevel * 100).toInt().coerceIn(0, 100)
            }
        audioPanelVolumeSeekBar?.progress = progress
        updateVolumeIcon()
        showVolumeValueLabel(progress)
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

    private fun showVolumeValueLabel(progress: Int) {
        audioPanelVolumeValue?.apply {
            text = formatVolumePercent(progress)
            visibility = View.VISIBLE
        }
    }

    private fun updateVolumeValueLabel(progress: Int) {
        audioPanelVolumeValue?.apply {
            text = formatVolumePercent(progress)
            visibility = View.VISIBLE
        }
    }

    private fun formatVolumePercent(progress: Int): String =
        "${progress.coerceIn(0, 100)}%"

    private fun wireNativeControls() {
        // Keep GSY default video_enlarge / video_shrink so icon size matches stock chrome.
        fullscreenButton?.scaleType = ImageView.ScaleType.CENTER
        fullscreenButton?.setOnClickListener {
            toggleWindowFullscreen()
        }
        toolbarPlayButton = findViewById(R.id.toolbar_play)
        toolbarPlayButton?.setOnClickListener {
            clickStartIcon()
        }
        updateToolbarPlayIcon()
    }

    override fun updateStartImage() {
        super.updateStartImage()
        updateToolbarPlayIcon()
    }

    private fun updateToolbarPlayIcon() {
        val iconRes =
            if (currentState == CURRENT_STATE_PLAYING) {
                R.drawable.kinetic_ic_pause
            } else {
                R.drawable.kinetic_ic_play
            }
        toolbarPlayButton?.setImageResource(iconRes)
    }

    private fun applyAccentToChrome() {
        val tint = ColorStateList.valueOf(accentColor)
        mProgressBar?.apply {
            progressTintList = tint
            thumbTintList = tint
        }
        audioPanelVolumeSeekBar?.apply {
            progressTintList = tint
            thumbTintList = tint
        }
        danmakuSend?.setTextColor(accentColor)
        findViewById<TextView>(R.id.danmaku_send)?.setTextColor(accentColor)
        danmakuInput?.setBackgroundResource(R.drawable.kinetic_danmaku_input_bg)
    }

    open fun applyUiConfig() {
        val config = storedUiConfig ?: DEFAULT_UI_CONFIG
        accentColor = config.accentColor
        chromeRate = config.speed
        chromeLooping = config.looping
        chromeStartAfterPrepared = config.startAfterPrepared
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
        toolbarPlayButton?.visibility =
            if (config.enableNativeControls) View.VISIBLE else View.GONE
        volumeTrigger?.visibility =
            if (config.showVolumeToolbar) View.VISIBLE else View.GONE
        settingsTrigger?.visibility =
            if (config.showSettingsButton) View.VISIBLE else View.GONE
        rateTrigger?.visibility = View.VISIBLE
        // Danmaku row visibility is driven by showDanmakuChrome in refreshDanmakuBar().
        if (!config.showVolumeToolbar) {
            hideAudioPanel()
        }
        if (!config.showSettingsButton) {
            hideSettingsPanel()
        }
        setCoverUrl(config.coverUrl)
        updateRateTriggerLabel()
        applyAccentToChrome()
        refreshDanmakuBar()
        refreshQualityToolbar()
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
            positionPanelAboveAnchor(
                panel = audioPanel,
                anchor = volumeTrigger,
                fixedWidthRes = R.dimen.kinetic_audio_panel_width,
            )
        }
        if (settingsPanelVisible) {
            settingsPanel?.bringToFront()
            positionPanelAboveAnchor(
                panel = settingsPanel,
                anchor = settingsTrigger,
                align = PanelHorizontalAlign.TRAILING,
            )
        }
        if (ratePanelVisible) {
            ratePanel?.bringToFront()
            positionPanelAboveAnchor(
                panel = ratePanel,
                anchor = rateTrigger,
                fixedWidthRes = R.dimen.kinetic_option_panel_width,
            )
        }
        if (qualityPanelVisible) {
            qualityPanel?.bringToFront()
            positionPanelAboveAnchor(
                panel = qualityPanel,
                anchor = qualityTrigger,
                fixedWidthRes = R.dimen.kinetic_option_panel_width,
            )
        }
        syncBottomChromeTouchPassthrough()
    }

    private enum class PanelHorizontalAlign {
        CENTER,
        TRAILING,
    }

    /** Positions popup above a bottom-toolbar anchor; re-run on layout / resize. */
    private fun positionPanelAboveAnchor(
        panel: View?,
        anchor: View?,
        align: PanelHorizontalAlign = PanelHorizontalAlign.CENTER,
        fixedWidthRes: Int? = null,
    ) {
        val panelView = panel ?: return
        val anchorView = anchor ?: return
        val host = panelView.parent as? RelativeLayout ?: return
        val fixedWidthPx =
            fixedWidthRes?.let { resources.getDimensionPixelSize(it) }
        val bottomMarginPx =
            resources.getDimensionPixelSize(R.dimen.kinetic_panel_popup_margin_bottom)
        panelView.post {
            if (!panelView.isShown) return@post
            if (host.width == 0 || anchorView.width == 0) {
                panelView.post {
                    positionPanelAboveAnchor(panel, anchor, align, fixedWidthRes)
                }
                return@post
            }
            val measuredWidth =
                if (fixedWidthPx != null) {
                    fixedWidthPx
                } else {
                    val maxWidth = host.width.coerceAtLeast(1)
                    panelView.measure(
                        View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
                        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                    )
                    panelView.measuredWidth.coerceAtLeast(1)
                }
            val hostLoc = IntArray(2)
            val anchorLoc = IntArray(2)
            host.getLocationInWindow(hostLoc)
            anchorView.getLocationInWindow(anchorLoc)
            val anchorLeft = anchorLoc[0] - hostLoc[0]
            val anchorTop = anchorLoc[1] - hostLoc[1]
            val targetLeft =
                when (align) {
                    PanelHorizontalAlign.CENTER ->
                        anchorLeft + (anchorView.width - measuredWidth) / 2
                    PanelHorizontalAlign.TRAILING ->
                        anchorLeft + anchorView.width - measuredWidth
                }
            val maxLeft = (host.width - measuredWidth).coerceAtLeast(0)
            val panelBottom = anchorTop - bottomMarginPx
            val lp = panelView.layoutParams as RelativeLayout.LayoutParams
            lp.width = fixedWidthPx ?: ViewGroup.LayoutParams.WRAP_CONTENT
            lp.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
            lp.removeRule(RelativeLayout.ABOVE)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_START)
            lp.removeRule(RelativeLayout.ALIGN_START)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_END)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_LEFT)
            lp.removeRule(RelativeLayout.ALIGN_PARENT_RIGHT)
            lp.leftMargin = targetLeft.coerceIn(0, maxLeft)
            lp.rightMargin = 0
            lp.bottomMargin = (host.height - panelBottom).coerceAtLeast(bottomMarginPx)
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
        post { fixControlOverlayLayering() }
    }

    override fun changeUiToPlayingShow() {
        super.changeUiToPlayingShow()
        fixControlOverlayLayering()
    }

    override fun changeUiToPlayingClear() {
        hideAllPopups()
        super.changeUiToPlayingClear()
        syncBottomChromeTouchPassthrough()
    }

    override fun changeUiToPauseShow() {
        super.changeUiToPauseShow()
        fixControlOverlayLayering()
    }

    override fun changeUiToPauseClear() {
        hideAllPopups()
        super.changeUiToPauseClear()
        syncBottomChromeTouchPassthrough()
    }

    override fun onClickUiToggle(event: MotionEvent) {
        hideAllPopups()
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
        refreshDanmakuBar()
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
        chromeMirrorHorizontal = mirrorH
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
        toPlayer.onRequestVideoTracks = fromPlayer.onRequestVideoTracks
        toPlayer.onVideoTrackSelected = fromPlayer.onVideoTrackSelected
        toPlayer.onMirrorHorizontalChanged = fromPlayer.onMirrorHorizontalChanged
        toPlayer.onLoopingChanged = fromPlayer.onLoopingChanged
        toPlayer.onStartAfterPreparedChanged = fromPlayer.onStartAfterPreparedChanged
        toPlayer.onAutoPlayNextChanged = fromPlayer.onAutoPlayNextChanged
        toPlayer.onShowTypeChanged = fromPlayer.onShowTypeChanged
        toPlayer.onSubtitleEnabledChanged = fromPlayer.onSubtitleEnabledChanged
        toPlayer.onDanmakuVisibleChanged = fromPlayer.onDanmakuVisibleChanged
        toPlayer.onDanmakuSend = fromPlayer.onDanmakuSend
        toPlayer.onDanmakuPlaybackStart = fromPlayer.onDanmakuPlaybackStart
        toPlayer.onDanmakuPlaybackPause = fromPlayer.onDanmakuPlaybackPause
        toPlayer.onDanmakuPlaybackComplete = fromPlayer.onDanmakuPlaybackComplete
        toPlayer.chromeRate = fromPlayer.chromeRate
        toPlayer.chromeMirrorHorizontal = fromPlayer.chromeMirrorHorizontal
        toPlayer.chromeLooping = fromPlayer.chromeLooping
        toPlayer.chromeStartAfterPrepared = fromPlayer.chromeStartAfterPrepared
        toPlayer.chromeAutoPlayNext = fromPlayer.chromeAutoPlayNext
        toPlayer.chromeShowType = fromPlayer.chromeShowType
        toPlayer.chromeHideBlackBars = fromPlayer.chromeHideBlackBars
        toPlayer.chromeBlackout = fromPlayer.chromeBlackout
        toPlayer.chromeQualityAuto = fromPlayer.chromeQualityAuto
        toPlayer.chromeQualityLabel = fromPlayer.chromeQualityLabel
        toPlayer.accentColor = fromPlayer.accentColor
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
            toPlayer.blackoutOverlay?.visibility =
                if (fromPlayer.chromeBlackout) View.VISIBLE else View.GONE
            toPlayer.applyAccentToChrome()
            toPlayer.updateRateTriggerLabel()
            toPlayer.refreshDanmakuBar()
            toPlayer.refreshQualityToolbar()
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
