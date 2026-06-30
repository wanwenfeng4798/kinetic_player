package com.keepwan.kinetic_player

import com.keepwan.kinetic_player.gsy.GsyPlatformViewRegistry
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
}
