package com.fixbyte.floatingvolume.pigeon_impl

import NativeApi
import ToastDuration
import android.content.Context
import android.widget.Toast
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc
import com.fixbyte.floatingvolume.bloc.VisibilityBloc
import com.fixbyte.floatingvolume.inIO
import com.fixbyte.floatingvolume.inMain
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first


class NativeApiImpl(
    private val context: Context,
    private val scope: CoroutineScope
) : NativeApi {
    override fun startService(callback: (Result<Unit>) -> Unit) {
        scope.inIO {
            ServiceStatusBloc.event.emit(ServiceStatusBloc.Event.Start)
            // Wait until the state is actually committed before signaling Flutter
            ServiceStatusBloc.state
                .filterIsInstance<ServiceStatusBloc.State.On>()
                .first()
            inMain { callback(Result.success(Unit)) }
        }
    }

    override fun stopService(callback: (Result<Unit>) -> Unit) {
        scope.inIO {
            ServiceStatusBloc.event.emit(ServiceStatusBloc.Event.Stop)
            // Wait until the state is actually committed before signaling Flutter
            ServiceStatusBloc.state
                .filterIsInstance<ServiceStatusBloc.State.Off>()
                .first()
            inMain { callback(Result.success(Unit)) }
        }
    }

    override fun hideFloatingVolume(callback: (Result<Unit>) -> Unit) {
        scope.inIO {
            VisibilityBloc.event.emit(
                VisibilityBloc.Event.Hide
            )
            inMain {
                callback(Result.success(Unit))
            }
        }
    }

    override fun showFloatingVolume(callback: (Result<Unit>) -> Unit) {
        scope.inIO {
            VisibilityBloc.event.emit(
                VisibilityBloc.Event.Show
            )
            inMain {
                callback(Result.success(Unit))
            }
        }
    }

    override fun setMaxVolume(maxVolume: Long, callback: (Result<Unit>) -> Unit) {
        scope.inIO {
//            SystemVolumeBloc
        }
    }

    override fun setMinVolume(minVolume: Long, callback: (Result<Unit>) -> Unit) {
//        TODO("Not yet implemented")
    }

    override fun showToast(
        message: String,
        duration: ToastDuration,
        callback: (Result<Unit>) -> Unit
    ) {
        scope.inMain {
            try {
                Toast.makeText(
                    context,
                    message,
                    when (duration) {
                        ToastDuration.SHORT -> Toast.LENGTH_SHORT
                        ToastDuration.LONG -> Toast.LENGTH_LONG
                    }
                ).show()
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
}