package com.example.kinetic_player_example

import android.content.res.Configuration
import com.keepwan.kinetic_player.KineticPlayerPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        KineticPlayerPlugin.handleConfigurationChanged(this, newConfig)
    }

    override fun onBackPressed() {
        if (KineticPlayerPlugin.handleBackPressed(this)) {
            return
        }
        super.onBackPressed()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        KineticPlayerPlugin.handleUserLeaveHint(this)
    }
}
