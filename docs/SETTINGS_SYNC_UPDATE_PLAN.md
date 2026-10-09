# Plan de actualización: ajustes persistentes y valores visibles

Fecha: 8 de octubre de 2026.
Proyecto: `D:\codigos\Floating Volume\FloatingVolume`.
Estado: auditoría del código completada; implementación y pruebas de reproducción pendientes.

## Objetivo

Que cada deslizador, interruptor y selector muestre exactamente el ajuste que utiliza el servicio Android. Cerrar la app, reiniciarla o instalar una actualización debe conservar la configuración válida del usuario. Una actualización no debe incrementar el paso de volumen ni sustituir los valores elegidos por predeterminados.

## Hallazgos comprobados en el código

Android guarda los ajustes de los controles en el archivo `prefs`. Flutter mantiene campos estáticos y, para algunos ajustes, otra copia en `FlutterSharedPreferences`. La carga de Home lee esa segunda copia y vuelve a ejecutar setters sobre Android. Esto produce dos fallas diferentes: valores visibles predeterminados con valores nativos guardados, y valores nativos sobrescritos al abrir Home.

Evidencia:

- [Almacén nativo](<D:/codigos/Floating Volume/FloatingVolume/android/app/src/main/kotlin/com/fixbyte/floatingvolume/Utils.kt:12>) y [nombre del archivo](<D:/codigos/Floating Volume/FloatingVolume/android/app/src/main/kotlin/com/fixbyte/floatingvolume/Const.kt:4>).
- [Carga y persistencia nativas](<D:/codigos/Floating Volume/FloatingVolume/android/app/src/main/kotlin/com/fixbyte/floatingvolume/WidgetSettings.kt:148>).
- [Carga de Home y reproducción de setters](<D:/codigos/Floating Volume/FloatingVolume/lib/src/screens/home.dart:424>).
- [Campos Flutter y setters](<D:/codigos/Floating Volume/FloatingVolume/lib/src/widget_settings.dart:33>).
- [Cambio del canal desde el mezclador nativo](<D:/codigos/Floating Volume/FloatingVolume/android/app/src/main/kotlin/com/fixbyte/floatingvolume/FloatingVolumeService.kt:1143>).

La revisión cubre 25 propiedades de WidgetSettings. Estos hallazgos identifican rutas concretas del código; todavía no representan una reproducción nueva en el teléfono.

| Grupo | Propiedades | Comportamiento actual |
|---|---|---|
| 12 valores visibles sin restauración desde Android | `volumeStep`, `buttonSize`, `buttonGap`, `opacity`, `hapticFeedback`, `indicatorWidth`, `indicatorHeight`, `indicatorGap`, `indicatorOpacity`, `indicatorHideDelay`, `showIndicatorNumber`, `showIndicatorIcon` | Android conserva el valor; Flutter vuelve a mostrar su predeterminado al iniciar un proceso nuevo. |
| 4 valores que Home puede sobrescribir | `selectedAudioStream`, `showAudioMixer`, `autoPeekDelay`, `peekSize` | Los setters guardan en Android, pero Home lee claves Flutter que esos setters no escriben y vuelve a enviar predeterminados o copias antiguas. También puede perderse el canal elegido desde el mezclador. |
| 1 valor con restauración parcial | `autoPeekEnabled` | El interruptor de Home escribe ambos almacenes. Restaurar la sección usa un setter que solo guarda en Android: una copia Flutter anterior puede deshacer la restauración al reabrir. |
| 6 valores con sincronización actual en sus rutas principales | `style`, `isPinned`, `useSystemVolume`, `creativeAnimSpeed`, `creativeGlowIntensity`, `buttonCornerRadius` | Estilo, fijar posición, indicador nativo y ajustes creativos tienen copias Flutter guardadas y restauradas. El redondeo se consulta desde Android por estilo. Incluirlos en regresión porque las rutas de cambios/restauración no comparten una sola fuente. |
| 2 propiedades internas sin control visible actual | `colorMode`, `indicatorAnimation` | Flutter conserva predeterminados sin consultar los valores nativos. Preservar estos datos durante la sincronización; no crear controles nuevos como parte de esta corrección. |

Idioma y tema claro/oscuro sí cuentan con escritura y lectura persistentes propias antes de presentar su estado. El estado activo del servicio utiliza su flujo nativo. No se encontró en esas rutas el mismo fallo de carga; conservarlas y verificar que la corrección no interfiera con ellas.

No existe una migración que haga `volumeStep + 1` por actualización. La suma ocurre al tocar +/- sobre el volumen actual. El valor guardado y el valor mostrado pueden diferir, pero el aumento automático de exactamente un nivel en cada instalación requiere aún una reproducción controlada.

## Otras diferencias de presentación

- Home formatea `autoPeekDelay` con división entera: 1800 ms aparece como `1s`, aunque el tiempo efectivo es 1.8 s.
- Tamaño/separación de botones y ancho/alto/distancia de la barra muestran `px`; Android convierte esos valores mediante `dp(...)`. Uniformar las etiquetas a `dp`, como ya hace el ancho visible en el borde, sin cambiar la escala física aplicada.
- El tiempo de ocultamiento nativo admite 1000–30000 ms; el deslizador actual muestra 1000–10000 ms. La restauración de una configuración nativa debe evitar dejar un valor fuera de los límites de Slider. El rango visual debe poder representar valores nativos válidos existentes.
- La elección de canal usa `DropdownButtonFormField.initialValue`. Actualizar el estado real debe también actualizar ese control después de cambios desde el mezclador o de restaurar la sección.

## Decisión de persistencia

Usar `prefs` de Android como fuente de los ajustes consumidos por el servicio. Exponer una lectura completa de los valores efectivos por el canal `floating_volume/settings`; Flutter los carga y los representa sin reenviar predeterminados durante el arranque.

Las preferencias de idioma, tema, recompensas y reportes conservan su almacenamiento propio. Se corrige la configuración del control flotante sin trasladar datos de otras funciones.

Reglas de migración, una sola vez y de forma idempotente:

1. Si una clave nativa tiene un valor válido, conservarlo.
2. Si falta la clave nativa y existe una copia Flutter histórica válida, importarla.
3. Si ambas faltan, usar el predeterminado actual.
4. Normalizar únicamente datos inválidos con límites acordados; el paso de volumen debe quedar entre 1 y 5. No aumentar ni reiniciar valores válidos por cambiar de versión.
5. Preservar radios por estilo y su migración histórica desde el radio global. Transmitir estilos por nombres estables, con correspondencia explícita entre los enums Kotlin/Dart; no interpretar ordinales Kotlin como índices Dart.
6. Actualizar la versión de migración después de guardar los datos. No borrar copias históricas antes de terminar y verificar la migración.

## Sprint 1 — lectura y migración

Archivos principales: WidgetSettings.kt, MainActivity.kt y widget_settings.dart.

- Definir un contrato completo y tipado de los 25 ajustes: nombres, unidades, valores predeterminados y límites.
- Implementar la migración idempotente según las reglas anteriores, disponible también cuando el servicio inicia sin Home.
- Añadir `getSettings` para obtener los valores efectivos, incluidos el estilo activo y su radio. La consulta no debe reescribir preferencias ni disparar cambios visuales del overlay.
- Cargar el estado inicial de forma coherente, evitando notificar a los observadores una vez por cada propiedad durante una carga masiva.

Criterio de salida: datos nativos válidos sobreviven intactos; se importan únicamente claves nativas ausentes; repetir la inicialización no modifica el paso ni otros valores.

## Sprint 2 — interfaz y cambios confirmados

Archivos principales: widget_settings.dart, home.dart y el canal nativo.

- Sustituir en `_loadSettings` la reproducción de setters por la lectura de `getSettings`.
- Mostrar los controles cuando los ajustes estén cargados y volver a consultarlos al reanudar la app.
- Hacer que los cambios nativos, como seleccionar un canal en el mezclador, actualicen también Home mientras permanece abierto; reutilizar las notificaciones de ajustes para comunicar un estado completo y coherente.
- Centralizar las escrituras y reflejar el valor aceptado por Android. Si una llamada falla, conservar/restaurar el último valor confirmado y permitir reintento, sin mostrar que un ajuste se guardó cuando no ocurrió.
- Resolver el selector de canal para que refleje cambios externos y restauraciones.
- Mantener los cambios rápidos de un deslizador ordenados y evitar que una lectura pendiente vuelva a colocar un valor anterior.

Criterio de salida: cada control muestra el valor efectivo del servicio después de carga, edición, cambio nativo y reanudación.

## Sprint 3 — restauración, rangos y etiquetas

- Restaurar cada sección como una actualización coherente, persistida y reflejada tanto en Home como en el servicio.
- Corregir `autoPeekEnabled` para que una restauración no sea deshecha al reiniciar.
- Mostrar 1800 ms como `1.8 s`, con formato localizado y sin truncar segundos. Permitir que el deslizador represente ese predeterminado y valores históricos válidos de hasta 30 s.
- Unificar los límites aceptados por Android y los controles Flutter; evitar valores fuera del rango visual y respetar valores válidos que no coincidan con una marca discreta.
- Uniformar unidades de geometría a dp; conservar las dimensiones efectivas actuales.
- Mantener el redondeo por diseño y verificar la dirección redondo → cuadrado, incluido MIUI y One UI.

Criterio de salida: restaurar una sección afecta solo a esa sección y persiste tras reinicio; textos, posición del deslizador y unidades corresponden al ajuste real.

## Sprint 4 — pruebas de conservación y comportamiento

Primero documentar la reproducción del fallo actual para distinguirlo de un aumento real del paso entre instalaciones. Preparar una configuración con valores no predeterminados en los cuatro grupos visibles: botones, audio, barra y creatividad.

| Caso | Validación requerida |
|---|---|
| Reinicio del proceso | Guardar cambios, cerrar el proceso y reabrir. La interfaz y el servicio conservan los mismos valores. |
| Paso de volumen | Con valor 3 y volumen lejos del mínimo/máximo, un toque cambia exactamente 3 niveles. Repetir con 1 y 5, subida y bajada; cerca de límites, respetar la saturación de Android. |
| Conservación entre instalaciones | Instalar la base debug y luego el debug corregido con el mismo applicationId/firma, sin borrar datos. Repetir la instalación tres veces: el paso permanece igual y coincide con el texto visible. |
| Canal desde mezclador | Elegir otro canal desde el overlay y comprobar el selector de Home abierto, reanudado y después de un arranque nuevo. |
| Restaurar sección | Restaurar botones después de desactivar auto-ocultamiento. Reabrir y comprobar que el valor restaurado sigue activo; ajustes de audio/barra/creatividad elegidos en otras secciones se conservan. |
| Redondeo por estilo | Alternar RGB Aurora, MIUI y One UI con radios distintos; cerrar/reabrir y confirmar radio visible y aplicado. |
| Migración | Cubrir clave nativa existente, clave nativa ausente con legado Flutter, ambos ausentes, valor inválido y repetición de migración. La preferencia nativa válida tiene prioridad. |
| Cambios rápidos/errores | Arrastrar un deslizador y cambiar de pantalla/reanudar; comprobar último valor confirmado. Simular fallo del canal y comprobar que no queda un valor ficticio en pantalla. |
| Textos y dimensiones | Español/inglés: 1.8 s se muestra sin pérdida de precisión; valores dp conservan tamaño según densidad; ningún Slider sale de rango. |

Automatización: pruebas de migración/contrato nativas y pruebas Flutter de carga y presentación con valores no predeterminados y de respuesta fallida. Completar `flutter analyze`, `flutter test` y `:app:testDebugUnitTest`. Las pruebas existentes no cubren todavía este ciclo completo.

Prueba práctica mínima: un emulador Android 8.1 (API 27) y el Samsung conectado cuando esté disponible. Registrar preferencias antes/después y lecturas reales de volumen; no contar ciclos hechos en otra app como evidencia de esta app. La actualización sobre la instalación de Play debe comprobarse además desde una pista de prueba de Play con la misma firma de distribución.

Criterio de salida: cero diferencias entre configuración guardada, configuración efectiva y controles visibles en los casos anteriores; sin incremento del paso después de instalaciones repetidas.

## Sprint 5 — paquete de actualización

- El AAB `FloatingVolume-0.0.12-build13.aab` creado antes de esta auditoría todavía contiene los problemas encontrados. Después de implementar los sprints, generar y validar un artefacto nuevo.
- Si el código 13 aún no fue enviado a Play, se puede reconstruir 0.0.12 (13) y actualizar su checksum/notas. Si ya fue enviado, usar 0.0.13 (14), siempre que ese código no esté ocupado en otra pista. Confirmar el estado de Console antes de elegir.
- Preparar notas localizadas: conservación de preferencias entre reinicios/actualizaciones; controles que reflejan valores guardados; mejoras en restauración, tiempos y unidades.
- Verificar nombre/código, firma de carga y paquete del AAB. Conservar su mapa R8 y checksum junto con los resultados.
- Instalar desde prueba interna y validar una actualización con configuración no predeterminada antes del despliegue de producción.

## Entregables

Corrección de sincronización y migración, pruebas de conservación reproducibles, debug para revisión en el teléfono, notas de versión y AAB regenerado después de verificar la implementación.

Este plan no certifica ni da por resueltos los fallos de servicio/renderizado de fabricantes que se investigan en la matriz Android; sus hallazgos siguen registrados por separado.

## Estado de ejecución — 8 de octubre de 2026

- Sprints 1–3: implementados; contrato nativo de 25 campos, migración, estado confirmado en Home, eventos, restauración por sección y tiempos/unidades coherentes.
- Sprint 4: 38 pruebas Flutter y 15 Kotlin aprobadas; análisis sin incidencias; discrepancia anterior reproducida y tres reinstalaciones verificadas en API 27, restauración persistente y 12 casos de volumen real (pasos 1/3/5) desde la pantalla de inicio. Debug instalado y abierto en Samsung, conservando sus ajustes existentes. Los límites y los intentos no concluyentes están en `SETTINGS_SYNC_VERIFICATION.md`.
- Sprint 5: debug y AAB 0.0.13 (14) generados; firma, metadatos y estructura validados, mapa R8 conservado y notas en 11 idiomas preparadas. Se eligió el siguiente código para no sobrescribir el artefacto 13 anterior; aún corresponde comprobar su disponibilidad en Console.
- Pendiente externo antes de producción: subir a prueba interna y comprobar actualización desde Play con la firma de distribución. No se publicó la versión ni se certificaron todos los fabricantes.
