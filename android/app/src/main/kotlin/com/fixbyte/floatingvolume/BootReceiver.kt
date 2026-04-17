package com.fixbyte.floatingvolume

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc

/**
 * Receives BOOT_COMPLETED and MY_PACKAGE_REPLACED broadcasts.
 *
 * On devices with aggressive memory management (MIUI, ColorOS, One UI),
 * background services are killed on every reboot and do not auto-restart.
 * This receiver auto-relaunches [FloatingVolumeService] if the user had
 * it enabled before the device was powered off.
 *
 * Requires:
 *   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
 *   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
 *
 * Registered in AndroidManifest.xml with:
 *   android:exported="true"  (required for BOOT_COMPLETED on Android 12+)
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        val shouldHandle = action == Intent.ACTION_BOOT_COMPLETED ||
                action == Intent.ACTION_MY_PACKAGE_REPLACED ||
                action == "android.intent.action.QUICKBOOT_POWERON" // HTC/Huawei variant

        if (!shouldHandle) return

        Log.d(TAG, "Boot/update detected (action=$action). Checking if service should restart.")

        // Only restart if the user had the service enabled before reboot
        if (!ServiceStatusBloc.wasEnabledBeforeReboot(context)) {
            Log.d(TAG, "Service was not enabled before reboot — skipping auto-start.")
            return
        }

        Log.d(TAG, "Auto-starting FloatingVolumeService after boot.")

        try {
            val serviceIntent = Intent(context, FloatingVolumeService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Use startForegroundService to guarantee the 5-second window
                // before startForeground() must be called.
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to auto-start service on boot: ${e.message}", e)
        }
    }
}
