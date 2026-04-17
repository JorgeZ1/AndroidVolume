package com.github.mkalmousli.floating_volume

import NativeApi
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.lifecycle.lifecycleScope
import com.github.mkalmousli.floating_volume.bloc.PositionBloc
import com.github.mkalmousli.floating_volume.bloc.ServiceStatusBloc
import com.github.mkalmousli.floating_volume.bloc.SystemOrientationBloc
import com.github.mkalmousli.floating_volume.bloc.SystemVolumeBloc
import com.github.mkalmousli.floating_volume.bloc.SystemVolumeInPercentageBloc
import com.github.mkalmousli.floating_volume.bloc.VisibilityBloc
import com.github.mkalmousli.floating_volume.pigeon_impl.FloatingVolumeVisibilityStreamHandlerImpl
import com.github.mkalmousli.floating_volume.pigeon_impl.NativeApiImpl
import com.github.mkalmousli.floating_volume.pigeon_impl.ServiceStatusStreamHandlerImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
            return

        val name = "Floating Volume Channel"
        val descriptionText = "Channel for Floating Volume notifications"
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
                WidgetSettings.load(sharedPrefs)

                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    "floating_volume/settings",
                ).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "setOpacity" -> {
                            val v = (call.argument<Double>("value") ?: 1.0).toFloat()
                            WidgetSettings.opacity = v
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setColorMode" -> {
                            val mode = call.argument<String>("mode") ?: "auto"
                            WidgetSettings.colorMode = when (mode) {
                                "blue" -> WidgetSettings.ColorMode.BLUE
                                "dark" -> WidgetSettings.ColorMode.DARK
                                else   -> WidgetSettings.ColorMode.AUTO
                            }
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setStyle" -> {
                            val s = call.argument<String>("style") ?: "android"
                            WidgetSettings.style = WidgetSettings.Style.fromName(s)
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setPinned" -> {
                            val pinned = call.argument<Boolean>("pinned") ?: false
                            WidgetSettings.isPinned = pinned
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setUseSystemVolume" -> {
                            val v = call.argument<Boolean>("value") ?: false
                            WidgetSettings.useSystemVolume = v
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setCreativeAnimSpeed" -> {
                            val v = call.argument<Double>("value") ?: 1.0
                            WidgetSettings.creativeAnimSpeed = v.toFloat()
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setCreativeGlowIntensity" -> {
                            val v = call.argument<Double>("value") ?: 1.0
                            WidgetSettings.creativeGlowIntensity = v.toFloat()
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setButtonSize" -> {
                            WidgetSettings.buttonSize = call.argument<Int>("value") ?: 52
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setButtonCornerRadius" -> {
                            WidgetSettings.buttonCornerRadius = (call.argument<Double>("value") ?: 0.5).toFloat()
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setButtonGap" -> {
                            WidgetSettings.buttonGap = call.argument<Int>("value") ?: 10
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorOpacity" -> {
                            WidgetSettings.indicatorOpacity = (call.argument<Double>("value") ?: 1.0).toFloat()
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorHeight" -> {
                            WidgetSettings.indicatorHeight = call.argument<Int>("value") ?: 160
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorWidth" -> {
                            WidgetSettings.indicatorWidth = call.argument<Int>("value") ?: 48
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorGap" -> {
                            WidgetSettings.indicatorGap = call.argument<Int>("value") ?: 10
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorHideDelay" -> {
                            WidgetSettings.indicatorHideDelay = call.argument<Int>("value") ?: 1800
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        "setIndicatorAnimation" -> {
                            WidgetSettings.indicatorAnimation = call.argument<String>("value") ?: "fade"
                            WidgetSettings.save(sharedPrefs)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }
}

