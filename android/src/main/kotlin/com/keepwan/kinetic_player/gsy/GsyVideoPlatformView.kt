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
    private val playTag =
        (creationParams?.get("playTag") as? String)?.takeIf { it.isNotEmpty() }
            ?: "kinetic_$viewId"
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
            playTag = playTag,
        )

    init {
        channel.setMethodCallHandler(this)
        player.applyUiConfig(uiConfig)
        val url = creationParams?.get("url") as? String
        if (!url.isNullOrEmpty()) {
            player.switchVideoSource(url, autoPlay = false)
        }
        @Suppress("UNCHECKED_CAST")
        val playlist = creationParams?.get("playlist") as? List<String>
        if (!playlist.isNullOrEmpty()) {
            player.setPlaylist(playlist)
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
            "stop" -> {
                player.stop()
                result.success(null)
            }
            "seekTo" -> {
                player.seekTo(call.argument<Int>("position") ?: 0)
                result.success(null)
            }
            "setScaleMode" -> {
                player.setScaleMode(call.argument<Int>("mode") ?: 0)
                result.success(null)
            }
            "setRate" -> {
                player.setSpeed(call.argument<Double>("rate")?.toFloat() ?: 1f)
                result.success(null)
            }
            "setVolume" -> {
                player.setVolume(call.argument<Double>("volume")?.toFloat() ?: 1f)
                result.success(null)
            }
            "setMute" -> {
                player.setMute(call.argument<Boolean>("muted") ?: false)
                result.success(null)
            }
            "switchVideoSource" -> {
                player.switchVideoSource(
                    call.argument<String>("url") ?: "",
                    call.argument<Boolean>("autoPlay") ?: true,
                )
                result.success(null)
            }
            "getAudioTracks" -> result.success(player.listAudioTracks())
            "selectAudioTrack" -> {
                val ok = player.selectAudioTrack(call.argument<Int>("index") ?: 0)
                if (ok) result.success(null) else result.error("TRACK", "Audio track not found", null)
            }
            "getVideoSize" -> result.success(player.getVideoSize())
            "setLooping" -> {
                player.setLooping(call.argument<Boolean>("looping") ?: false)
                result.success(null)
            }
            "captureFrame" -> {
                val high = call.argument<Boolean>("highQuality") ?: true
                val withView = call.argument<Boolean>("includeOverlay") ?: false
                player.takeScreenshot(
                    withView = withView,
                    high = high,
                ) { path -> result.success(path) }
            }
            "gsySwitchRenderCore" -> {
                val ok = player.changeRenderCore(call.argument<Int>("core") ?: 0)
                if (ok) result.success(null) else result.error("UNSUPPORTED", "Core not available (AliPlayer/custom)", null)
            }
            "gsyToggleDanmaku" -> {
                player.toggleDanmaku(call.argument<Boolean>("enabled") ?: false)
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
            "gsySetGsyShowType" -> {
                player.setGsyShowType(
                    call.argument<Int>("mode") ?: 0,
                    call.argument<Double>("customRatio")?.toFloat(),
                )
                result.success(null)
            }
            "gsySetRenderType" -> {
                player.setRenderType(call.argument<Int>("renderType") ?: GSY_RENDER_TEXTURE)
                result.success(null)
            }
            "gsySetEffectFilter" -> {
                player.setEffectFilter(call.argument<String>("name") ?: "none")
                result.success(null)
            }
            "gsyListEffectFilters" -> result.success(GsyEffectRegistry.effectNames)
            "gsySetRenderRotation" -> {
                player.setRenderRotation(call.argument<Int>("degrees") ?: 0)
                result.success(null)
            }
            "gsySetMirrorHorizontal" -> {
                player.setMirrorHorizontal(call.argument<Boolean>("enabled") ?: false)
                result.success(null)
            }
            "gsyGetNetSpeed" -> {
                result.success(
                    mapOf(
                        "bytesPerSecond" to player.getNetSpeedBytesPerSecond(),
                        "text" to player.getNetSpeedText(),
                    ),
                )
            }
            "gsySetSubtitleUrl" -> {
                player.setSubtitleUrl(
                    call.argument<String>("url") ?: "",
                    call.argument<String>("mimeType"),
                )
                result.success(null)
            }
            "gsySetSubtitleEnabled" -> {
                player.setSubtitleEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }
            "gsySetEmbeddedSubtitleText" -> {
                player.setEmbeddedSubtitleText(call.argument<String>("text"))
                result.success(null)
            }
            "gsySaveScreenshot" -> {
                player.saveScreenshot(
                    withView = call.argument<Boolean>("withView") ?: false,
                    high = call.argument<Boolean>("high") ?: false,
                ) { path -> result.success(path) }
            }
            "gsyStartGifRecording" -> {
                player.startGifRecording()
                result.success(null)
            }
            "gsyStopGifRecording" -> {
                player.stopGifRecording { path -> result.success(path) }
            }
            "gsySetPlaylist" -> {
                @Suppress("UNCHECKED_CAST")
                val urls = call.argument<List<String>>("urls") ?: emptyList()
                player.setPlaylist(urls, call.argument<Int>("startIndex") ?: 0)
                result.success(null)
            }
            "gsyPlayNextInPlaylist" -> result.success(player.playNextInPlaylist())
            "gsyPlayWithPreRollAd" -> {
                player.playWithPreRollAd(
                    call.argument<String>("adUrl") ?: "",
                    call.argument<String>("contentUrl") ?: "",
                )
                result.success(null)
            }
            "gsySetPurePlayMode" -> {
                player.setPurePlayMode(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }
            "gsyEnterPictureInPicture" -> result.success(player.enterPictureInPicture())
            "gsyReleaseAllVideos" -> {
                player.releaseAllVideos()
                result.success(null)
            }
            "gsySetDanmakuUrl" -> {
                player.setDanmakuUrl(call.argument<String>("url"))
                result.success(null)
            }
            "gsySetMidRollAds" -> {
                @Suppress("UNCHECKED_CAST")
                val ads = call.argument<List<Map<String, Any>>>("ads") ?: emptyList()
                player.setMidRollAds(ads)
                result.success(null)
            }
            "gsyListExoVideoTracks" -> result.success(player.listExoVideoTracks())
            "gsySelectExoVideoTrack" -> {
                val ok = player.selectExoVideoTrack(call.argument<Int>("index") ?: 0)
                result.success(ok)
            }
            "gsySetWatermarkUrl" -> {
                player.setWatermarkUrl(call.argument<String>("url"))
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

    companion object {
        const val GSY_RENDER_TEXTURE = 0
        const val GSY_RENDER_SURFACE = 1
        const val GSY_RENDER_GLSURFACE = 2
    }
}
