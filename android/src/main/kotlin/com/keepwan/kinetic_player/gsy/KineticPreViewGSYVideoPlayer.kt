package com.keepwan.kinetic_player.gsy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.LruCache
import android.view.View
import android.widget.ImageView
import android.widget.RelativeLayout
import android.widget.SeekBar
import com.keepwan.kinetic_player.R
import com.shuyu.gsyvideoplayer.preview.GSYVideoPreviewFrame
import com.shuyu.gsyvideoplayer.preview.GSYVideoPreviewProvider
import com.shuyu.gsyvideoplayer.preview.GSYVideoPreviewVttParser
import com.shuyu.gsyvideoplayer.video.base.GSYBaseVideoPlayer
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.Charset
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * WebVTT seek preview using GSY demo layout [R.layout.kinetic_video_layout_preview].
 */
class KineticPreViewGSYVideoPlayer : KineticGSYVideoPlayer {

    constructor(context: Context) : super(context)

    constructor(context: Context, fullFlag: Boolean) : super(context, fullFlag)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var previewLayout: RelativeLayout? = null
    private var previewImage: ImageView? = null
    private var isFromUser = false
    private var openPreview = true
    private var preProgress = -2
    private var previewVttUrl: String? = null
    private var previewProvider: GSYVideoPreviewProvider? = null
    private var previewLoadId = 0
    private var previewImageRequestId = 0

    override fun getLayoutId(): Int = R.layout.kinetic_video_layout_preview

    override fun init(context: Context) {
        super.init(context)
        previewLayout = findViewById(R.id.preview_layout)
        previewImage = findViewById(R.id.preview_image)
        previewImage?.scaleType = ImageView.ScaleType.CENTER_CROP
        uiConfig.previewVttUrl?.let { setPreviewVttUrl(it) }
    }

    override fun onProgressChanged(
        seekBar: SeekBar,
        progress: Int,
        fromUser: Boolean,
    ) {
        super.onProgressChanged(seekBar, progress, fromUser)
        if (!fromUser || !canShowPreview()) return

        val width = seekBar.width
        val time = progress.toLong() * duration / 100
        val halfPreview = resources.getDimension(R.dimen.seek_bar_image) / 2f
        val offset = ((width - halfPreview) / 100 * progress).toInt()
        showPreview(time)

        val layoutParams = previewLayout?.layoutParams as? RelativeLayout.LayoutParams ?: return
        layoutParams.leftMargin = offset
        previewLayout?.layoutParams = layoutParams
        if (mHadPlay) {
            preProgress = progress
        }
    }

    override fun onStartTrackingTouch(seekBar: SeekBar) {
        super.onStartTrackingTouch(seekBar)
        if (!canShowPreview()) return
        isFromUser = true
        previewLayout?.visibility = View.VISIBLE
        preProgress = -2
    }

    override fun onStopTrackingTouch(seekBar: SeekBar) {
        if (canShowPreview()) {
            if (preProgress >= 0) {
                seekBar.progress = preProgress
            }
            super.onStopTrackingTouch(seekBar)
            isFromUser = false
            previewLayout?.visibility = View.GONE
        } else {
            super.onStopTrackingTouch(seekBar)
        }
    }

    override fun setTextAndProgress(secProgress: Int) {
        if (isFromUser) return
        super.setTextAndProgress(secProgress)
    }

    override fun cloneParams(
        from: GSYBaseVideoPlayer?,
        to: GSYBaseVideoPlayer?,
    ) {
        super.cloneParams(from, to)
        val fromPreview = from as? KineticPreViewGSYVideoPlayer ?: return
        val toPreview = to as? KineticPreViewGSYVideoPlayer ?: return
        toPreview.openPreview = fromPreview.openPreview
        toPreview.previewVttUrl = fromPreview.previewVttUrl
        toPreview.previewProvider = fromPreview.previewProvider
        if (toPreview.previewProvider == null && !toPreview.previewVttUrl.isNullOrEmpty()) {
            toPreview.setPreviewVttUrl(toPreview.previewVttUrl)
        }
    }

    override fun startWindowFullscreen(
        context: Context,
        actionBar: Boolean,
        statusBar: Boolean,
    ): GSYBaseVideoPlayer? = super.startWindowFullscreen(context, actionBar, statusBar)

    fun setOpenPreview(enabled: Boolean) {
        openPreview = enabled
    }

    fun setPreviewVttUrl(url: String?) {
        previewVttUrl = url
        previewProvider = null
        val loadId = ++previewLoadId
        if (url.isNullOrEmpty()) return
        loadPreviewVtt(url, loadId)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        previewLoadId++
        previewImageRequestId++
        previewProvider?.release()
        previewProvider = null
    }

    private fun canShowPreview(): Boolean {
        return openPreview &&
            previewProvider != null &&
            !previewProvider!!.frames.isEmpty()
    }

    private fun showPreview(timeMs: Long) {
        val frame = previewProvider?.getPreviewFrame(timeMs) ?: return
        val imageView = previewImage ?: return
        val requestId = ++previewImageRequestId
        PREVIEW_EXECUTOR.execute {
            val bitmap = loadPreviewBitmap(frame)
            mainHandler.post {
                if (requestId != previewImageRequestId) return@post
                imageView.setImageBitmap(bitmap)
            }
        }
    }

    private fun loadPreviewBitmap(frame: GSYVideoPreviewFrame): Bitmap? {
        val source = loadBitmap(frame.imageUrl) ?: return null
        return if (frame.hasCrop()) {
            cropBitmap(source, frame.cropX, frame.cropY, frame.cropWidth, frame.cropHeight)
        } else {
            source
        }
    }

    private fun loadPreviewVtt(
        url: String,
        loadId: Int,
    ) {
        PREVIEW_EXECUTOR.execute {
            try {
                val provider = GSYVideoPreviewVttParser.parse(readUrl(url), url)
                mainHandler.post {
                    if (loadId == previewLoadId && url == previewVttUrl) {
                        previewProvider = provider
                    }
                }
            } catch (_: Exception) {
                mainHandler.post {
                    if (loadId == previewLoadId && url == previewVttUrl) {
                        previewProvider = null
                    }
                }
            }
        }
    }

    private fun readUrl(urlString: String): String {
        val connection = URL(urlString).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.requestMethod = "GET"
        connection.connect()
        connection.inputStream.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream, Charset.forName("UTF-8"))).use { reader ->
                val builder = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    builder.append(line).append('\n')
                }
                return builder.toString()
            }
        }
    }

    companion object {
        private val PREVIEW_EXECUTOR: ExecutorService = Executors.newSingleThreadExecutor()
        private val BITMAP_CACHE =
            LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 1024 / 8).toInt())

        private fun loadBitmap(url: String): Bitmap? {
            BITMAP_CACHE.get(url)?.let { return it }
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.connect()
            val bitmap =
                connection.inputStream.use { stream ->
                    BitmapFactory.decodeStream(stream)
                } ?: return null
            BITMAP_CACHE.put(url, bitmap)
            return bitmap
        }

        private fun cropBitmap(
            source: Bitmap,
            x: Int,
            y: Int,
            width: Int,
            height: Int,
        ): Bitmap {
            val safeX = x.coerceIn(0, source.width - 1)
            val safeY = y.coerceIn(0, source.height - 1)
            val safeWidth = width.coerceIn(1, source.width - safeX)
            val safeHeight = height.coerceIn(1, source.height - safeY)
            return Bitmap.createBitmap(source, safeX, safeY, safeWidth, safeHeight)
        }
    }
}

private val GSYVideoPreviewProvider.frames
    get() = getFrames()
