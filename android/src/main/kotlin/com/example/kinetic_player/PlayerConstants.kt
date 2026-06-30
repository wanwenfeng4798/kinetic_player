package com.example.kinetic_player

object PlayerConstants {
    const val GSY_VIEW_TYPE = "com.example.player/gsy_view_ui"

    fun gsyChannelName(viewId: Int): String = "com.example.player/gsy_$viewId"
}

enum class CommonPlayerState(val index: Int) {
    IDLE(0),
    BUFFERING(1),
    READY(2),
    PLAYING(3),
    PAUSED(4),
    COMPLETED(5),
    ERROR(6),
}
