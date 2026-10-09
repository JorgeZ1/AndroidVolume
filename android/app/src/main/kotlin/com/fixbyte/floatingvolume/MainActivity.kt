package com.fixbyte.floatingvolume

import NativeApi
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.lifecycle.lifecycleScope
import com.fixbyte.floatingvolume.bloc.PositionBloc
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc
import com.fixbyte.floatingvolume.bloc.SystemOrientationBloc
import com.fixbyte.floatingvolume.bloc.SystemVolumeBloc
import com.fixbyte.floatingvolume.bloc.SystemVolumeInPercentageBloc
import com.fixbyte.floatingvolume.bloc.VisibilityBloc
import com.fixbyte.floatingvolume.pigeon_impl.FloatingVolumeVisibilityStreamHandlerImpl
import com.fixbyte.floatingvolume.pigeon_impl.NativeApiImpl
import com.fixbyte.floatingvolume.pigeon_impl.ServiceStatusStreamHandlerImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val settingsStreamHandler = SettingsStreamHandler()

    override fun onDestroy() {
        TechnicalMonitoring.state("activity_state", "destroyed")
        settingsStreamHandler.dispose()
        super.onDestroy()
    }
    override fun onResume() {
        super.onResume()
        TechnicalMonitoring.state("activity_state", "resumed")
    }
    override fun onPause() {
        TechnicalMonitoring.state("activity_state", "paused")
        super.onPause()
    }
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
            return

        val name = "Floating Volume"
        val descriptionText = NativeLanguage.text(this,
            "Channel for Floating Volume notifications",
            "Canal de notificaciones de Floating Volume")
        val importance = NotificationManager.IMPORTANCE_DEFAULT
        val channel = NotificationChannel(Const.NOTIFICATION_CHANNEL_ID, name, importance).apply {
            description = descriptionText
        }
        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TechnicalMonitoring.state("activity_state", "created")


        val c = this
        val audioManager = c.getSystemService(AUDIO_SERVICE) as android.media.AudioManager

        // Store the device manufacturer so the Flutter UI can detect OEM skins
        // (MIUI, ColorOS, One UI) and show compatibility guidance to the user.
        sharedPrefs.edit()
            .putString("device_manufacturer", Build.MANUFACTURER)
            .apply()

        lifecycleScope.apply {
            /**
             * Create the notification channel for the service.
             * This is required for Android O and above to show notifications.
             */
            inMain {
                createNotificationChannel()
            }


            /**
             * [SystemVolumeBloc] is responsible for managing the system volume.
             */
            // Initialize the SystemVolumeBloc and start observing system volume changes.
            inIO {
                SystemVolumeBloc.initialize(c)
                SystemVolumeBloc.observeSystemVolume(c)
            }
            /// Handle events for the SystemVolumeBloc.
            inIO {
                SystemVolumeBloc.handleEvents(c)
            }

            /**
             * [SystemVolumeInPercentageBloc]
             */
            inIO {
                SystemVolumeInPercentageBloc.initialize(audioManager)
                SystemVolumeInPercentageBloc.listenToVolumeChange(audioManager)
            }


            /**
             * [SystemOrientationBloc]
             */
            inIO {
                SystemOrientationBloc.initialize(c)
            }
            inIO {
                SystemOrientationBloc.observeSystemOrientation(c)
            }



            /**
             * [PositionBloc]
             */
            inIO {
                PositionBloc.initialize(c)
            }
            inIO {
                PositionBloc.handleOrientationChanges(c)
            }
            inIO {
                PositionBloc.handleEvents(c)
            }





            /**
             * [ServiceStatusBloc]
             */
            inIO {
                ServiceStatusBloc.initializeState(c)
                ServiceStatusBloc.registerEvents(c)
            }




            /**
             * [VisibilityBloc]
             */
            inIO {
                VisibilityBloc.registerEvents()
            }
            inIO {
                VisibilityBloc.handleServiceStatusChanges()
            }
        }

    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "floating_volume/monitoring")
            .setMethodCallHandler { call, result ->
                if (call.method == "setEnabled") {
                    TechnicalMonitoring.enabledOverride = call.arguments as? Boolean ?: false
                    result.success(null)
                } else if (call.method == "selfTest" && packageName.endsWith(".debug")) {
                    val diagnostic = TechnicalMonitoring.begin(DiagnosticOperation.CHANNEL)
                    TechnicalMonitoring.event("native_monitoring_self_test")
                    TechnicalMonitoring.error("native_self_test", IllegalStateException("synthetic"))
                    TechnicalMonitoring.measure("native_monitoring_self_test") {
                        TechnicalMonitoring.state("self_test", "true")
                    }
                    android.util.Log.i("TechnicalMonitoring", "Native synthetic event recorded")
                    TechnicalMonitoring.finish(DiagnosticOperation.CHANNEL, diagnostic)
                    result.success(null)
                } else result.notImplemented()
            }

        lifecycleScope.apply {
            inMain {
                NativeApi.setUp(
                    flutterEngine.dartExecutor.binaryMessenger,
                    NativeApiImpl(context, lifecycleScope)
                )
            }

            inMain {
                ServiceStatusStreamHandler.register(
                    flutterEngine.dartExecutor.binaryMessenger,
                    ServiceStatusStreamHandlerImpl(lifecycleScope)
                )
            }

            inMain {
                FloatingVolumeVisibilityStreamHandler.register(
                    flutterEngine.dartExecutor.binaryMessenger,
                    FloatingVolumeVisibilityStreamHandlerImpl(lifecycleScope)
                )
            }

            inMain {
                // Load persisted settings so they're ready before the service starts
                WidgetSettings.load(sharedPrefs, getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE))
                EventChannel(flutterEngine.dartExecutor.binaryMessenger, "floating_volume/settings_changes")
                    .setStreamHandler(settingsStreamHandler)

                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    "floating_volume/settings",
                ).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "reportDiagnostics" -> {
                            @Suppress("DEPRECATION")
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(mapOf(
                                "manufacturer" to android.os.Build.MANUFACTURER,
                                "model" to android.os.Build.MODEL,
                                "android_sdk" to android.os.Build.VERSION.SDK_INT,
                                "app_version" to (info.versionName ?: "unknown"),
                                "version_code" to if (android.os.Build.VERSION.SDK_INT >= 28)
                                    info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong(),
                            ))
                        }
                        "refreshLanguage" -> {
                            createNotificationChannel()
                            FloatingVolumeService.notifyLanguageChanged()
                            result.success(null)
                        }
                        "getSettings" -> result.success(WidgetSettings.snapshot())
                        "getButtonCornerRadius" -> result.success(WidgetSettings.buttonCornerRadius.toDouble())
                        "updateSettings", "restoreSection" -> {
                            try {
                                val previousStream = WidgetSettings.selectedAudioStream
                                val snapshot = if (call.method == "restoreSection") {
                                    WidgetSettings.restore(call.argument<String>("section") ?: "", sharedPrefs)
                                } else {
                                    @Suppress("UNCHECKED_CAST")
                                    val changes = call.arguments as? Map<String, Any?> ?: emptyMap()
                                    WidgetSettings.update(changes, sharedPrefs)
                                }
                                if (previousStream != WidgetSettings.selectedAudioStream) {
                                    lifecycleScope.inIO {
                                        SystemVolumeBloc.event.emit(SystemVolumeBloc.Event.SelectStream(WidgetSettings.selectedAudioStream))
                                    }
                                }
                                result.success(snapshot)
                            } catch (error: IllegalArgumentException) {
                                result.error("invalid_settings", error.message, null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }
}

