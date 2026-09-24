package com.fixbyte.floatingvolume

import android.Manifest
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import android.view.animation.DecelerateInterpolator
import androidx.core.animation.doOnEnd
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.fixbyte.floatingvolume.bloc.PositionBloc
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc
import com.fixbyte.floatingvolume.bloc.SystemVolumeBloc
import com.fixbyte.floatingvolume.bloc.VisibilityBloc
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.roundToInt

class FloatingVolumeService : Service() {
    private val scope = CoroutineScope(Job())

    companion object {
        const val NOTIFICATION_ID = 1
        const val TAG = "FloatingService"
        private const val KEY_SYSTEM_INDICATOR_SAVED = "system_indicator_position_saved"
        private const val KEY_SYSTEM_INDICATOR_X = "system_indicator_previous_x"
        private const val KEY_SYSTEM_INDICATOR_Y = "system_indicator_previous_y"
        private const val KEY_SYSTEM_INDICATOR_RIGHT = "system_indicator_previous_right"
    }

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        // Load persisted settings and register for live updates
        WidgetSettings.load(sharedPrefs)
        lastUseSystemVolume = WidgetSettings.useSystemVolume
        WidgetSettings.addListener(::onSettingsChanged)
        enforceStyleEntitlement()
        styleExpiryJob = scope.launch {
            while (isActive) {
                kotlinx.coroutines.delay(60_000L)
                withContext(Dispatchers.Main) { enforceStyleEntitlement() }
            }
        }
        scope.inIO { SystemVolumeBloc.event.emit(SystemVolumeBloc.Event.SelectStream(WidgetSettings.selectedAudioStream)) }
    }

    private fun onSettingsChanged() {
        val systemIndicatorChanged = lastUseSystemVolume != WidgetSettings.useSystemVolume
        lastUseSystemVolume = WidgetSettings.useSystemVolume
        newInMain {
            floatingMuteView.applyTheme()
            if (systemIndicatorChanged && isViewAttached) {
                updateSystemIndicatorSafePosition(WidgetSettings.useSystemVolume)
            }
            if (volumeIndicatorView != null) {
                volumeIndicatorView?.applyStyle()
                showVolumeIndicator()
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        floatingMuteView.dispatchConfigurationChanged(newConfig)
        volumeIndicatorView?.dispatchConfigurationChanged(newConfig)
        // A portrait X coordinate is not meaningful on the wider landscape
        // display. Reattach the control to its remembered lateral edge.
        floatingMuteView.postDelayed({
            if (isViewAttached) snapToEdge(save = false, preferredRight = preferredEdgeRight)
        }, 180L)
    }

    private val windowManager: WindowManager by lazy {
        getSystemService(WINDOW_SERVICE) as WindowManager
    }

    private val audioManager: AudioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private val floatingMuteView by lazy {
        FloatingVolumeView(this)
    }

    // ── Volume indicator overlay ─────────────────────────────────────────────
    private var volumeIndicatorView: VolumeIndicatorView? = null
    private var indicatorParams: LayoutParams? = null
    private var hideIndicatorJob: Job? = null
    private var isViewAttached = false
    private var mixerView: AudioMixerView? = null
    private var mixerParams: LayoutParams? = null
    private var hideMixerJob: Job? = null
    private var peekJob: Job? = null
    private var peekAnimator: ValueAnimator? = null
    private var isPeeking = false
    private var preferredEdgeRight: Boolean? = null
    private var lastScreenHeight = 0
    private var lastDndWarningAt = 0L
    private var styleExpiryJob: Job? = null
    private var lastUseSystemVolume = false

    private val flutterPreferences by lazy {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private fun styleUnlockName(style: WidgetSettings.Style): String? = when (style) {
        WidgetSettings.Style.RGB_AURORA -> "rgbAurora"
        WidgetSettings.Style.RGB_NEON -> "rgbNeon"
        WidgetSettings.Style.COSMIC -> "cosmic"
        WidgetSettings.Style.LAVA -> "lava"
        WidgetSettings.Style.GLACIER -> "glacier"
        WidgetSettings.Style.MATRIX -> "matrix"
        WidgetSettings.Style.RETROWAVE -> "retrowave"
        WidgetSettings.Style.CARDS -> "cards"
        else -> null
    }

    private fun isStyleEntitled(style: WidgetSettings.Style): Boolean {
        val unlockName = styleUnlockName(style) ?: return true
        val now = System.currentTimeMillis()
        val legacyExpiry = flutterPreferences.getLong("flutter.special_unlock_expiry", 0L)
        val styleExpiry = flutterPreferences.getLong(
            "flutter.special_unlock_${unlockName}_expiry",
            0L,
        )
        return maxOf(legacyExpiry, styleExpiry) > now
    }

    private fun enforceStyleEntitlement() {
        if (isStyleEntitled(WidgetSettings.style)) return
        Log.i(TAG, "Special style entitlement expired; reverting to Android")
        WidgetSettings.style = WidgetSettings.Style.ANDROID
        WidgetSettings.save(sharedPrefs)
        flutterPreferences.edit().putString("flutter.widget_style", "android").apply()
        if (isViewAttached) {
            floatingMuteView.applyTheme()
            volumeIndicatorView?.applyStyle()
        }
    }

    private var layoutParams =
        LayoutParams(
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") LayoutParams.TYPE_PHONE,
            LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).also {
            it.gravity = android.view.Gravity.TOP or android.view.Gravity.START
        }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).roundToInt()
    private fun stream() = WidgetSettings.selectedAudioStream

    /**
     * Overlay permission/token validity can change while a delayed gesture is
     * pending, particularly on older Huawei firmware. Never let that race crash
     * the foreground service.
     */
    private fun tryAddOverlay(view: View, params: LayoutParams, label: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot add $label: overlay permission is unavailable")
            return false
        }
        return try {
            windowManager.addView(view, params)
            true
        } catch (error: WindowManager.BadTokenException) {
            Log.w(TAG, "Cannot add $label: invalid overlay token", error)
            false
        } catch (error: SecurityException) {
            Log.w(TAG, "Cannot add $label: overlay permission was revoked", error)
            false
        } catch (error: IllegalStateException) {
            Log.w(TAG, "Cannot add $label: window state changed", error)
            false
        }
    }

    /**
     * Some OEMs (including MIUI) reject ring/notification changes while Do Not
     * Disturb is enabled unless the app has notification-policy access. Audio
     * control must never take down the floating service in that situation.
     */
    private fun setStreamVolumeSafely(stream: AudioStream, target: Int, flags: Int): Boolean = try {
        audioManager.setStreamVolume(stream.streamType, target, flags)
        true
    } catch (error: SecurityException) {
        Log.w(TAG, "Volume change blocked for $stream; Do Not Disturb policy access is required", error)
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastDndWarningAt >= 3_000L) {
            lastDndWarningAt = now
            android.widget.Toast.makeText(
                this,
                "No se puede cambiar este canal mientras No molestar está activo.",
                android.widget.Toast.LENGTH_SHORT,
            ).show()
        }
        false
    }

    private fun refreshIdleTimer() {
        peekJob?.cancel()
        if (!WidgetSettings.autoPeekEnabled || !isViewAttached || isPeeking) return
        peekJob = newInMain {
            kotlinx.coroutines.delay(WidgetSettings.autoPeekDelay.toLong())
            if (volumeIndicatorView == null && mixerView == null && quickMenuView == null) peekToEdge()
        }
    }

    private fun peekToEdge() {
        if (isPeeking || !isViewAttached) return
        val screenW = resources.displayMetrics.widthPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        // peekSize is exposed as screen pixels in the settings UI. Treating it
        // as dp made a 16 px tab become ~48 physical pixels on dense displays.
        val visible = WidgetSettings.peekSize.coerceIn(8, 24)
        // WindowManager clamps overlay coordinates inside the display. Move the
        // *content* instead of the window so only the recovery tab remains visible.
        val offset = if (layoutParams.x + widgetW / 2 < screenW / 2)
            -(widgetW - visible).toFloat()
        else
            (widgetW - visible).toFloat()
        isPeeking = true
        floatingMuteView.pauseStyleAnimation()
        floatingMuteView.alpha = WidgetSettings.opacity * 0.82f
        peekAnimator?.cancel()
        peekAnimator = ValueAnimator.ofFloat(floatingMuteView.translationX, offset).apply {
            duration = 220L
            interpolator = DecelerateInterpolator()
            addUpdateListener { floatingMuteView.translationX = it.animatedValue as Float }
            doOnEnd {
                if (isPeeking) floatingMuteView.translationX = offset
            }
            start()
        }
        Log.d(TAG, "Widget peeked at edge; offset=$offset visible=$visible")
    }

    private fun expandFromPeek() {
        if (!isPeeking) return
        isPeeking = false
        peekAnimator?.cancel()
        floatingMuteView.applyTheme()
        peekAnimator = ValueAnimator.ofFloat(floatingMuteView.translationX, 0f).apply {
            duration = 180L
            interpolator = DecelerateInterpolator()
            addUpdateListener { floatingMuteView.translationX = it.animatedValue as Float }
            doOnEnd {
                if (!isPeeking) floatingMuteView.translationX = 0f
                refreshIdleTimer()
            }
            start()
        }
    }

    // ---------------------------------------------------------------------------
    // Touch / Drag / Snap / Volume
    // ---------------------------------------------------------------------------

    @SuppressLint("ClickableViewAccessibility")
    fun configureTouchListener() {
        var startWindowX  = 0
        var startWindowY  = 0
        var startTouchX   = 0f
        var startTouchY   = 0f
        var isDragging    = false
        var longPressJob: Job? = null
        var longPressFired = false
        var consumePeekGesture = false
        val dragThreshold = dp(8).toFloat()

        floatingMuteView.handleIv.setOnTouchListener { _, event ->
            when (event.action) {

                MotionEvent.ACTION_DOWN -> {
                    if (isPeeking) {
                        // The recovery tab also starts a drag gesture. Keep its
                        // coordinates so a pull from the edge can reposition the
                        // widget in one continuous gesture.
                        startWindowX = layoutParams.x
                        startWindowY = layoutParams.y
                        startTouchX = event.rawX
                        startTouchY = event.rawY
                        isDragging = false
                        expandFromPeek()
                        // A simple tap only reveals the widget; a move past the
                        // threshold below clears this and finishes with snapToEdge.
                        consumePeekGesture = true
                        return@setOnTouchListener true
                    }
                    refreshIdleTimer()
                    startWindowX = layoutParams.x
                    startWindowY = layoutParams.y
                    startTouchX  = event.rawX
                    startTouchY  = event.rawY
                    isDragging   = false
                    longPressFired = false
                    longPressJob?.cancel()
                    longPressJob = newInMain {
                        kotlinx.coroutines.delay(550)
                        if (isViewAttached && floatingMuteView.isAttachedToWindow) {
                            longPressFired = showQuickMenu()
                            if (longPressFired) {
                                floatingMuteView.performHapticFeedback(
                                    android.view.HapticFeedbackConstants.LONG_PRESS,
                                )
                            }
                        }
                    }
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startTouchX
                    val dy = event.rawY - startTouchY

                    if (!isDragging && !WidgetSettings.isPinned &&
                            (abs(dx) > dragThreshold || abs(dy) > dragThreshold)) {
                        isDragging = true
                        // Do not let a pending unfold animation fight the drag.
                        peekAnimator?.cancel()
                        floatingMuteView.translationX = 0f
                        floatingMuteView.alpha = WidgetSettings.opacity
                        consumePeekGesture = false
                        longPressJob?.cancel()
                        hideQuickMenu()
                        longPressFired = false
                    }

                    if (isDragging) {
                        layoutParams.x = startWindowX + dx.toInt()
                        layoutParams.y = startWindowY + dy.toInt()
                        windowManager.updateViewLayout(floatingMuteView, layoutParams)
                        refreshIdleTimer()
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (consumePeekGesture) {
                        consumePeekGesture = false
                        return@setOnTouchListener true
                    }
                    longPressJob?.cancel()
                    if (isDragging) {
                        snapToEdge()
                    } else if (longPressFired) {
                        // The long-press menu is already showing; swallow the tap
                    } else {
                        val tapY  = event.y
                        val viewH = floatingMuteView.height
                        // height == 0 means the view hasn't been laid out yet; a tap
                        // would always resolve to "down". Fall back to the configured size.
                        val midY  = (viewH.takeIf { it > 0 }
                            ?: dp(WidgetSettings.buttonSize * 2 + WidgetSettings.buttonGap)) / 2f
                        val up    = tapY < midY
                        Log.d(TAG, "Tap: y=$tapY viewH=$viewH midY=$midY -> ${if (up) "UP" else "DOWN"}")
                        if (WidgetSettings.hapticFeedback) {
                            floatingMuteView.performHapticFeedback(
                                android.view.HapticFeedbackConstants.KEYBOARD_TAP,
                                android.view.HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING,
                            )
                        }
                        changeVolume(up)
                        floatingMuteView.flashButton(up)
                        refreshIdleTimer()
                    }
                    true
                }

                MotionEvent.ACTION_CANCEL -> {
                    consumePeekGesture = false
                    longPressJob?.cancel()
                    false
                }

                else -> false
            }
        }
    }

    // ── Quick menu (long-press) ───────────────────────────────────────────────

    private var quickMenuView: android.widget.LinearLayout? = null
    private var hideMenuJob: Job? = null

    /** Compact action bubbles shown beside the controls on long-press. */
    private fun showQuickMenu(): Boolean {
        hideQuickMenu()
        if (!isViewAttached || !floatingMuteView.isAttachedToWindow) return false

        val menu = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(dp(2), dp(2), dp(2), dp(2))
            setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_OUTSIDE) hideQuickMenu()
                false
            }
        }

        fun item(icon: Int, description: String, topMargin: Int = 0, onTap: () -> Unit) =
            android.widget.ImageButton(this).apply {
                setImageResource(icon)
                setColorFilter(android.graphics.Color.WHITE)
                contentDescription = description
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) tooltipText = description
                setPadding(dp(12), dp(12), dp(12), dp(12))
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.OVAL
                    setColor(android.graphics.Color.argb(238, 28, 28, 32))
                    setStroke(dp(1), android.graphics.Color.argb(75, 255, 255, 255))
                }
                elevation = dp(8).toFloat()
                layoutParams = android.widget.LinearLayout.LayoutParams(dp(48), dp(48)).apply {
                    this.topMargin = dp(topMargin)
                }
                setOnClickListener { hideQuickMenu(onHidden = onTap) }
            }

        menu.addView(item(R.drawable.ic_power_settings_new_24, "Desactivar botón") {
            scope.inIO { ServiceStatusBloc.event.emit(ServiceStatusBloc.Event.Stop) }
        })
        if (WidgetSettings.showAudioMixer) {
            menu.addView(item(R.drawable.ic_equalizer_24, "Mezclador de volumen", 8) {
                showAudioMixer()
            })
        }

        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH = floatingMuteView.height.takeIf { it > 0 } ?: dp(110)
        val isOnRight = layoutParams.x + widgetW / 2 > screenW / 2
        val menuW = dp(52)
        val actionCount = if (WidgetSettings.showAudioMixer) 2 else 1
        val menuH = dp(actionCount * 48 + (actionCount - 1) * 8 + 4)
        val params = LayoutParams(
            menuW,
            menuH,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") LayoutParams.TYPE_PHONE,
            LayoutParams.FLAG_NOT_FOCUSABLE or LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT,
        ).also {
            it.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            it.x = if (isOnRight) {
                (layoutParams.x - menuW - dp(10)).coerceAtLeast(dp(8))
            } else {
                (layoutParams.x + widgetW + dp(10)).coerceAtMost(screenW - menuW - dp(8))
            }
            it.y = (layoutParams.y + (widgetH - menuH) / 2)
                .coerceIn(dp(8), (screenH - menuH - dp(8)).coerceAtLeast(dp(8)))
        }

        if (!tryAddOverlay(menu, params, "quick menu")) return false
        quickMenuView = menu
        menu.alpha = 0f
        menu.scaleX = 0.92f
        menu.scaleY = 0.92f
        menu.translationX = if (isOnRight) dp(12).toFloat() else -dp(12).toFloat()
        menu.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .translationX(0f)
            .setDuration(180L)
            .setInterpolator(DecelerateInterpolator())
            .start()

        hideMenuJob?.cancel()
        hideMenuJob = newInMain {
            kotlinx.coroutines.delay(3500)
            hideQuickMenu()
        }
        return true
    }

    private fun hideQuickMenu(onHidden: (() -> Unit)? = null) {
        hideMenuJob?.cancel()
        val menu = quickMenuView
        quickMenuView = null
        if (menu == null || !menu.isAttachedToWindow) {
            onHidden?.invoke()
            refreshIdleTimer()
            return
        }
        menu.animate().cancel()
        menu.animate()
            .alpha(0f)
            .scaleX(0.94f)
            .scaleY(0.94f)
            .setDuration(130L)
            .withEndAction {
                if (menu.isAttachedToWindow) windowManager.removeView(menu)
                onHidden?.invoke()
                refreshIdleTimer()
            }
            .start()
    }

    /** Keeps the system volume panel and our controls on separate edges. */
    private fun updateSystemIndicatorSafePosition(enabled: Boolean) {
        if (!isViewAttached) return
        expandFromPeek()
        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)

        if (enabled) {
            if (!sharedPrefs.getBoolean(KEY_SYSTEM_INDICATOR_SAVED, false)) {
                val wasRight = layoutParams.x + widgetW / 2 >= screenW / 2
                sharedPrefs.edit()
                    .putBoolean(KEY_SYSTEM_INDICATOR_SAVED, true)
                    .putInt(KEY_SYSTEM_INDICATOR_X, layoutParams.x)
                    .putInt(KEY_SYSTEM_INDICATOR_Y, layoutParams.y)
                    .putBoolean(KEY_SYSTEM_INDICATOR_RIGHT, wasRight)
                    .apply()
            }
            val currentlyRight = layoutParams.x + widgetW / 2 >= screenW / 2
            snapToEdge(save = false, preferredRight = !currentlyRight)
            Log.d(TAG, "System indicator enabled; controls moved to opposite edge")
            return
        }

        if (!sharedPrefs.getBoolean(KEY_SYSTEM_INDICATOR_SAVED, false)) return
        layoutParams.x = sharedPrefs.getInt(KEY_SYSTEM_INDICATOR_X, layoutParams.x)
            .coerceIn(0, (screenW - widgetW).coerceAtLeast(0))
        layoutParams.y = sharedPrefs.getInt(KEY_SYSTEM_INDICATOR_Y, layoutParams.y)
            .coerceIn(dp(8), (screenH - widgetH - dp(8)).coerceAtLeast(dp(8)))
        preferredEdgeRight = sharedPrefs.getBoolean(
            KEY_SYSTEM_INDICATOR_RIGHT,
            layoutParams.x + widgetW / 2 >= screenW / 2,
        )
        windowManager.updateViewLayout(floatingMuteView, layoutParams)
        sharedPrefs.edit().remove(KEY_SYSTEM_INDICATOR_SAVED).apply()
        refreshIdleTimer()
        Log.d(TAG, "System indicator disabled; previous controls position restored")
    }

    private fun snapToEdge(save: Boolean = true, preferredRight: Boolean? = null) {
        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)
        val margin  = dp(8)

        val useRightEdge = preferredRight ?: (layoutParams.x + widgetW / 2 >= screenW / 2)
        this.preferredEdgeRight = useRightEdge
        val targetX = if (useRightEdge) screenW - widgetW - margin else margin
        val oldUsableHeight = (lastScreenHeight - widgetH).coerceAtLeast(1)
        val verticalFraction = (layoutParams.y.toFloat() / oldUsableHeight).coerceIn(0f, 1f)
        val targetY = (verticalFraction * (screenH - widgetH - margin * 2).coerceAtLeast(0)).toInt() + margin
        lastScreenHeight = screenH

        ValueAnimator.ofInt(layoutParams.x, targetX).apply {
            duration     = 280L
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                layoutParams.x = it.animatedValue as Int
                windowManager.updateViewLayout(floatingMuteView, layoutParams)
            }
            doOnEnd {
                layoutParams.y = targetY
                if (floatingMuteView.isAttachedToWindow) {
                    windowManager.updateViewLayout(floatingMuteView, layoutParams)
                }
                // The compact volume indicator is its own overlay. After a
                // rotation it must be positioned again relative to the newly
                // snapped buttons, otherwise it can overlap them on the right.
                if (!save && volumeIndicatorView != null) {
                    showVolumeIndicator()
                }
                if (save) newInIO {
                    PositionBloc.event.emit(
                        PositionBloc.Event.UpdatePosition(
                            PositionBloc.Position(targetX, layoutParams.y)
                        )
                    )
                }
            }
            start()
        }
    }

    private fun changeVolume(increase: Boolean) {
        val step   = WidgetSettings.volumeStep.coerceAtLeast(1)
        val stream = stream()
        val max    = audioManager.getStreamMaxVolume(stream.streamType)
        val cur    = audioManager.getStreamVolume(stream.streamType)
        val target = (cur + if (increase) step else -step).coerceIn(0, max)

        if (WidgetSettings.useSystemVolume) {
            if (setStreamVolumeSafely(stream, target, AudioManager.FLAG_SHOW_UI)) {
            // Immediately hide our own indicator if it was shown previously
                hideVolumeIndicator()
            }
        } else {
            if (setStreamVolumeSafely(stream, target, 0)) {
                newInMain { showVolumeIndicator(target) }
            }
        }
    }

    private fun showVolumeIndicator(forcedVolume: Int? = null) {
        val stream = stream()
        val volume    = forcedVolume ?: audioManager.getStreamVolume(stream.streamType)
        val maxVolume = audioManager.getStreamMaxVolume(stream.streamType)

        val screenW  = resources.displayMetrics.widthPixels
        val widgetW  = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH  = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)
        val indW     = dp(WidgetSettings.indicatorWidth)
        val indH     = dp(WidgetSettings.indicatorHeight)
        val gap      = dp(WidgetSettings.indicatorGap)
        val margin   = dp(8)

        // Only the right-side overlay needs the visible coordinate after a
        // rotation. The left-side behavior is established and stays unchanged.
        val buttonLocation = IntArray(2)
        floatingMuteView.getLocationOnScreen(buttonLocation)
        val buttonX = buttonLocation[0]
        val buttonY = buttonLocation[1]
        val isOnRight = buttonX + widgetW / 2 > screenW / 2
        val indX = if (isOnRight) {
            // Reserve a separate lane to the left of +/- in landscape.
            (buttonX - indW - gap)
                .coerceIn(margin, (screenW - indW - margin).coerceAtLeast(margin))
        } else {
            // Preserve the original, correctly working left-side placement.
            layoutParams.x + widgetW + gap
        }
        // Both overlays use TOP|START window coordinates. getLocationOnScreen()
        // includes the status-bar inset on some devices (notably Samsung), so
        // feeding buttonY back into LayoutParams.y shifts the indicator down.
        // Center it from the controls' own window coordinate on either edge.
        val indY = (layoutParams.y + widgetH / 2 - indH / 2)
            .coerceIn(
                margin,
                (resources.displayMetrics.heightPixels - indH - margin).coerceAtLeast(margin),
            )
        Log.d(TAG, "Indicator position: button=($buttonX,$buttonY) right=$isOnRight indicator=($indX,$indY)")

        if (volumeIndicatorView == null) {
            volumeIndicatorView = VolumeIndicatorView(this).also {
                it.applyStyle()
                configureIndicatorTouch(it)
            }
            indicatorParams = LayoutParams(
                indW, indH,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION") LayoutParams.TYPE_PHONE,
                LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).also {
                it.gravity = android.view.Gravity.TOP or android.view.Gravity.START
                it.x = indX
                it.y = indY
            }
            volumeIndicatorView!!.setStream(stream)
            volumeIndicatorView!!.update(volume, maxVolume)
            if (!tryAddOverlay(volumeIndicatorView!!, indicatorParams!!, "volume indicator")) {
                volumeIndicatorView = null
                indicatorParams = null
                return
            }
        } else {
            volumeIndicatorView!!.setStream(stream)
            volumeIndicatorView!!.update(volume, maxVolume)
            indicatorParams!!.width = indW
            indicatorParams!!.height = indH
            indicatorParams!!.x = indX
            indicatorParams!!.y = indY
            windowManager.updateViewLayout(volumeIndicatorView, indicatorParams)
        }

        // indicatorOpacity was previously stored but never applied to the view
        volumeIndicatorView?.alpha = WidgetSettings.indicatorOpacity

        // Auto-hide after configurable delay; reset timer if pressed again
        scheduleIndicatorHide()
        refreshIdleTimer()
    }

    private fun scheduleIndicatorHide() {
        hideIndicatorJob?.cancel()
        hideIndicatorJob = newInMain {
            kotlinx.coroutines.delay(WidgetSettings.indicatorHideDelay.toLong())
            hideVolumeIndicator()
        }
    }

    /**
     * Makes the indicator act as a slider: tap or drag on its track sets the
     * volume directly. The auto-hide timer pauses while the finger is down.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun configureIndicatorTouch(view: VolumeIndicatorView) {
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    hideIndicatorJob?.cancel()
                    val stream   = stream()
                    val max      = audioManager.getStreamMaxVolume(stream.streamType)
                    val fraction = view.fractionForTouch(event.y)
                    val target   = (fraction * max).roundToInt().coerceIn(0, max)
                    if (target != audioManager.getStreamVolume(stream.streamType) &&
                        !setStreamVolumeSafely(stream, target, 0)) {
                        return@setOnTouchListener true
                    }
                    view.update(target, max)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    scheduleIndicatorHide()
                    true
                }
                else -> false
            }
        }
    }

    private fun hideVolumeIndicator() {
        volumeIndicatorView?.let {
            if (it.isAttachedToWindow) windowManager.removeView(it)
        }
        volumeIndicatorView = null
        indicatorParams     = null
        refreshIdleTimer()
    }

    private fun showAudioMixer() {
        hideAudioMixer()
        hideVolumeIndicator()
        val mixer = AudioMixerView(
            this,
            onVolumeChanged = { audioStream, volume ->
                if (setStreamVolumeSafely(audioStream, volume, 0)) refreshMixer()
            },
            onStreamSelected = { audioStream ->
                WidgetSettings.selectedAudioStream = audioStream
                WidgetSettings.save(sharedPrefs)
                scope.inIO { SystemVolumeBloc.event.emit(SystemVolumeBloc.Event.SelectStream(audioStream)) }
                hideAudioMixer()
                showVolumeIndicator()
            },
            onInteractionStarted = { hideMixerJob?.cancel() },
            onInteractionFinished = { scheduleMixerHide() },
        )
        val screenW = resources.displayMetrics.widthPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val isOnRight = layoutParams.x + widgetW / 2 > screenW / 2
        val panelW = dp(270).coerceAtMost(screenW - dp(16))
        val panelH = dp(235).coerceAtMost(resources.displayMetrics.heightPixels - dp(16))
        val params = LayoutParams(
            panelW, panelH,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") LayoutParams.TYPE_PHONE,
            LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).also {
            it.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            it.x = if (isOnRight) (layoutParams.x - panelW - dp(10)).coerceAtLeast(dp(8))
                   else (layoutParams.x + widgetW + dp(10)).coerceAtMost(screenW - panelW - dp(8))
            it.y = layoutParams.y.coerceIn(dp(8), resources.displayMetrics.heightPixels - panelH - dp(8))
        }
        mixerView = mixer
        mixerParams = params
        if (!tryAddOverlay(mixer, params, "audio mixer")) {
            mixerView = null
            mixerParams = null
            return
        }
        refreshMixer()
        scheduleMixerHide()
        Log.d(TAG, "Audio mixer shown")
    }

    private fun refreshMixer() {
        val mixer = mixerView ?: return
        AudioStream.entries.forEach { audioStream ->
            try {
                mixer.update(
                    audioStream,
                    audioManager.getStreamVolume(audioStream.streamType),
                    audioManager.getStreamMaxVolume(audioStream.streamType),
                    audioStream != AudioStream.VOICE_CALL || audioManager.mode == AudioManager.MODE_IN_CALL || audioManager.mode == AudioManager.MODE_IN_COMMUNICATION,
                )
            } catch (e: Exception) {
                Log.w(TAG, "Stream unavailable: $audioStream", e)
                mixer.update(audioStream, 0, 1, false)
            }
        }
    }

    private fun hideAudioMixer() {
        hideMixerJob?.cancel()
        mixerView?.let { if (it.isAttachedToWindow) windowManager.removeView(it) }
        mixerView = null
        mixerParams = null
        refreshIdleTimer()
    }

    /** The mixer is a transient tool, never a second persistent floating widget. */
    private fun scheduleMixerHide() {
        hideMixerJob?.cancel()
        hideMixerJob = newInMain {
            kotlinx.coroutines.delay(WidgetSettings.indicatorHideDelay.toLong())
            hideAudioMixer()
        }
    }

    /** Must be called on the Main thread. */
    private fun updateViewVisibility(shouldShow: Boolean) {
        if (shouldShow && !isViewAttached) {
            isPeeking = false
            floatingMuteView.translationX = 0f
            if (tryAddOverlay(floatingMuteView, layoutParams, "floating controls")) {
                isViewAttached = true
                refreshIdleTimer()
            }
        } else if (!shouldShow && isViewAttached) {
            peekJob?.cancel()
            isPeeking = false
            floatingMuteView.translationX = 0f
            hideAudioMixer()
            hideVolumeIndicator()
            windowManager.removeView(floatingMuteView)
            isViewAttached = false
        }
    }

    // ---------------------------------------------------------------------------
    // Show / lifecycle
    // ---------------------------------------------------------------------------

    private suspend fun showFloatingMuteView() {
        Log.d(TAG, "Showing Floating Mute View")
        val position = PositionBloc.state
            .filterIsInstance<PositionBloc.State.Initialized>()
            .map { it.position }
            .first()

        withContext(Dispatchers.Main) {
            layoutParams.x = position.x
            layoutParams.y = position.y
            updateViewVisibility(true)
            lastScreenHeight = resources.displayMetrics.heightPixels
            val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
            preferredEdgeRight = layoutParams.x + widgetW / 2 >= resources.displayMetrics.widthPixels / 2
            if (WidgetSettings.useSystemVolume) {
                updateSystemIndicatorSafePosition(enabled = true)
            }
        }
    }

    private var isFirstStart = true

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("FloatingViewService", "onStartCommand called")

        fun createPendingIntent(action: NotificationBroadcastReceiver.Action): PendingIntent {
            val i = Intent(this@FloatingVolumeService, NotificationBroadcastReceiver::class.java)
            i.putExtra("action", action.ordinal)
            return PendingIntent.getBroadcast(
                this@FloatingVolumeService,
                100 + action.ordinal,
                i,
                PendingIntent.FLAG_IMMUTABLE,
            )
        }

        scope.inIO {
            // drop(1) skips the initial Off value that ServiceStatusBloc holds at startup.
            // Without it, this collector fires stopSelf() immediately before the state
            // transitions to On, which destroys the service right after it starts.
            ServiceStatusBloc.state
                .drop(1)
                .filterIsInstance<ServiceStatusBloc.State.Off>()
                .first()
            inMain { stopSelf() }
        }

        scope.inIO {
            VisibilityBloc.state.collectLatest {
                val isVisible = it is VisibilityBloc.State.Shown

                val notification = NotificationCompat.Builder(this@FloatingVolumeService, Const.NOTIFICATION_CHANNEL_ID)
                    .setContentTitle("Floating Volume")
                    .setContentText(if (isVisible) "Floating Volume is visible" else "Floating Volume is hidden")
                    .setSmallIcon(R.drawable.logo)
                    .setContentIntent(createPendingIntent(NotificationBroadcastReceiver.Action.LAUNCH_MAIN_ACTIVITY))
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setAutoCancel(false)
                    .setDeleteIntent(createPendingIntent(NotificationBroadcastReceiver.Action.STOP))
                    .addAction(android.R.color.transparent, "Stop",
                        createPendingIntent(NotificationBroadcastReceiver.Action.STOP))
                    .addAction(android.R.color.transparent,
                        if (isVisible) "Hide" else "Show",
                        createPendingIntent(NotificationBroadcastReceiver.Action.TOGGLE_VISIBILITY))
                    .build()

                if (isFirstStart) {
                    isFirstStart = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        startForeground(NOTIFICATION_ID, notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } else {
                    if (ActivityCompat.checkSelfPermission(
                            this@FloatingVolumeService,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) != PackageManager.PERMISSION_GRANTED
                    ) return@collectLatest

                    NotificationManagerCompat.from(this@FloatingVolumeService)
                        .notify(NOTIFICATION_ID, notification)
                }
            }
        }

        // Launch visibility collector BEFORE adding the view.
        // isViewAttached = false here, so initial Hidden is a no-op.
        scope.launch {
            VisibilityBloc.state.collect { state ->
                Log.d(TAG, "VisibilityBloc state changed: $state")
                withContext(Dispatchers.Main) {
                    val shouldShow = state is VisibilityBloc.State.Shown
                    if (shouldShow) {
                        // Apply the saved position BEFORE attaching the view.
                        // Otherwise the window is added at the default (0,0) —
                        // top-left corner — and later jumps when PositionBloc emits.
                        (PositionBloc.state.value as? PositionBloc.State.Initialized)?.let {
                            layoutParams.x = it.position.x
                            layoutParams.y = it.position.y
                        }
                    }
                    updateViewVisibility(shouldShow)
                }
            }
        }

        // Keep the volume indicator in sync with the real system volume
        // This solves the stale volume reading when rapidly pressing + and -
        scope.inIO {
            SystemVolumeBloc.state
                .filterIsInstance<SystemVolumeBloc.State.Initialized>()
                .map { it.volume }
                .distinctUntilChanged()
                .drop(1) // Skip the first emission when the service starts
                .collect { volume ->
                    inMain {
                        // Only update our indicator if it is currently visible (i.e. user just tapped our buttons)
                        // If it's hidden, physical buttons are used and we let the system UI handle it
                        if (hideIndicatorJob?.isActive == true) {
                            showVolumeIndicator(volume)
                        }
                        refreshMixer()
                    }
                }
        }

        Log.d(TAG, "Starting Floating Mute View")
        scope.inIO {
            showFloatingMuteView()
            withContext(Dispatchers.Main) { configureTouchListener() }
        }

        refreshIdleTimer()

        scope.inIO {
            PositionBloc.state
                .filterIsInstance<PositionBloc.State.Initialized>()
                .map { it.position }
                .collectLatest { position ->
                    inMain {
                        layoutParams.x = position.x
                        layoutParams.y = position.y
                        if (floatingMuteView.isAttachedToWindow) {
                            windowManager.updateViewLayout(floatingMuteView, layoutParams)
                        }
                    }
                }
        }

        // START_STICKY: if the OS kills this service (e.g. MIUI/ColorOS memory pressure),
        // it will be automatically restarted with a null intent. This is the key flag
        // needed for background survival on aggressive OEM memory managers.
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        hideIndicatorJob?.cancel()
        hideMixerJob?.cancel()
        peekJob?.cancel()
        styleExpiryJob?.cancel()
        WidgetSettings.removeListener(::onSettingsChanged)
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        hideVolumeIndicator()
        hideQuickMenu()
        hideAudioMixer()
        updateViewVisibility(false)
    }
}
