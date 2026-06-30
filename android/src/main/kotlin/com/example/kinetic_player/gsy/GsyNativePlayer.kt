package com.example.kinetic_player.gsy

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import com.example.kinetic_player.CommonPlayerState
import com.example.kinetic_player.ThrottledProgressReporter
import com.shuyu.gsyvideoplayer.GSYVideoManager
import com.shuyu.gsyvideoplayer.builder.GSYVideoOptionBuilder
import com.shuyu.gsyvideoplayer.listener.GSYSampleCallBack
import com.shuyu.gsyvideoplayer.player.IjkPlayerManager
import com.shuyu.gsyvideoplayer.player.IPlayerManager
import com.shuyu.gsyvideoplayer.player.PlayerFactory
import com.shuyu.gsyvideoplayer.player.SystemPlayerManager
import com.shuyu.gsyvideoplayer.utils.GSYVideoType
import tv.danmaku.ijk.media.exo2.Exo2PlayerManager
import com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer
import com.shuyu.gsyvideoplayer.video.base.GSYVideoView

interface GsyPlayerCallbacks {
    fun onPlayerStateChanged(state: CommonPlayerState)
    fun onPositionChanged(positionMs: Long, durationMs: Long)
}

class GsyNativePlayer(
    context: Context,
    private val callbacks: GsyPlayerCallbacks,
) {
    private val container = FrameLayout(context)
    private val playerView = StandardGSYVideoPlayer(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var danmakuVisible = false
    private var isPlaying = false

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
                callbacks.onPlayerStateChanged(CommonPlayerState.COMPLETED)
                reportProgress(force = true)
            }

            override fun onPrepared(url: String?, vararg objects: Any?) {
                callbacks.onPlayerStateChanged(CommonPlayerState.READY)
                reportProgress(force = true)
            }
        }

    init {
        container.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        mainHandler.post(progressRunnable)
    }

    fun getView(): View = container

    fun setUrl(videoUrl: String) {
        GSYVideoOptionBuilder()
            .setUrl(videoUrl)
            .setVideoTitle("")
            .setIsTouchWiget(false)
            .setRotateViewAuto(false)
            .setLockLand(false)
            .setShowFullAnimation(false)
            .setNeedLockFull(true)
            .setCacheWithPlay(true)
            .setVideoAllCallBack(videoCallback)
            .build(playerView)
        callbacks.onPlayerStateChanged(CommonPlayerState.IDLE)
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

    fun setShowType(mode: Int) {
        GSYVideoType.setShowType(mode)
    }

    fun changeRenderCore(core: Int) {
        PlayerFactory.setPlayManager(playManagerClassForCore(core))
        // Release current player so the next prepare uses the new kernel.
        GSYVideoManager.instance().releaseMediaPlayer()
    }

    private fun playManagerClassForCore(core: Int): Class<out IPlayerManager> =
        when (core) {
            1 -> Exo2PlayerManager::class.java
            2 -> SystemPlayerManager::class.java
            else -> IjkPlayerManager::class.java
        }

    fun toggleDanmaku(enabled: Boolean) {
        danmakuVisible = enabled
        val danmakuView = container.findViewWithTag<View>("gsy_danmaku")
        danmakuView?.visibility = if (enabled) View.VISIBLE else View.GONE
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
        playerView.release()
        GSYVideoManager.releaseAllVideos()
        progressReporter.reset()
    }
}
