package com.keepwan.kinetic_player.gsy

import android.app.Activity
import android.content.res.Configuration
import android.os.Build
import com.shuyu.gsyvideoplayer.GSYVideoManager
import java.lang.ref.WeakReference

/**
 * Tracks active [GsyNativePlayer] instances for Activity lifecycle events
 * (configuration changes, back press) required by GSY window fullscreen.
 */
object GsyPlayerLifecycleRegistry {
    private val players = LinkedHashSet<WeakReference<GsyNativePlayer>>()

    fun register(player: GsyNativePlayer) {
        players.removeAll { it.get() == null || it.get() === player }
        players.add(WeakReference(player))
    }

    fun unregister(player: GsyNativePlayer) {
        players.removeAll { it.get() == null || it.get() === player }
    }

    fun onConfigurationChanged(
        activity: Activity,
        newConfig: Configuration,
    ) {
        activePlayers().forEach { it.onConfigurationChanged(activity, newConfig) }
    }

    fun onBackPressed(activity: Activity): Boolean =
        GSYVideoManager.backFromWindowFull(activity)

    fun onUserLeaveHint(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activePlayers()
            .firstOrNull { it.shouldAutoEnterPictureInPicture() }
            ?.enterPictureInPicture()
    }

    private fun activePlayers(): List<GsyNativePlayer> {
        players.removeAll { it.get() == null }
        return players.mapNotNull { it.get() }
    }
}
