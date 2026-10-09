# Plan de pruebas Android — Floating Volume

## Objetivo

Detectar regresiones antes de publicar, conservar evidencia reproducible y complementar (no sustituir) las pruebas con Crashlytics/Performance en producción. No excluir versiones Android sin evidencia de una incompatibilidad no corregible. Mantener un AAB y adaptar comportamiento por API.

## Sprint 0 — Arranque en primer plano (esta intervención)

- Promover el servicio síncronamente antes de preferencias, monitoreo y corrutinas.
- Crear el canal desde el servicio y la ruta de inicio por reinicio, sin depender de Activity.
- Esperar confirmación de promoción antes de procesar el apagado de la app.
- Registrar observadores una sola vez por instancia, incluso con intents repetidos.
- No condicionar la promoción al permiso POST_NOTIFICATIONS; comprobarlo solo al actualizar notificaciones en API 33+.
- Repetir el caso de API 27 que cerró 0.0.11: 50 ciclos directos, una sesión de intents repetidos, y ciclos mediante el interruptor visible.
- Conservar logcat, versión/APK, captura y pasos. No generar AAB hasta completar y revisar resultados.

## Sprint 1 — Infraestructura y comprobaciones rápidas

Crear AVD exclusivos de Floating Volume; no reutilizar el dispositivo de MintDocx ni modificar sus datos. Ejecutar un emulador a la vez en esta PC (16 GB y memoria libre reducida). Usar aceleración WHPX, 2 núcleos y 1–2 GB de RAM según disponibilidad. Instalar imágenes oficiales, verificar integridad y registrar ABI/imagen.

| Sistema | API | Prioridad | Foco | Estado inicial |
|---|---:|---|---|---|
| Android 7 | 24 | P1 | Mínimo admitido, volumen, overlay y permisos | Pendiente |
| Android 7.1 | 25 | P2 | Comprobación rápida del mínimo sin contrato FGS | Pendiente |
| Android 8 | 26 | P1 | Primera versión con contrato startForegroundService | Pendiente |
| Android 8.1 | 27 | P0 | Timeout reproducido, carreras de inicio/apagado | AVD preparado; regresión de Sprint 0 |
| Android 9 | 28 | P2 | Permiso FOREGROUND_SERVICE y volumen en segundo plano | Pendiente |
| Android 10 | 29 | P1 | Ventanas retiradas, arrastre, ocultamiento y giro | Pendiente |
| Android 11 | 30 | P2 | Overlay, navegación gestual y permisos | Pendiente |
| Android 12 | 31 | P1 | Restricciones de inicio en segundo plano | Pendiente |
| Android 12L | 32 | P2 | Pantalla amplia y geometría en horizontal | Pendiente |
| Android 13 | 33 | P1 | Notificaciones concedidas, denegadas y revocadas | Pendiente |
| Android 14 | 34 | P1 | Tipo specialUse y permisos del servicio | Pendiente |
| Android 15 | 35 | P1 | Inicio desde reinicio, permisos y geometría | Pendiente |
| Android 16 | 36 | P0 | targetSdk actual del proyecto y regresiones completas | Crear AVD propio; no tocar el AVD de otra app |
| Android 17 | 37 | P0 | Compatibilidad en plataforma más reciente, orientación y ventanas | Pendiente; AVD exclusivo |

La imagen AOSP API 27 x86_64 no incluye Play Store/Google Play services: sirve para ciclo de servicio y UI, no certifica anuncios o distribución por Play. Usar imágenes Google APIs/Play donde estén disponibles para esas pruebas.

Orden de ejecución: P0 (27, 36 y 37), P1 en orden de API, después P2. En P0/P1 ejecutar la tabla completa; en P2 al menos apertura, activar/apagar, volumen desde Home, giro y permisos. Añadir teléfono compacto/texto grande y pantalla amplia. Comprobar ARM64 en teléfono real y páginas de memoria de 16 KB en un AVD propio de API 35/36/37; no dar por validada otra ABI por pasar x86_64. Probar la compilación actual en API 37 no requiere aumentar targetSdk en esta intervención; la migración de target es un cambio separado.

Referencia vigente consultada: [Android 17 publicado y cambios de compatibilidad](https://developer.android.com/blog/posts/android-17-is-here?hl=en). Separar cambios aplicables a todas las apps de los que exigen targetSdk 37.

## Sprint 2 — Casos repetibles por API

| Caso | Ejecución | Criterio de aprobación |
|---|---|---|
| Inicio en frío | 10 aperturas tras force-stop, activación desde UI | No cierres; notificación y un solo overlay |
| Carrera inicio/apagado | 50 ciclos directos y 30 desde interruptor | Sin RemoteServiceException/ANR; estado final apagado |
| Inicio repetido | 10 intents sobre una instancia activa | Una instancia/observadores; sin ventanas duplicadas |
| Segundo plano | Inicio, Home, otra app y regreso | Multimedia cambia realmente; sin usar el volumen visual como única prueba |
| Volumen | Comparar AudioManager/dumpsys antes/después con sonido multimedia y sin reproducción | Cambia STREAM_MUSIC dentro de límites; no cambia otro canal inesperadamente |
| Giro | 20 giros vertical/horizontal con controles e indicador visibles | Sin superposición; posición válida y distancia independiente del giro |
| Gestos | Pulsación prolongada + arrastre al aparecer menú, 30 intentos | Auxiliares se retiran; no hay duplicados ni ventanas huérfanas |
| Tamaño/forma | Mínimo/máximo y restauración por estilo | Controles recuperables; esquinas cambian; anclaje lateral conservado |
| Ocultamiento | Automático activado/desactivado y recuperación, 30 intentos | Controles accesibles en borde; sin guía ni espacio residual inesperados |
| Permisos | Sin overlay; permiso revocado en ejecución; notificaciones denegadas en 33+ | Fallo controlado, estado coherente, no cierre ni promoción omitida |
| Reinicio | Habilitado/deshabilitado antes de reinicio real del AVD | Respeta elección; sin timeout; documentar restricciones de API/OEM |
| Actualización | Instalar nueva compilación sobre anterior sin borrar datos | Preferencias/accesos preservados; reinicio del servicio coherente |
| Sin red | Abrir, activar, ajustar y pedir anuncio/reporte sin red | Control local funciona; no recompensa ficticia ni pérdida del formulario |
| Reportes | 0/1/2 imágenes, cancelar selector, fallo y reintento | Datos conservados; máximo dos; botón visible con teclado/navegación |
| Idioma/accesibilidad | Español/inglés/sistema no español, texto grande | Traducción/fallback correcto; controles sin overflow y etiquetados |

Los ciclos shell son complementarios: no equivalen al flujo Flutter/ServiceStatusBloc ni a un teléfono OEM. Medir intervalos reales en logs; 100 ms de espera del host no significa 100 ms exactos entre callbacks de Android.

Scripts disponibles para API 27:

- `scripts/test_api27_startup.ps1 -Cycles 50`: prueba adversarial original, detiene desde shell sin esperar promoción. Conservar también resultados fallidos; puede cancelar la petición antes de que Android entregue onCreate.
- `scripts/test_api27_startup.ps1 -Cycles 50 -WaitForPromotion`: verifica el contrato de promoción antes de detener, como hace el controlador corregido. No reemplaza ni oculta el resultado de la variante anterior.
- `scripts/test_api27_ui_startup.ps1 -Cycles 30`: usa el interruptor real, espera estado habilitado y comprueba apagado/ausencia de servicio activo. Los toques durante el estado ocupado pueden ignorarse por diseño y no deben contarse como ciclos completos.

Para cualquier fallo, clasificar si pertenece al flujo real de la app, a una llamada externa que omite sus protecciones o a una limitación del AVD. Antes de publicar, revisar explícitamente los fallos P0 abiertos; no cambiar un FAIL a PASS solo por modificar el escenario.

## Sprint 3 — Dispositivos físicos y distribución

- Samsung disponible: gestos, notificación nativa, orientación, batería.
- Realme/ColorOS y Huawei/EMUI: acceso a hardware real, préstamo o laboratorio remoto si disponible; no declarar resuelto un fallo OEM solo por emulador.
- Modelo S7 del evento: confirmar fabricante exacto en Firebase; “S7” no basta para identificarlo como Samsung.
- No manipular teléfonos conectados que estén dedicados a otras pruebas sin confirmar disponibilidad.
- Debug usa anuncios de prueba y monitoreo desactivado, salvo habilitación explícita para validar diagnósticos. Jamás hacer clic automático en anuncios reales ni contaminar Crashlytics producción con cierres sintéticos.
- Tras verificar, preparar release y subir a prueba interna. Instalar desde Play, comprobar firma/actualización y recepción en la app Firebase de producción. Una captura debug no valida release.

## Sprint 4 — Puerta de salida y observabilidad

- Flutter tests/analyze y pruebas Kotlin aprobados; APK/AAB de la misma revisión que la evidencia.
- Sin fallos en escenarios P0, sin ANR ni ventanas residuales y sin regresión del volumen real.
- Registrar por caso: API, AVD/dispositivo, ABI, versión, fecha, repeticiones, resultado, pasos, log y captura. Usar PASS/FAIL/PENDIENTE/NO APLICA; no dejar vacíos como si fueran aprobados.
- Archivar Crashlytics mapping/símbolos por compilación; comprobar desofuscación y app Firebase correcta.
- Publicación gradual solo tras autorización del usuario; decidir expansión con suficientes sesiones y cobertura de dispositivos, no solo por haber pasado un plazo.
- Comparar fallas/ANR por versión, API y fabricante; agrupar nuevas incidencias y priorizar por usuarios afectados, frecuencia e impacto. Android vitals complementa Firebase para ANR.
- Bloquear expansión ante nueva regresión grave del arranque/volumen; investigar y corregir, no interpretar cero eventos con poca muestra como garantía.

## Estado

Este documento es un plan de ejecución. Las APIs pendientes no se han probado todavía. Los resultados efectivos del Sprint 0 se registran en `docs/ANDROID81_TESTING.md`; no extender esos resultados a otras versiones.
