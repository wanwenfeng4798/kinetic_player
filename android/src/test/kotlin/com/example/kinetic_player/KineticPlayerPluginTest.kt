package com.example.kinetic_player

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.platform.PlatformViewRegistry
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.mockito.ArgumentCaptor
import org.mockito.Mockito

class KineticPlayerPluginTest {
    @Test
    fun `registers GSY platform view factory only`() {
        val plugin = KineticPlayerPlugin()
        val binding = Mockito.mock(FlutterPlugin.FlutterPluginBinding::class.java)
        val registry = Mockito.mock(PlatformViewRegistry::class.java)
        val messenger = Mockito.mock(io.flutter.plugin.common.BinaryMessenger::class.java)

        Mockito.`when`(binding.platformViewRegistry).thenReturn(registry)
        Mockito.`when`(binding.binaryMessenger).thenReturn(messenger)

        plugin.onAttachedToEngine(binding)

        val viewTypeCaptor = ArgumentCaptor.forClass(String::class.java)
        Mockito.verify(registry, Mockito.times(1))
            .registerViewFactory(viewTypeCaptor.capture(), Mockito.any())

        assertEquals(PlayerConstants.GSY_VIEW_TYPE, viewTypeCaptor.value)
    }
}
