package com.fixbyte.floatingvolume.pigeon_impl

import FloatingVolumeVisibilityStreamHandler
import PigeonEventSink
import com.fixbyte.floatingvolume.bloc.ServiceStatusBloc
import com.fixbyte.floatingvolume.bloc.VisibilityBloc
import com.fixbyte.floatingvolume.inIO
import com.fixbyte.floatingvolume.inMain
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest

class FloatingVolumeVisibilityStreamHandlerImpl(
    private val scope: CoroutineScope
) : FloatingVolumeVisibilityStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Boolean>) {
        job = scope.inIO {
            VisibilityBloc.state
                .collectLatest {
                    val visible = when (it) {
                        VisibilityBloc.State.Shown -> true
                        else -> false
                    }

                    scope.inMain {
                        sink.success(visible)
                    }
                }
        }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}