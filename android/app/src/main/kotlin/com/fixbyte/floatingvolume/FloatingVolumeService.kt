package com.fixbyte.floatingvolume

import android.Manifest
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.Point
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.WindowInsets
import android.view.WindowManager.LayoutParams
import android.view.animation.DecelerateInterpolator
import androidx.core.animation.doOnEnd
import androidx.core.animation.doOnCancel
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.doOnLayout
import com.fixbyte.floatingvolume.bloc.PositionBloc
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc
import com.fixbyte.floatingvolume.bloc.SystemVolumeBloc
import com.fixbyte.floatingvolume.bloc.VisibilityBloc
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CompletableDeferred
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
    private data class ResizeSnapshot(
        val oldWidth: Int,
        val oldHeight: Int,
        val restorePeek: Boolean,
    )

    companion object {
        const val NOTIFICATION_ID = 1
        const val TAG = "FloatingService"
        @Volatile private var activeInstance: FloatingVolumeService? = null
        @Volatile private var pendingStart: CompletableDeferred<Unit>? = null
        fun prepareStart(): CompletableDeferred<Unit> = CompletableDeferred<Unit>().also {
            pendingStart = it
        }
        fun notifyLanguageChanged() { activeInstance?.refreshLanguage() }
        private const val KEY_SYSTEM_INDICATOR_SAVED = "system_indicator_position_saved"
        private const val KEY_SYSTEM_INDICATOR_X = "system_indicator_previous_x"
        private const val KEY_SYSTEM_INDICATOR_Y = "system_indicator_previous_y"
        private const val KEY_SYSTEM_INDICATOR_RIGHT = "system_indicator_previous_right"
    }

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        // Fulfil the OS contract synchronously, before preferences, Firebase,
        // entitlement checks, overlays or coroutine scheduling can delay us.
        ForegroundNotificationChannel.ensure(this)
        val startupAt = SystemClock.elapsedRealtime()
        promoteToForeground(NotificationCompat.Builder(this, Const.NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Floating Volume")
            .setContentText("Floating Volume")
            .setSmallIcon(R.drawable.logo)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build())
        Log.d(TAG, "foreground_promoted create_ms=${SystemClock.elapsedRealtime() - startupAt}")
        TechnicalMonitoring.state("foreground_ms", (SystemClock.elapsedRealtime() - startupAt).toString())
        TechnicalMonitoring.duration("native_foreground_promotion", SystemClock.elapsedRealtime() - startupAt)
        activeInstance = this
        Log.d(TAG, "service_created instance=${System.identityHashCode(this)}")
        // Load persisted settings and register for live updates
        WidgetSettings.load(sharedPrefs, flutterPreferences)
        TechnicalMonitoring.event("service_created")
        TechnicalMonitoring.state("service_active", "true")
        TechnicalMonitoring.state("widget_style", WidgetSettings.style.name)
        lastUseSystemVolume = WidgetSettings.useSystemVolume
        lastAppliedButtonSize = WidgetSettings.buttonSize
        lastAppliedButtonGap = WidgetSettings.buttonGap
        lastAppliedPeekSize = WidgetSettings.peekSize
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
        TechnicalMonitoring.state("widget_style", WidgetSettings.style.name)
        TechnicalMonitoring.state("native_indicator", WidgetSettings.useSystemVolume.toString())
        TechnicalMonitoring.state("auto_hide", WidgetSettings.autoPeekEnabled.toString())
        val systemIndicatorChanged = lastUseSystemVolume != WidgetSettings.useSystemVolume
        val oldButtonSize = lastAppliedButtonSize
        val oldButtonGap = lastAppliedButtonGap
        val buttonGeometryChanged =
            oldButtonSize != WidgetSettings.buttonSize || oldButtonGap != WidgetSettings.buttonGap
        val peekSizeChanged = lastAppliedPeekSize != WidgetSettings.peekSize
        lastUseSystemVolume = WidgetSettings.useSystemVolume
        lastAppliedButtonSize = WidgetSettings.buttonSize
        lastAppliedButtonGap = WidgetSettings.buttonGap
        lastAppliedPeekSize = WidgetSettings.peekSize
        newInMain {
            val wasPeeking = isPeeking
            val oldWidth = floatingMuteView.width.takeIf { it > 0 } ?: dp(oldButtonSize)
            val oldHeight =
                floatingMuteView.height.takeIf { it > 0 }
                    ?: dp(oldButtonSize * 2 + oldButtonGap)

            if (buttonGeometryChanged) {
                peekJob?.cancel()
                if (pendingResizeSnapshot == null && isViewAttached) {
                    pendingResizeSnapshot = ResizeSnapshot(oldWidth, oldHeight, wasPeeking)
                }
            }

            if (wasPeeking && buttonGeometryChanged) {
                peekJob?.cancel()
                peekAnimator?.cancel()
                isPeeking = false
                floatingMuteView.translationX = 0f
                floatingMuteView.alpha = WidgetSettings.opacity
            } else if (wasPeeking && !WidgetSettings.autoPeekEnabled) {
                expandFromPeek()
            } else if (wasPeeking && peekSizeChanged) {
                peekJob?.cancel()
                peekAnimator?.cancel()
                isPeeking = false
                floatingMuteView.translationX = 0f
                floatingMuteView.alpha = WidgetSettings.opacity
            }

            floatingMuteView.applyTheme()

            if (buttonGeometryChanged && isViewAttached) scheduleResizePreservation()

            if (!buttonGeometryChanged && wasPeeking && peekSizeChanged && WidgetSettings.autoPeekEnabled) {
                floatingMuteView.post { peekToEdge() }
            }

            if (!WidgetSettings.autoPeekEnabled) peekJob?.cancel()
            if (systemIndicatorChanged && isViewAttached) {
                updateSystemIndicatorSafePosition(WidgetSettings.useSystemVolume)
            }
            if (volumeIndicatorView != null) {
                volumeIndicatorView?.applyStyle()
                showVolumeIndicator()
            }
            if (!buttonGeometryChanged && !(wasPeeking && peekSizeChanged)) {
                refreshIdleTimer()
            }
        }
    }

    /** Coalesce rapid slider updates so one resize gesture yields one re-anchor. */
    private fun scheduleResizePreservation() {
        resizeSettleJob?.cancel()
        resizeSettleJob = newInMain {
            kotlinx.coroutines.delay(150L)
            val snapshot = pendingResizeSnapshot ?: return@newInMain
            pendingResizeSnapshot = null
            if (!isViewAttached || !floatingMuteView.isAttachedToWindow) return@newInMain
            preserveControlPositionAfterResize(
                oldWidth = snapshot.oldWidth,
                oldHeight = snapshot.oldHeight,
                restorePeek = snapshot.restorePeek,
            )
        }
    }

    /** Keep the selected edge and relative vertical position after a resize. */
    private fun preserveControlPositionAfterResize(
        oldWidth: Int,
        oldHeight: Int,
        restorePeek: Boolean,
    ) {
        if (!isViewAttached || !floatingMuteView.isAttachedToWindow) return

        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        val margin = dp(8)
        val newWidth = floatingMuteView.width.coerceAtLeast(1)
        val newHeight = floatingMuteView.height.coerceAtLeast(1)
        val useRightEdge =
            preferredEdgeRight ?: (layoutParams.x + oldWidth / 2 >= screenW / 2)

        val targetX = if (useRightEdge) (screenW - newWidth).coerceAtLeast(0) else 0
        val oldAvailableHeight = (screenH - oldHeight - margin * 2).coerceAtLeast(1)
        val verticalFraction =
            ((layoutParams.y - margin).toFloat() / oldAvailableHeight).coerceIn(0f, 1f)
        val newAvailableHeight = (screenH - newHeight - margin * 2).coerceAtLeast(0)
        val targetY = margin + (verticalFraction * newAvailableHeight).roundToInt()

        layoutParams.x = targetX
        layoutParams.y = targetY
        preferredEdgeRight = useRightEdge
        lastScreenHeight = screenH
        runCatching { windowManager.updateViewLayout(floatingMuteView, layoutParams) }
            .onFailure { Log.w(TAG, "Could not reposition resized floating controls", it) }
        newInIO {
            PositionBloc.event.emit(
                PositionBloc.Event.UpdatePosition(PositionBloc.Position(targetX, targetY)),
            )
        }

        if (volumeIndicatorView != null) showVolumeIndicator()
        hideQuickMenu(immediate = true)
        if (restorePeek && WidgetSettings.autoPeekEnabled && !isFloatingTouchActive) {
            peekToEdge()
        } else {
            refreshIdleTimer()
        }
        Log.d(TAG, "Resized controls re-anchored: ${newWidth}x$newHeight at $targetX,$targetY")
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        TechnicalMonitoring.event("orientation_changed")
        TechnicalMonitoring.state("orientation", newConfig.orientation.toString())
        rotationSettleJob?.cancel()
        cancelSnapAnimation()
        val restoreIndicator = volumeIndicatorView != null
        hideVolumeIndicator()
        hideQuickMenu(immediate = true)
        floatingMuteView.dispatchConfigurationChanged(newConfig)
        // A portrait X coordinate is not meaningful on the wider landscape
        // display. Reattach the control to its remembered lateral edge.
        rotationSettleJob = newInMain {
            kotlinx.coroutines.delay(180L)
            if (isViewAttached) snapToEdge(save = false, preferredRight = preferredEdgeRight) {
                if (restoreIndicator && !WidgetSettings.useSystemVolume) showVolumeIndicator()
            }
        }
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
    private var snapAnimator: ValueAnimator? = null
    private var rotationSettleJob: Job? = null
    private var indicatorRepositionJob: Job? = null
    private var volumeVerificationJob: Job? = null
    private var resizeSettleJob: Job? = null
    private var pendingResizeSnapshot: ResizeSnapshot? = null
    private var isPeeking = false
    private var isFloatingTouchActive = false
    private var preferredEdgeRight: Boolean? = null
    private var lastScreenHeight = 0
    private var lastDndWarningAt = 0L
    private var styleExpiryJob: Job? = null
    private var lastUseSystemVolume = false
    private var lastAppliedButtonSize = 44
    private var lastAppliedButtonGap = 10
    private var lastAppliedPeekSize = 20

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
        val featuredStyle = flutterPreferences.getString(
            "flutter.special_featured_style",
            null,
        )
        val featuredExpiry = flutterPreferences.getLong(
            "flutter.special_featured_expiry",
            0L,
        )
        if (featuredStyle == unlockName && featuredExpiry > now) return true

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
        WidgetSettings.update(mapOf("style" to "android"), sharedPrefs)
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
            it.setTitle("FloatingVolume controls")
        }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).roundToInt()
    private fun stream() = WidgetSettings.selectedAudioStream

    /** Full display coordinates, with system bars/cutouts excluded on every edge. */
    private fun indicatorAvailableBounds(): OverlayRect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            return OverlayRect(bounds.left + insets.left, bounds.top + insets.top,
                bounds.right - insets.right, bounds.bottom - insets.bottom)
        }
        val size = Point()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealSize(size)
        val insets = floatingMuteView.rootWindowInsets
        @Suppress("DEPRECATION")
        var left = insets?.stableInsetLeft ?: 0
        @Suppress("DEPRECATION")
        var top = insets?.stableInsetTop ?: 0
        @Suppress("DEPRECATION")
        var right = insets?.stableInsetRight ?: 0
        @Suppress("DEPRECATION")
        var bottom = insets?.stableInsetBottom ?: 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            insets?.displayCutout?.let {
                left = maxOf(left, it.safeInsetLeft)
                top = maxOf(top, it.safeInsetTop)
                right = maxOf(right, it.safeInsetRight)
                bottom = maxOf(bottom, it.safeInsetBottom)
            }
        }
        return OverlayRect(left, top, size.x - right, size.y - bottom)
    }

    /**
     * Overlay permission/token validity can change while a delayed gesture is
     * pending, particularly on older Huawei firmware. Never let that race crash
     * the foreground service.
     */
    private fun tryAddOverlay(view: View, params: LayoutParams, label: String): Boolean {
        TechnicalMonitoring.state("window_kind", when (label) {
            "floating controls" -> "controls"
            "volume indicator" -> "indicator"
            "quick menu" -> "menu"
            "audio mixer" -> "mixer"
            else -> "unknown"
        })
        TechnicalMonitoring.state("window_attached", view.isAttachedToWindow.toString())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot add $label: overlay permission is unavailable")
            return false
        }
        // The WindowManager is the source of truth. A service restart or a
        // visibility transition can leave our bookkeeping flag behind the
        // actual window state; never submit an already attached View again.
        if (view.isAttachedToWindow) {
            Log.w(TAG, "Skipped duplicate add for $label; view is already attached")
            return true
        }
        val operation = TechnicalMonitoring.begin(DiagnosticOperation.OVERLAY_ADD)
        val added = try {
            windowManager.addView(view, params)
            true
        } catch (error: WindowManager.BadTokenException) {
            TechnicalMonitoring.error("overlay_bad_token", error)
            Log.w(TAG, "Cannot add $label: invalid overlay token", error)
            false
        } catch (error: SecurityException) {
            TechnicalMonitoring.error("overlay_security", error)
            Log.w(TAG, "Cannot add $label: overlay permission was revoked", error)
            false
        } catch (error: IllegalStateException) {
            TechnicalMonitoring.error("overlay_state", error)
            Log.w(TAG, "Cannot add $label: window state changed", error)
            false
        }
        TechnicalMonitoring.finish(DiagnosticOperation.OVERLAY_ADD, operation, added)
        TechnicalMonitoring.state("window_attached", view.isAttachedToWindow.toString())
        return added
    }

    /**
     * Some OEMs (including MIUI) reject ring/notification changes while Do Not
     * Disturb is enabled unless the app has notification-policy access. Audio
     * control must never take down the floating service in that situation.
     */
    private fun setStreamVolumeSafely(stream: AudioStream, target: Int, flags: Int): Boolean = try {
        val before = audioManager.getStreamVolume(stream.streamType)
        TechnicalMonitoring.measure("native_volume_request") {
            audioManager.setStreamVolume(stream.streamType, target, flags)
        }
        val actual = audioManager.getStreamVolume(stream.streamType)
        TechnicalMonitoring.volume(stream.name, before, target, actual)
        Log.d(TAG, "Volume request: stream=$stream before=$before target=$target actual=$actual fixed=${audioManager.isVolumeFixed}")
        volumeVerificationJob?.cancel()
        volumeVerificationJob = newInMain {
            kotlinx.coroutines.delay(150L)
            val confirmed = audioManager.getStreamVolume(stream.streamType)
            TechnicalMonitoring.state("volume_confirmed", confirmed.toString())
            Log.d(TAG, "Volume confirmed: stream=$stream target=$target actual=$confirmed")
            if (confirmed != target) Log.w(TAG, "Android limited or ignored volume request for $stream")
            if (stream == stream() && isViewAttached) {
                volumeIndicatorView?.update(confirmed, audioManager.getStreamMaxVolume(stream.streamType))
                refreshMixer()
            }
        }
        true
    } catch (error: SecurityException) {
        TechnicalMonitoring.error("volume_security", error)
        Log.w(TAG, "Volume change blocked for $stream; Do Not Disturb policy access is required", error)
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastDndWarningAt >= 3_000L) {
            lastDndWarningAt = now
            android.widget.Toast.makeText(
                this,
                NativeLanguage.text(this, "This channel cannot be changed while Do Not Disturb is on.", "No se puede cambiar este canal mientras No molestar está activo."),
                android.widget.Toast.LENGTH_SHORT,
            ).show()
        }
        false
    }

    private fun refreshIdleTimer() {
        peekJob?.cancel()
        if (!WidgetSettings.autoPeekEnabled || !isViewAttached || isPeeking || isFloatingTouchActive) return
        peekJob = newInMain {
            kotlinx.coroutines.delay(WidgetSettings.autoPeekDelay.toLong())
            if (
                !isFloatingTouchActive &&
                volumeIndicatorView == null &&
                mixerView == null &&
                quickMenuViews.isEmpty()
            ) peekToEdge()
        }
    }

    private fun peekToEdge() {
        TechnicalMonitoring.transition(DiagnosticOperation.PEEK, DiagnosticPhase.START)
        if (isPeeking || !isViewAttached || isFloatingTouchActive) return
        val screenW = resources.displayMetrics.widthPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val isOnRight = preferredEdgeRight ?: (layoutParams.x + widgetW / 2 >= screenW / 2)
        layoutParams.x = if (isOnRight) (screenW - widgetW).coerceAtLeast(0) else 0
        if (floatingMuteView.isAttachedToWindow) {
            runCatching { windowManager.updateViewLayout(floatingMuteView, layoutParams) }
        }
        preferredEdgeRight = isOnRight
        // The recovery tab is a dp-sized touch target, not a handful of physical
        // pixels. Keep at least 16dp exposed so it remains visible and reachable.
        val visible = dp(WidgetSettings.peekSize.coerceIn(16, 28))
            .coerceAtMost((widgetW - dp(8)).coerceAtLeast(1))
        // WindowManager clamps overlay coordinates inside the display. Move the
        // *content* instead of the window so only the recovery tab remains visible.
        val offset = if (!isOnRight)
            -(widgetW - visible).toFloat()
        else
            (widgetW - visible).toFloat()
        isPeeking = true
        floatingMuteView.pauseStyleAnimation()
        // The revealed portion remains visible even when the user set a very
        // low opacity; otherwise the hidden controls can look completely lost.
        floatingMuteView.alpha = (WidgetSettings.opacity * 0.82f).coerceAtLeast(0.70f)
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
        var gestureMoved  = false
        var longPressJob: Job? = null
        var longPressFired = false
        var consumePeekGesture = false
        val dragThreshold = dp(8).toFloat()

        floatingMuteView.handleIv.setOnTouchListener { _, event ->
            when (event.action) {

                MotionEvent.ACTION_DOWN -> {
                    isFloatingTouchActive = true
                    indicatorRepositionJob?.cancel()
                    cancelSnapAnimation()
                    peekJob?.cancel()
                    longPressJob?.cancel()
                    longPressFired = false
                    isDragging = false
                    gestureMoved = false
                    consumePeekGesture = false
                    hideQuickMenu(immediate = true)
                    if (isPeeking) {
                        Log.d(TAG, "Recovery tab touched; reveal without changing volume")
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
                    longPressJob = newInMain {
                        kotlinx.coroutines.delay(550)
                        if (!gestureMoved && isFloatingTouchActive &&
                            isViewAttached && floatingMuteView.isAttachedToWindow) {
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

                    if (!gestureMoved &&
                            (abs(dx) > dragThreshold || abs(dy) > dragThreshold)) {
                        gestureMoved = true
                        TechnicalMonitoring.event("drag_started")
                        // Do not let a pending unfold animation fight the drag.
                        peekAnimator?.cancel()
                        floatingMuteView.translationX = 0f
                        floatingMuteView.alpha = WidgetSettings.opacity
                        consumePeekGesture = false
                        longPressJob?.cancel()
                        hideVolumeIndicator()
                        hideQuickMenu(immediate = true)
                        longPressFired = false
                        isDragging = !WidgetSettings.isPinned
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
                        isFloatingTouchActive = false
                        refreshIdleTimer()
                        return@setOnTouchListener true
                    }
                    longPressJob?.cancel()
                    if (isDragging) {
                        snapToEdge()
                    } else if (gestureMoved) {
                        // A move that dismissed the menu is never a volume tap.
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
                        Log.d(TAG, "Expanded volume control tapped: ${if (up) "UP" else "DOWN"}")
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
                    isFloatingTouchActive = false
                    refreshIdleTimer()
                    true
                }

                MotionEvent.ACTION_CANCEL -> {
                    consumePeekGesture = false
                    longPressJob?.cancel()
                    hideQuickMenu(immediate = true)
                    isFloatingTouchActive = false
                    refreshIdleTimer()
                    false
                }

                else -> false
            }
        }
    }

    // ── Quick menu (long-press) ───────────────────────────────────────────────

    private var quickMenuView: android.widget.LinearLayout? = null
    private val quickMenuViews = mutableSetOf<android.widget.LinearLayout>()
    private val menuClosers = mutableMapOf<android.widget.LinearLayout, Runnable>()
    private val menuHandler = Handler(Looper.getMainLooper())
    private var hideMenuJob: Job? = null

    /** Compact action bubbles shown beside the controls on long-press. */
    private fun showQuickMenu(): Boolean {
        TechnicalMonitoring.state("quick_menu_count", quickMenuViews.size.toString())
        TechnicalMonitoring.transition(DiagnosticOperation.QUICK_MENU, DiagnosticPhase.START)
        TechnicalMonitoring.event("quick_menu_requested")
        // A previous fade-out may still own an overlay window. Remove it before
        // adding another menu so two gesture races cannot leave duplicate bubbles.
        hideQuickMenu(immediate = true)
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

        menu.addView(item(R.drawable.ic_power_settings_new_24, NativeLanguage.text(this, "Turn off controls", "Desactivar botones")) {
            scope.inIO { ServiceStatusBloc.event.emit(ServiceStatusBloc.Event.Stop) }
        })
        if (WidgetSettings.showAudioMixer) {
        menu.addView(item(R.drawable.ic_equalizer_24, NativeLanguage.text(this, "Volume mixer", "Mezclador de volumen"), 8) {
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
        quickMenuViews.add(menu)
        TechnicalMonitoring.state("quick_menu_count", quickMenuViews.size.toString())
        TechnicalMonitoring.transition(DiagnosticOperation.QUICK_MENU, DiagnosticPhase.SUCCESS)
        Log.d(TAG, "Quick menu attached; active windows=${quickMenuViews.size}")
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

    private fun removeQuickMenu(menu: android.widget.LinearLayout) {
        menuClosers.remove(menu)?.let(menuHandler::removeCallbacks)
        menu.animate().cancel()
        // addView registers the window before the first traversal attaches the View.
        // A drag on that frame must still remove it from WindowManager; checking
        // isAttachedToWindow here leaves an invisible, orphaned overlay behind.
        val wasAttached = menu.isAttachedToWindow
        val operation = TechnicalMonitoring.begin(DiagnosticOperation.OVERLAY_REMOVE)
        TechnicalMonitoring.state("window_removing", "true")
        val removed = runCatching { windowManager.removeViewImmediate(menu) }
            .onFailure {
                TechnicalMonitoring.error("overlay_remove_failed", it)
                Log.w(TAG, "Could not remove quick menu", it)
            }
            .isSuccess
        TechnicalMonitoring.finish(DiagnosticOperation.OVERLAY_REMOVE, operation, removed)
        TechnicalMonitoring.state("window_removing", "false")
        if (removed || menu.parent == null) {
            quickMenuViews.remove(menu)
            if (quickMenuView === menu) quickMenuView = null
        }
        TechnicalMonitoring.state("quick_menu_count", quickMenuViews.size.toString())
        Log.d(TAG, "Quick menu removal: attached=$wasAttached removed=$removed active windows=${quickMenuViews.size}")
    }

    private fun hideQuickMenu(onHidden: (() -> Unit)? = null, immediate: Boolean = false) {
        TechnicalMonitoring.state("quick_menu_count", quickMenuViews.size.toString())
        TechnicalMonitoring.event("quick_menu_hidden")
        hideMenuJob?.cancel()
        if (immediate) {
            quickMenuViews.toList().forEach(::removeQuickMenu)
            onHidden?.invoke()
            refreshIdleTimer()
            return
        }
        val menu = quickMenuView
        quickMenuView = null
        if (menu == null || !menu.isAttachedToWindow) {
            if (menu != null) removeQuickMenu(menu)
            onHidden?.invoke()
            refreshIdleTimer()
            return
        }
        menu.animate().cancel()
        val finish = object : Runnable {
            override fun run() {
                // A drag or service stop may have removed this window already.
                if (menuClosers[menu] !== this) return
                removeQuickMenu(menu)
                onHidden?.invoke()
                refreshIdleTimer()
            }
        }
        menuClosers[menu] = finish
        menu.animate()
            .alpha(0f)
            .scaleX(0.94f)
            .scaleY(0.94f)
            .setDuration(130L)
            .withEndAction { finish.run() }
            .start()
        // ViewPropertyAnimator's end action is skipped if a gesture cancels it.
        // This fallback makes removal deterministic even on that path.
        menuHandler.postDelayed(finish, 200L)
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
        val savedRight = sharedPrefs.getBoolean(
            KEY_SYSTEM_INDICATOR_RIGHT,
            layoutParams.x + widgetW / 2 >= screenW / 2,
        )
        layoutParams.x = if (savedRight) (screenW - widgetW).coerceAtLeast(0) else 0
        layoutParams.y = sharedPrefs.getInt(KEY_SYSTEM_INDICATOR_Y, layoutParams.y)
            .coerceIn(dp(8), (screenH - widgetH - dp(8)).coerceAtLeast(dp(8)))
        preferredEdgeRight = savedRight
        windowManager.updateViewLayout(floatingMuteView, layoutParams)
        sharedPrefs.edit().remove(KEY_SYSTEM_INDICATOR_SAVED).apply()
        refreshIdleTimer()
        Log.d(TAG, "System indicator disabled; previous controls position restored")
    }

    private fun snapToEdge(save: Boolean = true, preferredRight: Boolean? = null, onFinished: (() -> Unit)? = null) {
        cancelSnapAnimation()
        if (!isViewAttached || !floatingMuteView.isAttachedToWindow) return
        TechnicalMonitoring.transition(DiagnosticOperation.SNAP, DiagnosticPhase.START)
        val screenW = resources.displayMetrics.widthPixels
        val screenH = resources.displayMetrics.heightPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)
        val margin  = dp(8)

        val useRightEdge = preferredRight ?: (layoutParams.x + widgetW / 2 >= screenW / 2)
        this.preferredEdgeRight = useRightEdge
        val targetX = if (useRightEdge) (screenW - widgetW).coerceAtLeast(0) else 0
        val targetY = OverlayPosition.rotatedY(
            layoutParams.y, lastScreenHeight, screenH, widgetH, margin)
        lastScreenHeight = screenH

        val animator = ValueAnimator.ofInt(layoutParams.x, targetX)
        animator.duration = 280L
        animator.interpolator = DecelerateInterpolator()
        var cancelled = false
        animator.doOnCancel { cancelled = true }
        animator.addUpdateListener {
            if (snapAnimator !== animator || !isViewAttached || !floatingMuteView.isAttachedToWindow) {
                cancelSnapAnimation()
                return@addUpdateListener
            }
            layoutParams.x = it.animatedValue as Int
            try {
                windowManager.updateViewLayout(floatingMuteView, layoutParams)
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "Floating controls detached during edge snap", e)
                TechnicalMonitoring.error("snap_detached", e)
                cancelSnapAnimation()
            }
        }
        animator.doOnEnd {
            if (cancelled || snapAnimator !== animator) return@doOnEnd
            snapAnimator = null
            if (!isViewAttached || !floatingMuteView.isAttachedToWindow) return@doOnEnd
            layoutParams.y = targetY
            try {
                windowManager.updateViewLayout(floatingMuteView, layoutParams)
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "Floating controls detached at end of edge snap", e)
                TechnicalMonitoring.error("snap_end_detached", e)
                return@doOnEnd
            }
            TechnicalMonitoring.transition(DiagnosticOperation.SNAP, DiagnosticPhase.SUCCESS)
            // The indicator is a separate overlay and must follow the snapped buttons.
            // Updating window coordinates returns before Android applies its frame.
            // Measure after traversal, otherwise rotation centers on the old Y.
            if ((!save && volumeIndicatorView != null) || onFinished != null) {
                indicatorRepositionJob?.cancel()
                indicatorRepositionJob = newInMain {
                    kotlinx.coroutines.delay(64L)
                    if (!isViewAttached || snapAnimator != null) return@newInMain
                    if (!save && volumeIndicatorView != null) showVolumeIndicator()
                    onFinished?.invoke()
                }
            }
            if (save) newInIO {
                PositionBloc.event.emit(
                    PositionBloc.Event.UpdatePosition(PositionBloc.Position(targetX, targetY))
                )
            }
        }
        snapAnimator = animator
        animator.start()
    }

    private fun cancelSnapAnimation() {
        val animator = snapAnimator ?: return
        TechnicalMonitoring.transition(DiagnosticOperation.SNAP, DiagnosticPhase.CANCELLED)
        snapAnimator = null
        animator.cancel()
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
                newInMain { showVolumeIndicator() }
            }
        }
    }

    private fun showVolumeIndicator() {
        val controlsActuallyAttached = floatingMuteView.isAttachedToWindow
        if (!controlsActuallyAttached) {
            Log.w(TAG, "Skip indicator: controls window is not attached; tracked_controls=$isViewAttached instance=${System.identityHashCode(this)}")
            return
        }
        // Input callbacks can arrive in the same frame as a stop/show
        // transition. The attached window is authoritative for this action.
        isViewAttached = true
        val stream = stream()
        val volume    = audioManager.getStreamVolume(stream.streamType)
        val maxVolume = audioManager.getStreamMaxVolume(stream.streamType)

        val widgetW  = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH  = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)
        val buttonLocation = IntArray(2)
        floatingMuteView.getLocationOnScreen(buttonLocation)
        // The reveal animation translates the content, not its overlay window.
        // Anchor to the settled window so an early tap cannot shrink the final gap.
        val buttonX = buttonLocation[0] - floatingMuteView.translationX.roundToInt()
        val buttonY = buttonLocation[1]
        val controls = OverlayRect(buttonX, buttonY, buttonX + widgetW, buttonY + widgetH)
        val available = indicatorAvailableBounds()
        val placement = IndicatorPlacement.calculate(available, controls,
            dp(WidgetSettings.indicatorWidth), dp(WidgetSettings.indicatorHeight),
            dp(WidgetSettings.indicatorGap), dp(8), dp(24))
        if (placement == null) {
            Log.w(TAG, "Indicator has no safe slot: controls=$controls available=$available")
            hideVolumeIndicator()
            return
        }
        val indW = placement.width
        val indH = placement.height
        val indX = placement.left
        val indY = placement.top
        Log.d(TAG, "Indicator placement: controls=$controls available=$available indicator=$placement gap=${WidgetSettings.indicatorGap}")

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
                LayoutParams.FLAG_NOT_FOCUSABLE or LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).also {
                it.gravity = android.view.Gravity.TOP or android.view.Gravity.LEFT
                it.setTitle("FloatingVolume indicator")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    it.setFitInsetsTypes(0)
                    it.layoutInDisplayCutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    it.layoutInDisplayCutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
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
            if (runCatching { windowManager.updateViewLayout(volumeIndicatorView, indicatorParams) }.isFailure) {
                hideVolumeIndicator()
                return
            }
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
                    view.update(audioManager.getStreamVolume(stream.streamType), max)
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
        hideIndicatorJob?.cancel()
        indicatorRepositionJob?.cancel()
        volumeIndicatorView?.let {
            val operation = TechnicalMonitoring.begin(DiagnosticOperation.OVERLAY_REMOVE)
            runCatching { windowManager.removeViewImmediate(it) }
                .onFailure { error ->
                    TechnicalMonitoring.error("overlay_remove_failed", error)
                    Log.w(TAG, "Could not remove volume indicator", error)
                }.also { result -> TechnicalMonitoring.finish(DiagnosticOperation.OVERLAY_REMOVE, operation, result.isSuccess) }
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
                WidgetSettings.update(mapOf("selectedAudioStream" to audioStream.name), sharedPrefs)
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
        if (!shouldShow) {
            cancelSnapAnimation()
            hideQuickMenu(immediate = true)
        }
        // Reconcile the cached state with WindowManager before deciding whether
        // an add/remove is needed. This prevents duplicate overlay tokens when
        // a stop/restart races a visibility event on legacy Android versions.
        val actuallyAttached = floatingMuteView.isAttachedToWindow
        isViewAttached = actuallyAttached
        Log.d(TAG, "sync_controls visible=$shouldShow tracked=$isViewAttached instance=${System.identityHashCode(this)}")

        if (shouldShow && !actuallyAttached) {
            isPeeking = false
            floatingMuteView.translationX = 0f
            if (tryAddOverlay(floatingMuteView, layoutParams, "floating controls")) {
                isViewAttached = floatingMuteView.isAttachedToWindow
                Log.d(TAG, "controls_added actual=$isViewAttached instance=${System.identityHashCode(this)}")
                refreshIdleTimer()
            }
        } else if (!shouldShow && actuallyAttached) {
            peekJob?.cancel()
            isPeeking = false
            isFloatingTouchActive = false
            floatingMuteView.translationX = 0f
            hideAudioMixer()
            hideVolumeIndicator()
            isViewAttached = false
            try {
                // Synchronous detach prevents a rapid stop/start from creating
                // a second TYPE_APPLICATION_OVERLAY while the old ViewRoot is
                // still being removed (notably on Android 8.x).
                windowManager.removeViewImmediate(floatingMuteView)
            } catch (e: IllegalArgumentException) {
                TechnicalMonitoring.error("overlay_remove_failed", e)
                Log.w(TAG, "Floating controls already detached while hiding", e)
            } catch (e: IllegalStateException) {
                TechnicalMonitoring.error("overlay_remove_failed", e)
                Log.w(TAG, "Floating controls changed state while hiding", e)
            }
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
            floatingMuteView.doOnLayout {
                if (!isViewAttached) return@doOnLayout
                val screenW = resources.displayMetrics.widthPixels
                val widgetW = floatingMuteView.width.coerceAtLeast(1)
                val savedRight = layoutParams.x + widgetW / 2 >= screenW / 2
                preferredEdgeRight = savedRight
                if (WidgetSettings.useSystemVolume) {
                    updateSystemIndicatorSafePosition(enabled = true)
                } else {
                    layoutParams.x = if (savedRight) (screenW - widgetW).coerceAtLeast(0) else 0
                    windowManager.updateViewLayout(floatingMuteView, layoutParams)
                    val anchoredX = layoutParams.x
                    val anchoredY = layoutParams.y
                    newInIO {
                        PositionBloc.event.emit(
                            PositionBloc.Event.UpdatePosition(
                                PositionBloc.Position(anchoredX, anchoredY),
                            ),
                        )
                    }
                }
            }
        }
    }

    private var isFirstStart = true
    private var observersStarted = false

    private fun promoteToForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isFirstStart = false
    }

    private fun createPendingIntent(action: NotificationBroadcastReceiver.Action): PendingIntent {
        val intent = Intent(this, NotificationBroadcastReceiver::class.java)
            .putExtra("action", action.ordinal)
        return PendingIntent.getBroadcast(
            this, 100 + action.ordinal, intent, PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildNotification(isVisible: Boolean) =
        NotificationCompat.Builder(this, Const.NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Floating Volume")
            .setContentText(if (isVisible)
                NativeLanguage.text(this, "Floating Volume is visible", "Floating Volume está visible")
                else NativeLanguage.text(this, "Floating Volume is hidden", "Floating Volume está oculto"))
            .setSmallIcon(R.drawable.logo)
            .setContentIntent(createPendingIntent(NotificationBroadcastReceiver.Action.LAUNCH_MAIN_ACTIVITY))
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(false)
            .setDeleteIntent(createPendingIntent(NotificationBroadcastReceiver.Action.STOP))
            .addAction(android.R.color.transparent,
                NativeLanguage.text(this, "Stop", "Detener"),
                createPendingIntent(NotificationBroadcastReceiver.Action.STOP))
            .addAction(android.R.color.transparent,
                if (isVisible) NativeLanguage.text(this, "Hide", "Ocultar")
                else NativeLanguage.text(this, "Show", "Mostrar"),
                createPendingIntent(NotificationBroadcastReceiver.Action.TOGGLE_VISIBILITY))
            .build()

    private fun refreshLanguage() {
        if (isFirstStart) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) return
        val isVisible = VisibilityBloc.state.value is VisibilityBloc.State.Shown
        NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, buildNotification(isVisible))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("FloatingViewService", "onStartCommand called")
        // Repeated startForegroundService requests need an acknowledgement too.
        promoteToForeground(buildNotification(VisibilityBloc.state.value is VisibilityBloc.State.Shown))
        pendingStart?.complete(Unit)
        Log.d(TAG, "foreground_start_ack startId=$startId observersStarted=$observersStarted")
        TechnicalMonitoring.event("service_foreground_ready")
        if (observersStarted) return START_STICKY
        observersStarted = true

        // One collector per Service instance. It only updates an already-promoted
        // notification; notification permission never gates the promotion itself.
        scope.inMain {
            VisibilityBloc.state.collectLatest {
                val isVisible = it is VisibilityBloc.State.Shown

                val notification = buildNotification(isVisible)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ActivityCompat.checkSelfPermission(
                        this@FloatingVolumeService,
                        Manifest.permission.POST_NOTIFICATIONS,
                    ) != PackageManager.PERMISSION_GRANTED
                ) return@collectLatest

                NotificationManagerCompat.from(this@FloatingVolumeService)
                    .notify(NOTIFICATION_ID, notification)
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
                .collect {
                    inMain {
                        // Only update our indicator if it is currently visible (i.e. user just tapped our buttons)
                        // If it's hidden, physical buttons are used and we let the system UI handle it
                        if (hideIndicatorJob?.isActive == true) {
                            showVolumeIndicator()
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
        TechnicalMonitoring.event("service_destroyed")
        TechnicalMonitoring.state("service_active", "false")
        Log.d(TAG, "service_destroying instance=${System.identityHashCode(this)} tracked=$isViewAttached actual=${floatingMuteView.isAttachedToWindow}")
        cancelSnapAnimation()
        rotationSettleJob?.cancel()
        indicatorRepositionJob?.cancel()
        volumeVerificationJob?.cancel()
        scope.cancel()
        hideIndicatorJob?.cancel()
        hideMixerJob?.cancel()
        peekJob?.cancel()
        resizeSettleJob?.cancel()
        pendingResizeSnapshot = null
        styleExpiryJob?.cancel()
        WidgetSettings.removeListener(::onSettingsChanged)
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        hideVolumeIndicator()
        hideQuickMenu(immediate = true)
        hideAudioMixer()
        // Do not trust isViewAttached during destruction. Always inspect and
        // remove the actual WindowManager attachment before this service exits.
        isViewAttached = false
        if (floatingMuteView.isAttachedToWindow) {
            try {
                windowManager.removeViewImmediate(floatingMuteView)
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "Floating controls already detached during service destruction", e)
            } catch (e: IllegalStateException) {
                Log.w(TAG, "Floating controls changed state during service destruction", e)
            }
        }
        Log.d(TAG, "service_destroyed_views instance=${System.identityHashCode(this)} actual=${floatingMuteView.isAttachedToWindow}")
        updateViewVisibility(false)
        super.onDestroy()
        if (activeInstance === this) activeInstance = null
    }
}
