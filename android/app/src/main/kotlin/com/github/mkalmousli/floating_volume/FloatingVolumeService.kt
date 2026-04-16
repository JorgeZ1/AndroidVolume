package com.github.mkalmousli.floating_volume

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
import android.util.Log
import android.view.MotionEvent
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import android.view.animation.DecelerateInterpolator
import androidx.core.animation.doOnEnd
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.github.mkalmousli.floating_volume.bloc.PositionBloc
import com.github.mkalmousli.floating_volume.bloc.ServiceStatusBloc
import com.github.mkalmousli.floating_volume.bloc.SystemVolumeBloc
import com.github.mkalmousli.floating_volume.bloc.VisibilityBloc
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
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.roundToInt

class FloatingVolumeService : Service() {
    private val scope = CoroutineScope(Job())

    companion object {
        const val NOTIFICATION_ID = 1
        const val TAG = "FloatingService"
    }

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        // Load persisted settings and register for live updates
        WidgetSettings.load(sharedPrefs)
        WidgetSettings.addListener(::onSettingsChanged)
    }

    private fun onSettingsChanged() {
        newInMain {
            floatingMuteView.applyTheme()
            volumeIndicatorView?.applyStyle()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        floatingMuteView.dispatchConfigurationChanged(newConfig)
        volumeIndicatorView?.dispatchConfigurationChanged(newConfig)
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
        val dragThreshold = dp(8).toFloat()

        floatingMuteView.handleIv.setOnTouchListener { _, event ->
            when (event.action) {

                MotionEvent.ACTION_DOWN -> {
                    startWindowX = layoutParams.x
                    startWindowY = layoutParams.y
                    startTouchX  = event.rawX
                    startTouchY  = event.rawY
                    isDragging   = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startTouchX
                    val dy = event.rawY - startTouchY

                    if (!isDragging && !WidgetSettings.isPinned &&
                            (abs(dx) > dragThreshold || abs(dy) > dragThreshold)) {
                        isDragging = true
                    }

                    if (isDragging) {
                        layoutParams.x = startWindowX + dx.toInt()
                        layoutParams.y = startWindowY + dy.toInt()
                        windowManager.updateViewLayout(floatingMuteView, layoutParams)
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        snapToEdge()
                    } else {
                        val tapY  = event.y
                        val midY  = floatingMuteView.height / 2f
                        val up    = tapY < midY
                        changeVolume(up)
                        floatingMuteView.flashButton(up)
                    }
                    true
                }

                else -> false
            }
        }
    }

    private fun snapToEdge() {
        val screenW = resources.displayMetrics.widthPixels
        val widgetW = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val margin  = dp(8)

        val targetX = if (layoutParams.x + widgetW / 2 < screenW / 2)
            margin                          // snap izquierda
        else
            screenW - widgetW - margin      // snap derecha

        ValueAnimator.ofInt(layoutParams.x, targetX).apply {
            duration     = 280L
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                layoutParams.x = it.animatedValue as Int
                windowManager.updateViewLayout(floatingMuteView, layoutParams)
            }
            doOnEnd {
                newInIO {
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
        audioManager.adjustVolume(
            if (increase) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER,
            0,
        )
        newInMain { showVolumeIndicator() }
    }

    private fun showVolumeIndicator(forcedVolume: Int? = null) {
        val volume    = forcedVolume ?: audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)

        val screenW  = resources.displayMetrics.widthPixels
        val widgetW  = floatingMuteView.width.takeIf { it > 0 } ?: dp(64)
        val widgetH  = floatingMuteView.height.takeIf { it > 0 } ?: dp(140)
        val indW     = dp(WidgetSettings.indicatorWidth)
        val indH     = dp(WidgetSettings.indicatorHeight)
        val gap      = dp(WidgetSettings.indicatorGap)

        val isOnRight = layoutParams.x + widgetW / 2 > screenW / 2
        val indX = if (isOnRight)
            layoutParams.x - indW - gap
        else
            layoutParams.x + widgetW + gap
        val indY = (layoutParams.y + widgetH / 2 - indH / 2).coerceAtLeast(dp(8))

        if (volumeIndicatorView == null) {
            volumeIndicatorView = VolumeIndicatorView(this).also { it.applyStyle() }
            indicatorParams = LayoutParams(
                indW, indH,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION") LayoutParams.TYPE_PHONE,
                LayoutParams.FLAG_NOT_FOCUSABLE or LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT,
            ).also {
                it.gravity = android.view.Gravity.TOP or android.view.Gravity.START
                it.x = indX
                it.y = indY
            }
            volumeIndicatorView!!.update(volume, maxVolume)
            windowManager.addView(volumeIndicatorView, indicatorParams)
        } else {
            volumeIndicatorView!!.update(volume, maxVolume)
            indicatorParams!!.x = indX
            indicatorParams!!.y = indY
            windowManager.updateViewLayout(volumeIndicatorView, indicatorParams)
        }

        // Auto-hide after configurable delay; reset timer if pressed again
        hideIndicatorJob?.cancel()
        hideIndicatorJob = newInMain {
            kotlinx.coroutines.delay(WidgetSettings.indicatorHideDelay.toLong())
            hideVolumeIndicator()
        }
    }

    private fun hideVolumeIndicator() {
        volumeIndicatorView?.let {
            if (it.isAttachedToWindow) windowManager.removeView(it)
        }
        volumeIndicatorView = null
        indicatorParams     = null
    }

    /** Must be called on the Main thread. */
    private fun updateViewVisibility(shouldShow: Boolean) {
        if (shouldShow && !isViewAttached) {
            windowManager.addView(floatingMuteView, layoutParams)
            isViewAttached = true
        } else if (!shouldShow && isViewAttached) {
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(NOTIFICATION_ID, notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
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
                    }
                }
        }

        Log.d(TAG, "Starting Floating Mute View")
        scope.inIO {
            showFloatingMuteView()
            withContext(Dispatchers.Main) { configureTouchListener() }
        }

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

        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        hideIndicatorJob?.cancel()
        WidgetSettings.removeListener(::onSettingsChanged)
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        hideVolumeIndicator()
        updateViewVisibility(false)
    }
}
