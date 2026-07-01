package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.View
import android.widget.FrameLayout
import com.keepwan.kinetic_player.CommonPlayerState
import com.keepwan.kinetic_player.ThrottledProgressReporter
import com.shuyu.gsyvideoplayer.GSYVideoManager
import com.shuyu.gsyvideoplayer.builder.GSYVideoOptionBuilder
import com.shuyu.gsyvideoplayer.listener.GSYSampleCallBack
import com.shuyu.gsyvideoplayer.listener.GSYVideoGifSaveListener
import com.shuyu.gsyvideoplayer.listener.GSYVideoShotListener
import com.shuyu.gsyvideoplayer.listener.GSYVideoShotSaveListener
import com.shuyu.gsyvideoplayer.player.IjkPlayerManager
import com.shuyu.gsyvideoplayer.player.IPlayerManager
import com.shuyu.gsyvideoplayer.player.PlayerFactory
import com.shuyu.gsyvideoplayer.player.SystemPlayerManager
import com.shuyu.gsyvideoplayer.subtitle.GSYSubtitleSource
import com.shuyu.gsyvideoplayer.utils.CommonUtil
import com.shuyu.gsyvideoplayer.utils.GSYVideoType
import com.shuyu.gsyvideoplayer.utils.GifCreateHelper
import tv.danmaku.ijk.media.exo2.Exo2PlayerManager
import com.shuyu.gsyvideoplayer.video.base.GSYVideoView
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

interface GsyPlayerCallbacks {
    fun onPlayerStateChanged(state: CommonPlayerState)
    fun onPositionChanged(positionMs: Long, durationMs: Long)
}

class GsyNativePlayer(
    context: Context,
    private val callbacks: GsyPlayerCallbacks,
    initialUiConfig: GsyUiConfig = GsyUiConfig(),
    private val playTag: String = "kinetic_${UUID.randomUUID()}",
) {
    private val appContext = context.applicationContext
    private val container = FrameLayout(context)
    private val playerView = KineticPreViewGSYVideoPlayer(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cacheDir = File(appContext.cacheDir, "kinetic_player").apply { mkdirs() }

    private var uiConfig = initialUiConfig
    private var danmakuOverlay: View? = null
    private var danmakuVisible = false
    private var isPlaying = false
    private var currentUrl: String? = null
    private var playlist: List<String> = emptyList()
    private var playlistIndex = 0
    private var pendingContentUrl: String? = null
    private var gifHelper: GifCreateHelper? = null
    private var gifResultCallback: ((String?) -> Unit)? = null
    private var renderRotation = 0
    private var mirrorHorizontal = false

    private val progressReporter = ThrottledProgressReporter { positionMs, durationMs ->
        callbacks.onPositionChanged(positionMs, durationMs)
    }

    private val progressRunnable =
        object : Runnable {
            override fun run() {
                if (isPlaying) {
                    reportProgress()
                }
                mainHandler.postDelayed(this, 250L)
            }
        }

    private val videoCallback =
        object : GSYSampleCallBack() {
            override fun onPlayError(url: String?, vararg objects: Any?) {
                isPlaying = false
                callbacks.onPlayerStateChanged(CommonPlayerState.ERROR)
            }

            override fun onAutoComplete(url: String?, vararg objects: Any?) {
                isPlaying = false
                when {
                    pendingContentUrl != null -> {
                        val content = pendingContentUrl!!
                        pendingContentUrl = null
                        setUrl(content)
                        startPlayLogic()
                    }
                    playlistIndex < playlist.lastIndex -> {
                        playlistIndex++
                        setUrl(playlist[playlistIndex])
                        startPlayLogic()
                    }
                    else -> {
                        callbacks.onPlayerStateChanged(CommonPlayerState.COMPLETED)
                        reportProgress(force = true)
                    }
                }
            }

            override fun onPrepared(url: String?, vararg objects: Any?) {
                callbacks.onPlayerStateChanged(CommonPlayerState.READY)
                applyRenderTransform()
                reportProgress(force = true)
            }
        }

    init {
        playerView.uiConfig = uiConfig
        container.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        mainHandler.post(progressRunnable)
        GsyPlayerLifecycleRegistry.register(this)
    }

    fun getView(): View = container

    fun onConfigurationChanged(
        activity: Activity,
        newConfig: Configuration,
    ) {
        playerView.dispatchConfigurationChanged(activity, newConfig)
    }

    fun applyUiConfig(config: GsyUiConfig) {
        uiConfig = config
        playerView.uiConfig = config
        config.previewVttUrl?.let { playerView.setPreviewVttUrl(it) }
        currentUrl?.let { setUrl(it) }
    }

    fun setPreviewVttUrl(url: String?) {
        uiConfig = uiConfig.copy(previewVttUrl = url)
        playerView.setPreviewVttUrl(url)
    }

    fun startFullscreen() = playerView.toggleWindowFullscreen()

    fun setSpeed(speed: Float) {
        uiConfig = uiConfig.copy(speed = speed)
        playerView.setSpeed(speed, false)
    }

    fun setLooping(looping: Boolean) {
        uiConfig = uiConfig.copy(looping = looping)
        playerView.isLooping = looping
    }

    fun setUrl(videoUrl: String) {
        currentUrl = videoUrl
        buildVideoOptions()
            .setUrl(videoUrl)
            .setPlayTag(playTag)
            .build(playerView)
        uiConfig.previewVttUrl?.let { playerView.setPreviewVttUrl(it) }
        callbacks.onPlayerStateChanged(CommonPlayerState.IDLE)
    }

    fun setPlaylist(urls: List<String>, startIndex: Int = 0) {
        playlist = urls
        playlistIndex = startIndex.coerceIn(0, (urls.size - 1).coerceAtLeast(0))
        if (urls.isNotEmpty()) {
            setUrl(urls[playlistIndex])
        }
    }

    fun playNextInPlaylist(): Boolean {
        if (playlistIndex >= playlist.lastIndex) return false
        playlistIndex++
        setUrl(playlist[playlistIndex])
        startPlayLogic()
        return true
    }

    fun playWithPreRollAd(
        adUrl: String,
        contentUrl: String,
    ) {
        pendingContentUrl = contentUrl
        setUrl(adUrl)
    }

    fun setPurePlayMode(enabled: Boolean) {
        applyUiConfig(
            uiConfig.copy(
                enableNativeControls = !enabled,
                enableNativeControlsFullscreen = !enabled,
                showFullscreenButton = !enabled,
                showLockButton = !enabled,
            ),
        )
    }

    private fun buildVideoOptions(): GSYVideoOptionBuilder {
        val builder =
            GSYVideoOptionBuilder()
                .setVideoTitle(uiConfig.videoTitle)
                .setIsTouchWiget(uiConfig.enableNativeControls)
                .setIsTouchWigetFull(uiConfig.enableNativeControlsFullscreen)
                .setRotateViewAuto(uiConfig.rotateViewAuto)
                .setRotateWithSystem(uiConfig.rotateWithSystem)
                .setLockLand(uiConfig.lockLand)
                .setNeedOrientationUtils(uiConfig.needOrientationUtils)
                .setShowFullAnimation(uiConfig.showFullAnimation)
                .setHideKey(uiConfig.hideVirtualKey)
                .setShowPauseCover(uiConfig.showPauseCover)
                .setNeedShowWifiTip(uiConfig.needShowWifiTip)
                .setSurfaceErrorPlay(uiConfig.surfaceErrorPlay)
                .setReleaseWhenLossAudio(uiConfig.releaseWhenLossAudio)
                .setShowDragProgressTextOnSeekBar(uiConfig.showDragProgressTextOnSeekBar)
                .setDismissControlTime(uiConfig.dismissControlTime)
                .setSeekRatio(uiConfig.seekRatio)
                .setSpeed(uiConfig.speed)
                .setLooping(uiConfig.looping)
                .setAutoFullWithSize(uiConfig.autoFullWithSize)
                .setNeedLockFull(uiConfig.showLockButton)
                .setCacheWithPlay(uiConfig.cacheWithPlay)
                .setStartAfterPrepared(uiConfig.startAfterPrepared)
                .setVideoAllCallBack(videoCallback)
        if (uiConfig.seekOnStartMs >= 0) {
            builder.setSeekOnStart(uiConfig.seekOnStartMs)
        }
        return builder
    }

    fun startPlayLogic() {
        playerView.startPlayLogic()
        isPlaying = true
        emitMappedState(GSYVideoView.CURRENT_STATE_PLAYING)
        reportProgress(force = true)
    }

    fun onVideoPause() {
        playerView.onVideoPause()
        isPlaying = false
        emitMappedState(GSYVideoView.CURRENT_STATE_PAUSE)
    }

    fun seekTo(positionMs: Int) {
        GSYVideoManager.instance().seekTo(positionMs.toLong())
        reportProgress(force = true)
    }

    /** CommonScaleMode: 0=fit, 1=fill, 2=stretch */
    fun setScaleMode(commonMode: Int) {
        val gsyMode =
            when (commonMode) {
                0 -> GSYVideoType.SCREEN_TYPE_DEFAULT
                1 -> GSYVideoType.SCREEN_TYPE_FULL
                2 -> GSYVideoType.SCREEN_MATCH_FULL
                else -> GSYVideoType.SCREEN_TYPE_DEFAULT
            }
        GSYVideoType.setShowType(gsyMode)
    }

    fun setGsyShowType(
        mode: Int,
        customRatio: Float?,
    ) {
        if (customRatio != null && mode == 6) {
            GsyScaleModeMapper.setCustomRatio(customRatio)
        } else {
            GSYVideoType.setShowType(GsyScaleModeMapper.toGsyShowType(mode))
        }
    }

    fun setRenderType(renderType: Int) {
        GSYVideoType.setRenderType(renderType)
    }

    fun setEffectFilter(name: String) {
        val effect = GsyEffectRegistry.resolve(name)
        playerView.setEffectFilter(effect)
    }

    fun setRenderRotation(degrees: Int) {
        renderRotation = degrees
        applyRenderTransform()
    }

    fun setMirrorHorizontal(enabled: Boolean) {
        mirrorHorizontal = enabled
        applyRenderTransform()
    }

    private fun applyRenderTransform() {
        val proxy = playerView.getRenderProxy() ?: return
        val matrix = Matrix()
        val w = playerView.width.takeIf { it > 0 } ?: return
        val h = playerView.height.takeIf { it > 0 } ?: return
        matrix.postRotate(renderRotation.toFloat(), w / 2f, h / 2f)
        if (mirrorHorizontal) {
            matrix.postScale(-1f, 1f, w / 2f, h / 2f)
        }
        proxy.setTransform(matrix)
    }

    fun getNetSpeedBytesPerSecond(): Long = playerView.getNetSpeed()

    fun getNetSpeedText(): String = playerView.getNetSpeedText()

    fun changeRenderCore(core: Int): Boolean =
        when (core) {
            0 -> {
                PlayerFactory.setPlayManager(IjkPlayerManager::class.java)
                GSYVideoManager.instance().releaseMediaPlayer()
                true
            }
            1 -> {
                PlayerFactory.setPlayManager(Exo2PlayerManager::class.java)
                GSYVideoManager.instance().releaseMediaPlayer()
                true
            }
            2 -> {
                PlayerFactory.setPlayManager(SystemPlayerManager::class.java)
                GSYVideoManager.instance().releaseMediaPlayer()
                true
            }
            else -> false
        }

    fun setSubtitleUrl(
        url: String,
        mimeType: String?,
    ) {
        val builder = GSYSubtitleSource.Builder(url)
        if (!mimeType.isNullOrEmpty()) {
            builder.setMimeType(mimeType)
        }
        playerView.setSubtitleSource(builder.build())
        playerView.setSubtitleEnabled(true)
    }

    fun setSubtitleEnabled(enabled: Boolean) {
        playerView.setSubtitleEnabled(enabled)
    }

    fun setEmbeddedSubtitleText(text: String?) {
        if (text.isNullOrEmpty()) {
            playerView.clearSubtitleTextFromPlayer()
        } else {
            playerView.setSubtitleTextFromPlayer(text)
        }
    }

    fun takeScreenshot(
        withView: Boolean,
        high: Boolean,
        callback: (String?) -> Unit,
    ) {
        val output = File(cacheDir, "shot_${System.currentTimeMillis()}.png")
        val listener =
            object : GSYVideoShotListener {
                override fun getBitmap(bitmap: Bitmap?) {
                    if (bitmap == null) {
                        mainHandler.post { callback(null) }
                        return
                    }
                    try {
                        FileOutputStream(output).use { out ->
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                        }
                        mainHandler.post { callback(output.absolutePath) }
                    } catch (_: Exception) {
                        mainHandler.post { callback(null) }
                    }
                }
            }
        if (withView) {
            playerView.taskShotPicWithView(listener, high)
        } else {
            playerView.taskShotPic(listener, high)
        }
    }

    fun saveScreenshot(
        withView: Boolean,
        high: Boolean,
        callback: (String?) -> Unit,
    ) {
        val output = File(cacheDir, "frame_${System.currentTimeMillis()}.png")
        val listener =
            GSYVideoShotSaveListener { success, _ ->
                mainHandler.post {
                    callback(if (success) output.absolutePath else null)
                }
            }
        if (withView) {
            playerView.saveFrameWithView(output, high, listener)
        } else {
            playerView.saveFrame(output, high, listener)
        }
    }

    fun captureFirstFrame(callback: (String?) -> Unit) {
        takeScreenshot(withView = false, high = true, callback = callback)
    }

    fun startGifRecording() {
        stopGifRecordingInternal(save = false)
        gifHelper =
            GifCreateHelper(
                playerView,
                object : GSYVideoGifSaveListener {
                    override fun process(
                        curPosition: Int,
                        total: Int,
                    ) = Unit

                    override fun result(
                        success: Boolean,
                        file: File?,
                    ) {
                        mainHandler.post {
                            gifResultCallback?.invoke(if (success) file?.absolutePath else null)
                            gifResultCallback = null
                        }
                    }
                },
            )
        gifHelper?.startGif(File(cacheDir, "gif_tmp"))
    }

    fun stopGifRecording(callback: (String?) -> Unit) {
        val helper = gifHelper
        if (helper == null) {
            callback(null)
            return
        }
        gifResultCallback = callback
        helper.stopGif(File(cacheDir, "video_${System.currentTimeMillis()}.gif"))
        gifHelper = null
    }

    private fun stopGifRecordingInternal(save: Boolean) {
        gifHelper?.cancelTask()
        if (!save) {
            gifHelper = null
        }
    }

    fun toggleDanmaku(enabled: Boolean) {
        danmakuVisible = enabled
        if (enabled && danmakuOverlay == null) {
            danmakuOverlay =
                FrameLayout(appContext).apply {
                    tag = "gsy_danmaku"
                    layoutParams =
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT,
                        )
                }
            container.addView(danmakuOverlay)
        }
        danmakuOverlay?.visibility = if (enabled) View.VISIBLE else View.GONE
    }

    fun enterPictureInPicture(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val activity = CommonUtil.scanForActivity(playerView.context) as? Activity ?: return false
        val params =
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
        return activity.enterPictureInPictureMode(params)
    }

    fun releaseAllVideos() {
        GSYVideoManager.releaseAllVideos()
    }

    private fun emitMappedState(rawState: Int) {
        val mapped =
            when (rawState) {
                GSYVideoView.CURRENT_STATE_PLAYING -> CommonPlayerState.PLAYING
                GSYVideoView.CURRENT_STATE_PLAYING_BUFFERING_START -> CommonPlayerState.BUFFERING
                GSYVideoView.CURRENT_STATE_PAUSE -> CommonPlayerState.PAUSED
                GSYVideoView.CURRENT_STATE_AUTO_COMPLETE -> CommonPlayerState.COMPLETED
                GSYVideoView.CURRENT_STATE_ERROR -> CommonPlayerState.ERROR
                GSYVideoView.CURRENT_STATE_PREPAREING -> CommonPlayerState.BUFFERING
                else -> CommonPlayerState.IDLE
            }
        callbacks.onPlayerStateChanged(mapped)
    }

    private fun reportProgress(force: Boolean = false) {
        val positionMs = GSYVideoManager.instance().currentPosition
        val durationMs = playerView.duration.coerceAtLeast(0L)
        progressReporter.report(positionMs, durationMs, force)
    }

    fun release() {
        isPlaying = false
        mainHandler.removeCallbacks(progressRunnable)
        stopGifRecordingInternal(save = false)
        GsyPlayerLifecycleRegistry.unregister(this)
        playerView.release()
        progressReporter.reset()
    }
}
