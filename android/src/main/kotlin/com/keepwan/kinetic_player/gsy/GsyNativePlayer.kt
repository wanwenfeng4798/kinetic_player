package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
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
import java.net.HttpURLConnection
import java.net.URL
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
    private val danmakuController = GsyDanmakuController(container, playerView)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cacheDir = File(appContext.cacheDir, "kinetic_player").apply { mkdirs() }

    private var uiConfig = initialUiConfig
    private var danmakuVisible = false
    private var danmakuUrl: String? = null
    private var watermarkView: ImageView? = null
    private val midRollQueue = mutableListOf<Pair<Long, String>>()
    private var isPlaying = false
    private var currentUrl: String? = null
    private var playlist: List<String> = emptyList()
    private var playlistIndex = 0
    private var pendingContentUrl: String? = null
    private var gifHelper: GifCreateHelper? = null
    private var gifResultCallback: ((String?) -> Unit)? = null
    private var renderRotation = 0
    private var mirrorHorizontal = false
    private var activeRenderType: Int? = null

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
                playerView.fixControlOverlayLayering()
                danmakuController.onPrepared()
                danmakuUrl?.let { danmakuController.loadFromUrl(it) }
                reportProgress(force = true)
            }
        }

    init {
        playerView.uiConfig = initialUiConfig
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
        danmakuController.onResume()
        emitMappedState(GSYVideoView.CURRENT_STATE_PLAYING)
        reportProgress(force = true)
    }

    fun onVideoPause() {
        playerView.onVideoPause()
        isPlaying = false
        danmakuController.onPause()
        emitMappedState(GSYVideoView.CURRENT_STATE_PAUSE)
    }

    fun seekTo(positionMs: Int) {
        GSYVideoManager.instance().seekTo(positionMs.toLong())
        danmakuController.onSeek(positionMs.toLong())
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
        if (activeRenderType == renderType) return
        activeRenderType = renderType
        GSYVideoType.setRenderType(renderType)
        currentUrl?.let { setUrl(it) }
        scheduleControlOverlayFix()
    }

    fun setEffectFilter(name: String) {
        val effect = GsyEffectRegistry.resolve(name)
        playerView.setEffectFilter(effect)
        scheduleControlOverlayFix()
    }

    private fun scheduleControlOverlayFix() {
        playerView.post { playerView.fixControlOverlayLayering() }
        playerView.postDelayed({ playerView.fixControlOverlayLayering() }, 100)
        playerView.postDelayed({ playerView.fixControlOverlayLayering() }, 400)
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
        danmakuController.attachIfNeeded()
        danmakuController.setVisible(enabled)
    }

    fun setDanmakuUrl(url: String?) {
        danmakuUrl = url
        if (!url.isNullOrEmpty()) {
            danmakuController.attachIfNeeded()
            danmakuController.loadFromUrl(url)
            danmakuController.setVisible(danmakuVisible)
        }
    }

    fun setMidRollAds(ads: List<Map<String, Any>>) {
        midRollQueue.clear()
        for (ad in ads) {
            val atMs = (ad["atMs"] as? Number)?.toLong() ?: continue
            val url = ad["url"] as? String ?: continue
            midRollQueue.add(atMs to url)
        }
        midRollQueue.sortBy { it.first }
    }

    fun listExoVideoTracks(): List<Map<String, Any>> =
        GsyExoTrackHelper.listVideoTracks().map {
            mapOf(
                "index" to it.index,
                "label" to it.label,
                "width" to it.width,
                "height" to it.height,
                "bitrate" to it.bitrate,
                "selected" to it.selected,
            )
        }

    fun selectExoVideoTrack(index: Int): Boolean = GsyExoTrackHelper.selectVideoTrack(index)

    fun setWatermarkUrl(url: String?) {
        if (url.isNullOrEmpty()) {
            watermarkView?.visibility = View.GONE
            return
        }
        if (watermarkView == null) {
            watermarkView =
                ImageView(appContext).apply {
                    layoutParams =
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                        ).apply {
                            gravity = android.view.Gravity.TOP or android.view.Gravity.END
                            topMargin = CommonUtil.dip2px(appContext, 8f)
                            rightMargin = CommonUtil.dip2px(appContext, 8f)
                        }
                }
            container.addView(watermarkView)
        }
        watermarkView?.visibility = View.VISIBLE
        Thread {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connect()
                val bitmap = BitmapFactory.decodeStream(connection.inputStream)
                mainHandler.post { watermarkView?.setImageBitmap(bitmap) }
            } catch (_: Exception) {
                // ignore
            }
        }.start()
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
        checkMidRoll(positionMs)
        progressReporter.report(positionMs, durationMs, force)
    }

    private fun checkMidRoll(positionMs: Long) {
        if (midRollQueue.isEmpty() || pendingContentUrl != null) return
        val next = midRollQueue.first()
        if (positionMs >= next.first) {
            midRollQueue.removeAt(0)
            val content = currentUrl ?: return
            playWithPreRollAd(next.second, content)
        }
    }

    fun release() {
        isPlaying = false
        mainHandler.removeCallbacks(progressRunnable)
        stopGifRecordingInternal(save = false)
        danmakuController.release()
        GsyPlayerLifecycleRegistry.unregister(this)
        playerView.release()
        progressReporter.reset()
    }
}
