package com.keepwan.kinetic_player.gsy

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.keepwan.kinetic_player.CommonPlayerState
import com.keepwan.kinetic_player.PlayerConstants

class GsyVideoPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    creationParams: Map<String, Any?>?,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, PlayerConstants.gsyChannelName(viewId))
    private val uiConfig = GsyUiConfig.fromCreationParams(creationParams)
    private val player =
        GsyNativePlayer(
            context,
            object : GsyPlayerCallbacks {
                override fun onPlayerStateChanged(state: CommonPlayerState) {
                    channel.invokeMethod(
                        "onPlayerStateChanged",
                        mapOf("state" to state.index),
                    )
                }

                override fun onPositionChanged(positionMs: Long, durationMs: Long) {
                    channel.invokeMethod(
                        "onPositionChanged",
                        mapOf(
                            "position" to positionMs,
                            "duration" to durationMs,
                        ),
                    )
                }
            },
            initialUiConfig = uiConfig,
        )

    init {
        channel.setMethodCallHandler(this)
        player.applyUiConfig(uiConfig)
        val url = creationParams?.get("url") as? String
        if (!url.isNullOrEmpty()) {
            player.setUrl(url)
        }
    }

    override fun getView() = player.getView()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                player.startPlayLogic()
                result.success(null)
            }
            "pause" -> {
                player.onVideoPause()
                result.success(null)
            }
            "seekTo" -> {
                val position = call.argument<Int>("position") ?: 0
                player.seekTo(position)
                result.success(null)
            }
            "setScaleMode" -> {
                val mode = call.argument<Int>("mode") ?: 0
                player.setShowType(mode)
                result.success(null)
            }
            "gsySwitchRenderCore" -> {
                val core = call.argument<Int>("core") ?: 0
                player.changeRenderCore(core)
                result.success(null)
            }
            "gsyToggleDanmaku" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                player.toggleDanmaku(enabled)
                result.success(null)
            }
            "gsyStartFullscreen" -> {
                player.startFullscreen()
                result.success(null)
            }
            "gsySetPreviewVttUrl" -> {
                player.setPreviewVttUrl(call.argument<String>("url"))
                result.success(null)
            }
            "gsySetUiConfig" -> {
                @Suppress("UNCHECKED_CAST")
                val ui = call.argument<Map<String, Any?>>("gsyUi")
                player.applyUiConfig(GsyUiConfig.fromCreationParams(mapOf("gsyUi" to ui)))
                result.success(null)
            }
            "gsySetSpeed" -> {
                val speed = call.argument<Double>("speed")?.toFloat() ?: 1f
                player.setSpeed(speed)
                result.success(null)
            }
            "gsySetLooping" -> {
                player.setLooping(call.argument<Boolean>("looping") ?: false)
                result.success(null)
            }
            "sgSetVRMode", "sgSetSyncGroupId" -> result.notImplemented()
            "dispose" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        player.release()
    }
}
