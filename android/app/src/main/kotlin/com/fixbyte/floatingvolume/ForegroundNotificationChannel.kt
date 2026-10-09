package com.fixbyte.floatingvolume

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/** Startup must also work without an Activity (boot and sticky recreation). */
object ForegroundNotificationChannel {
    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(Const.NOTIFICATION_CHANNEL_ID) != null) return
        manager.createNotificationChannel(NotificationChannel(
            Const.NOTIFICATION_CHANNEL_ID, "Floating Volume", NotificationManager.IMPORTANCE_DEFAULT,
        ))
    }
}
