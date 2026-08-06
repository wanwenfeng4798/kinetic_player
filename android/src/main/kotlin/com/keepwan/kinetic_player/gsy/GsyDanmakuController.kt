package com.keepwan.kinetic_player.gsy

import android.net.Uri
import android.view.View
import android.view.ViewGroup
import com.keepwan.kinetic_player.R
import com.keepwan.kinetic_player.danmaku.BiliDanmukuParser
import com.shuyu.gsyvideoplayer.video.StandardGSYVideoPlayer
import master.flame.danmaku.controller.DrawHandler
import master.flame.danmaku.danmaku.loader.ILoader
import master.flame.danmaku.danmaku.loader.android.DanmakuLoaderFactory
import master.flame.danmaku.danmaku.model.BaseDanmaku
import master.flame.danmaku.danmaku.model.DanmakuTimer
import master.flame.danmaku.danmaku.model.IDisplayer
import master.flame.danmaku.danmaku.model.android.DanmakuContext
import master.flame.danmaku.danmaku.model.android.Danmakus
import master.flame.danmaku.danmaku.model.android.SpannedCacheStuffer
import master.flame.danmaku.danmaku.parser.BaseDanmakuParser
import master.flame.danmaku.danmaku.parser.IDataSource
import master.flame.danmaku.ui.widget.DanmakuView
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * DanmakuFlameMaster integration. Binds to [R.id.kinetic_danmaku_view] inside the player
 * layout so overlays survive GSY window-fullscreen clone.
 */
class GsyDanmakuController(
    private val playerView: StandardGSYVideoPlayer,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var danmakuView: DanmakuView? = null
    private var danmakuContext: DanmakuContext? = null
    private var parser: BaseDanmakuParser? = null
    private var visible = false
    private var prepared = false
    private var pendingUrl: String? = null

    fun attachIfNeeded() {
        if (danmakuView != null) return
        val view = playerView.findViewById<DanmakuView>(R.id.kinetic_danmaku_view) ?: return
        view.tag = "gsy_danmaku"
        danmakuView = view
        initDanmakuContext(view)
        pendingUrl?.let { loadFromUrl(it) }
    }

    /** Rebind after fullscreen clone inflated a new layout. */
    fun rebindToPlayer() {
        releaseViewOnly()
        attachIfNeeded()
        if (visible) {
            setVisible(true)
        }
    }

    private fun initDanmakuContext(view: DanmakuView) {
        val maxLines = hashMapOf(BaseDanmaku.TYPE_SCROLL_RL to 5)
        val overlapping = hashMapOf(BaseDanmaku.TYPE_SCROLL_RL to true, BaseDanmaku.TYPE_FIX_TOP to true)
        danmakuContext =
            DanmakuContext.create()
                .setDanmakuStyle(IDisplayer.DANMAKU_STYLE_STROKEN, 3f)
                .setDuplicateMergingEnabled(false)
                .setScrollSpeedFactor(1.2f)
                .setScaleTextSize(1.2f)
                .setCacheStuffer(SpannedCacheStuffer(), null)
                .setMaximumLines(maxLines)
                .preventOverlapping(overlapping)
        view.setCallback(
            object : DrawHandler.Callback {
                override fun updateTimer(timer: DanmakuTimer) = Unit

                override fun drawingFinished() = Unit

                override fun danmakuShown(danmaku: BaseDanmaku) = Unit

                override fun prepared() {
                    prepared = true
                    view.start()
                    if (visible) view.show() else view.hide()
                    syncToPlayerPosition()
                }
            },
        )
        view.enableDanmakuDrawingCache(true)
    }

    fun setVisible(show: Boolean) {
        visible = show
        danmakuView?.let { if (show) it.show() else it.hide() }
    }

    fun isVisible(): Boolean = visible

    fun loadFromUrl(url: String) {
        pendingUrl = url
        attachIfNeeded()
        val host = danmakuView?.parent as? ViewGroup ?: playerView
        executor.execute {
            try {
                val xml = readUrl(url)
                val stream = xml.byteInputStream()
                val newParser = createParser(stream)
                host.post {
                    parser = newParser
                    prepareDanmaku(forceReload = true)
                }
            } catch (_: Exception) {
                // ignore load failures
            }
        }
    }

    fun currentUrl(): String? = pendingUrl

    fun onPrepared() = prepareDanmaku()

    fun onPlaybackStart() {
        attachIfNeeded()
        val view = danmakuView ?: return
        if (!view.isPrepared) {
            prepareDanmaku()
            return
        }
        val positionMs = playerView.currentPositionWhenPlaying.coerceAtLeast(0L)
        view.seekTo(positionMs)
        if (view.isPaused) {
            view.resume()
        } else {
            view.start()
        }
        if (visible) view.show() else view.hide()
    }

    fun onPlaybackComplete() {
        val view = danmakuView ?: return
        if (view.isPrepared) {
            view.pause()
        }
    }

    fun onPause() {
        if (danmakuView?.isPrepared == true) {
            danmakuView?.pause()
        }
    }

    fun onResume() {
        if (danmakuView?.isPrepared == true && danmakuView?.isPaused == true) {
            danmakuView?.resume()
        }
    }

    fun onSeek(positionMs: Long) {
        if (danmakuView?.isPrepared == true) {
            danmakuView?.seekTo(positionMs)
        }
    }

    fun syncToPlayerPosition() {
        onSeek(playerView.currentPositionWhenPlaying)
    }

    fun release() {
        releaseViewOnly()
        parser = null
        pendingUrl = null
        visible = false
        executor.shutdownNow()
    }

    private fun releaseViewOnly() {
        danmakuView?.release()
        danmakuView = null
        prepared = false
    }

    private fun prepareDanmaku(forceReload: Boolean = false) {
        val view = danmakuView ?: return
        val p = parser ?: emptyParser()
        if (view.isPrepared) {
            if (!forceReload) {
                syncToPlayerPosition()
                if (visible) view.show() else view.hide()
                return
            }
            view.release()
            prepared = false
        }
        view.prepare(p, danmakuContext)
    }

    private fun createParser(stream: InputStream): BaseDanmakuParser {
        val loader: ILoader = DanmakuLoaderFactory.create(DanmakuLoaderFactory.TAG_BILI)
        loader.load(stream)
        val parser = BiliDanmukuParser()
        val dataSource: IDataSource<*> = loader.dataSource
        parser.load(dataSource)
        return parser
    }

    private fun emptyParser(): BaseDanmakuParser =
        object : BaseDanmakuParser() {
            override fun parse(): Danmakus = Danmakus()
        }

    private fun readUrl(urlString: String): String {
        when {
            urlString.startsWith("file://", ignoreCase = true) -> {
                val path = Uri.parse(urlString).path ?: return ""
                return File(path).readText()
            }
            urlString.startsWith("/") -> {
                return File(urlString).readText()
            }
        }
        val connection = URL(urlString).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.connect()
        connection.inputStream.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream)).use { reader ->
                val builder = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    builder.append(line).append('\n')
                }
                return builder.toString()
            }
        }
    }
}
