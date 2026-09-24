# Floating Volume — contexto técnico del proyecto

Este documento describe el estado real del proyecto y las decisiones que deben conservarse al modificarlo.

## Producto actual

Floating Volume es una aplicación Android construida con Flutter/Dart y un servicio nativo Kotlin. Muestra sobre otras aplicaciones un control flotante arrastrable con dos botones (`+` y `−`). Al cambiar el volumen aparece un indicador vertical que también funciona como slider táctil.

El servicio puede seguir activo cuando la interfaz Flutter está cerrada. Android exige una notificación persistente mientras el overlay está funcionando.

### Interacciones existentes

- Tap en la mitad superior: aumenta el volumen.
- Tap en la mitad inferior: reduce el volumen.
- Arrastre: mueve el widget si no está fijado.
- Al terminar el arrastre: el widget se ajusta al borde más cercano y guarda su posición por orientación.
- Pulsación larga: abre un menú rápido con `Ocultar burbuja` y `Detener servicio`.
- Indicador de volumen: puede tocarse o arrastrarse; arriba representa 100 % y abajo 0 %.
- Notificación del servicio: permite mostrar/ocultar el widget y detener el servicio.
- `isPinned`: bloquea el movimiento, pero no bloquea los taps de volumen ni la pulsación larga.

### Visibilidad actual

`VisibilityBloc` sólo conoce tres situaciones funcionales: no inicializado, mostrado y oculto. Ocultar elimina el overlay del `WindowManager`; no queda una pestaña visible para recuperarlo. Para volver a mostrarlo se usa la app o la notificación.

Todavía no existe:

- autoocultamiento por inactividad;
- estado parcialmente oculto o “asomado” en el borde;
- gesto desde el borde para recuperarlo;
- temporizador de inactividad del widget principal;
- diferenciación entre ocultamiento manual y automático.

## Arquitectura

El flujo principal es:

`Flutter UI → MethodChannel/Pigeon → Kotlin Service → Android AudioManager/WindowManager`

Los eventos de estado regresan de Kotlin a Flutter mediante streams Pigeon.

### Flutter

- `lib/main.dart`: entrada de la aplicación.
- `lib/src/app.dart`: tema y proveedores BLoC.
- `lib/src/screens/home.dart`: pantalla principal, estilos, vistas previas y opciones avanzadas.
- `lib/src/screens/permissions.dart`: permisos de overlay, notificación y optimización de batería.
- `lib/src/widget_settings.dart`: ajustes mantenidos en Flutter y llamadas al canal `floating_volume/settings`.
- `lib/src/bloc/status/`: estado del servicio y de visibilidad.
- `lib/src/bloc/permissions/`: permisos Android.
- `lib/src/bloc/theme/`: tema de la app.

### Kotlin / Android

- `FloatingVolumeService.kt`: servicio en primer plano; crea los overlays, procesa taps, arrastre, snap, pulsación larga, indicador y notificación.
- `FloatingVolumeView.kt`: botones `+` y `−` y aplicación del estilo elegido.
- `VolumeIndicatorView.kt`: indicador vertical, estilos y conversión entre posición táctil y porcentaje.
- `WidgetSettings.kt`: ajustes nativos persistidos en `SharedPreferences`.
- `MainActivity.kt`: inicialización de BLoCs, Pigeon y canal de ajustes.
- `NotificationBroadcastReceiver.kt`: acciones de mostrar/ocultar y detener.
- `BootReceiver.kt`: reinicio tras arranque/actualización cuando corresponde.
- `bloc/PositionBloc.kt`: posición guardada separadamente por orientación.
- `bloc/VisibilityBloc.kt`: mostrado/oculto.
- `bloc/ServiceStatusBloc.kt`: ciclo de vida del servicio.
- `bloc/SystemVolumeBloc.kt`: observación y escritura del volumen.
- `style/ClassicStyles.kt` y `style/AnimatedStyles.kt`: estilos nativos reales.
- `style/StyleFactory.kt`: selección del estilo.

### Comunicación Flutter ↔ Kotlin

- Pigeon `NativeApi`: iniciar/detener servicio, mostrar/ocultar widget y límites de volumen.
- Pigeon `NativeEvents`: estado del servicio y visibilidad.
- `MethodChannel('floating_volume/settings')`: ajustes visuales y de comportamiento aplicados en vivo.
- Si cambian los archivos de `pigeons/`, regenerar Dart y Kotlin; no editar los generados manualmente.

## Audio: comportamiento y limitaciones actuales

El control se centraliza en `AudioStream` y el canal principal elegido se persiste en `WidgetSettings.selectedAudioStream`. Botones, indicador, slider táctil y observador usan el mismo stream seleccionado. El mezclador nativo ofrece barras para:

- multimedia (`STREAM_MUSIC`);
- tono de llamada (`STREAM_RING`);
- notificaciones (`STREAM_NOTIFICATION`);
- alarma (`STREAM_ALARM`);
- sonidos del sistema (`STREAM_SYSTEM`);
- llamada (`STREAM_VOICE_CALL`), sólo habilitada durante llamada o comunicación activa.

Android y cada fabricante pueden vincular algunos canales. En muchos teléfonos, llamada y notificaciones comparten nivel; no debe asumirse que son siempre independientes. El volumen de llamada sólo tiene sentido durante una llamada activa y puede estar restringido por versión/fabricante. “Configuración” no es un canal de audio: los sonidos de interacción pertenecen normalmente a `STREAM_SYSTEM`.

Al añadir un nuevo canal, actualizar `AudioStream`; nunca introducir una constante de stream aislada. Toda lectura, escritura, porcentaje, broadcast e indicador debe recibir el mismo stream seleccionado; de lo contrario la barra mostrará un canal mientras los botones modifican otro.

No usar `adjustVolume()` para esta función: deja al sistema elegir el stream activo y produce resultados impredecibles. Usar explícitamente `getStreamVolume`, `getStreamMaxVolume`, `setStreamVolume` o `adjustStreamVolume` con el stream elegido.

## Autoocultamiento plegado al borde

No se implementa un ocultamiento total como comportamiento predeterminado: una vez eliminado el overlay, Android no entrega a esta app un gesto global desde el borde sin añadir accesibilidad u otros mecanismos invasivos. El usuario podría creer que el control desapareció o no saber recuperarlo.

La aplicación implementa un estado adicional **plegado/asomado**:

1. Tras un periodo configurable sin interacción, animar el widget hacia su borde guardado.
2. Dejar visible una pestaña configurable de 8–24 dp.
3. Tap o deslizamiento hacia el centro despliega los botones.
4. Cualquier tap, arrastre, cambio de volumen o apertura del menú reinicia el temporizador.
5. No plegar mientras el dedo está abajo, el indicador está activo, el menú rápido está abierto o la app está configurando el widget.
6. Mantener en la notificación las acciones Mostrar/Ocultar/Detener como recuperación segura.
7. Ofrecer en Opciones avanzadas: activado/desactivado, espera (3–30 s) y tamaño de pestaña.

El lado se determina por el borde al que el usuario ajustó el widget. La posición expandida se conserva; el estado plegado nunca reemplaza la posición guardada.

Estados sugeridos para evitar carreras:

`ShownExpanded → ShownPeeking → Hidden`

`Hidden` sigue reservado para una acción explícita del usuario. El autoocultamiento conserva la vista adjunta para recibir el gesto de recuperación y no usa `VisibilityBloc.Hide`.

Guardar por orientación tanto la posición expandida como el borde elegido. Al rotar, cancelar animaciones y temporizadores antes de restaurar la posición correspondiente.

## Estilos y personalización

Hay cinco estilos clásicos (`Android`, `Android 12`, `iOS`, `MIUI`, `One UI`) y siete especiales (`RGB Aurora`, `RGB Neon`, `Cosmic`, `Lava`, `Glacier`, `Matrix`, `Retrowave`). Las vistas previas Flutter deben representar el mismo aspecto y estructura que los drawables Kotlin.

Los estilos especiales usan animadores infinitos. Deben detenerse al ocultar o plegar completamente el widget y reiniciarse al mostrarlo para reducir CPU/GPU y batería.

## Persistencia y ajustes

Los ajustes se almacenan en `SharedPreferences` y deben existir de forma equivalente en:

1. `lib/src/widget_settings.dart`;
2. `MainActivity.kt` (handler del canal);
3. `WidgetSettings.kt` (valor, clave, carga y guardado);
4. consumidor nativo correspondiente;
5. restauración de valores predeterminados.

No agregar un control sólo en Flutter: parecerá funcionar en la interfaz pero no afectará al overlay.

## Permisos y ciclo de vida

- `SYSTEM_ALERT_WINDOW`: overlay.
- `POST_NOTIFICATIONS`: notificación del servicio.
- `MODIFY_AUDIO_SETTINGS`: modificación de audio.
- `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: servicio en primer plano.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: supervivencia del servicio.
- `RECEIVE_BOOT_COMPLETED`: recuperación tras reinicio.

No presentar la excepción de batería como garantía: MIUI, ColorOS y One UI pueden detener servicios aun con ella. Mantener una vía de recuperación desde la notificación y la app.

## Compilación y verificación

```bash
dart run pigeon --input pigeons/native_api.dart
dart run pigeon --input pigeons/native_events.dart
dart run build_runner build
flutter analyze lib
flutter test
flutter build apk --release
```

- Regenerar Pigeon sólo cuando cambien sus definiciones.
- Ejecutar `build_runner` al cambiar modelos Freezed.
- El APK release requiere `android/key.properties`.
- Para actualizar una instalación existente, la firma debe coincidir.
- El proyecto conserva deuda previa en pruebas/análisis; distinguir errores nuevos de advertencias existentes.
- Tras cambios de overlay, probar en dispositivo: mostrar/ocultar, rotar, reiniciar servicio, arrastrar en ambos bordes, fijar posición, pulsación larga, indicador táctil y restauración tras proceso muerto.

## Reproducibilidad, licencia y archivos generados

- Objetivo de distribución: F-Droid y builds reproducibles.
- Licencia: GPL v3; mantener compatibilidad.
- No editar archivos generados por Pigeon.
- No reemplazar en commits los IDs placeholder de AdMob por credenciales reales.
- No incluir claves de firma.
- Preservar los cambios locales existentes: el árbol de trabajo puede estar modificado.
