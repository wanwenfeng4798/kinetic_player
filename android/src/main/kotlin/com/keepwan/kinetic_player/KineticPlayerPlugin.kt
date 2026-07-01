package com.keepwan.kinetic_player

import android.app.Activity
import android.content.res.Configuration
import com.keepwan.kinetic_player.gsy.GsyPlatformViewRegistry
import com.keepwan.kinetic_player.gsy.GsyPlayerLifecycleRegistry
import com.keepwan.kinetic_player.gsy.GsyVideoViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin

class KineticPlayerPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        GsyPlatformViewRegistry.attach(messenger)
        binding.platformViewRegistry.registerViewFactory(
            PlayerConstants.GSY_VIEW_TYPE,
            GsyVideoViewFactory(),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    companion object {
        /** Forward from host Activity.onConfigurationChanged for GSY orientation fullscreen. */
        @JvmStatic
        fun handleConfigurationChanged(
            activity: Activity,
            newConfig: Configuration,
        ) {
            GsyPlayerLifecycleRegistry.onConfigurationChanged(activity, newConfig)
        }

        /** Forward from host Activity.onBackPressed for GSY window fullscreen exit. */
        @JvmStatic
        fun handleBackPressed(activity: Activity): Boolean =
            GsyPlayerLifecycleRegistry.onBackPressed(activity)
    }
}
