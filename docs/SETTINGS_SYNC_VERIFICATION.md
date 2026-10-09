# Verificación de sincronización de ajustes — 8 de octubre de 2026

Versión implementada: **0.0.13 (14)**. Repositorio: `D:\codigos\Floating Volume\FloatingVolume`.

## Resultado

La causa reproducida no es una operación que incremente el paso de volumen durante una actualización. La instalación base conserva `widget_vol_step=3` en Android, pero un arranque nuevo muestra `1 level` y tamaño `44px` en Flutter, aunque el tamaño nativo es 64. El debug corregido muestra `3 levels` y `64dp`, conservando los valores después de tres reinstalaciones sin borrar datos.

Se implementó un contrato completo para 25 ajustes, migración idempotente, lectura completa sin reenviar predeterminados, escrituras confirmadas y ordenadas, eventos de cambios nativos, restauración agrupada por sección y presentación precisa de tiempos/unidades. Se mantiene el radio por estilo; las copias Flutter antiguas ya no deshacen ajustes nativos existentes.

## Pruebas completadas

| Prueba | Resultado y evidencia |
|---|---|
| Análisis Flutter | `flutter analyze --no-pub`: sin incidencias. |
| Pruebas Flutter | 38 aprobadas, incluidas 8 nuevas de sincronización. Cubren carga sin reproducción de setters, valor confirmado, fallo/reintento, orden de lecturas/escrituras, evento del mezclador y lectura antigua, restauración, instantáneas inválidas y formato de tiempos. |
| Pruebas Kotlin | 15 aprobadas: 7 de geometría del indicador, 3 de posición y 5 de persistencia/migración. Se repitieron después del último cambio nativo. |
| Android 8.1 / API 27 | Baseline: discrepancia nativo 3 / visible 1 reproducida. Actualización al debug corregido y tres reinstalaciones: paso 3 y tamaño 64 conservados y visibles; otras 13 preferencias no predeterminadas verificadas en cada ciclo. `test-artifacts/settings-sync/upgrade-api27-final.log` y XML de cada ciclo. |
| Restauración de botones API 27 | Botones regresan a paso 1, tamaño 44, separación 10, ocultamiento automático activo y espera de 1800 ms. Canal ALARM y ancho del indicador 48 permanecen. Tras un arranque nuevo, UI muestra 1 nivel, 44dp y `1.8 s`. `reset-api27-confirmed.log`. |
| Volumen real desde Home del sistema API 27 | Pasos 1, 3 y 5: subida/bajada desde volumen 7 y saturación en 0/15, 12 casos aprobados. Se verificaron valores `before`, `target` y `actual` del AudioManager mediante toques en el overlay fuera de la app. `volume-steps-results.log` y `volume-steps-api27-final.log`. |
| Samsung SM-S926W | Instalación sobre el debug existente, apertura correcta y comparación antes/después: ninguna clave nativa `widget_*` previamente existente cambió. Se conservó, entre otros, tamaño 36 y paso 1. La instalación usa `com.fixbyte.floatingvolume.debug` y no sustituye la versión Play. |
| AAB | `bundletool validate` aprobado; paquete, versión, SDK y firma revisados. Mapa R8 local coincide con el incorporado en el AAB. |

## Entorno y límites de las pruebas

- Se recuperó la imagen AOSP oficial API 27, archivo `x86_64-27_r01.zip`, y se comprobó su SHA-1 contra el repositorio de Google antes de extraerla en el directorio QA aislado. AVD exclusivo `FloatingVolume_Settings_API27`, puerto 5582, 1024 MiB y 2 núcleos. Se utilizó GPU host para las pruebas finales.
- En API 29 con SwiftShader se observaron errores de Impeller y automatización no concluyente. Ese intento no certifica API 29. Los primeros intentos API 27 tampoco se contaron: faltaba la exclusión de batería y la app estaba en la pantalla de permisos; los logs se conservan.
- El primer chequeo de restauración leyó el XML antes de terminar el procesamiento del toque; al consultar después, los valores sí estaban restaurados. La automatización ahora espera el estado persistido y evita elementos recortados por el viewport. El intento posterior completo pasó.
- La prueba de volumen necesitó ADB root en el emulador porque el servicio no está exportado. No se cambió ese atributo de seguridad. Los pasos se prepararon en preferencias del emulador; los cambios de volumen se hicieron con los botones reales, no llamando directamente al método de ajuste de la app. Las preferencias previas al test se restauraron al terminar.
- La propagación desde el mezclador y el redondeo MIUI/One UI se cubrieron en pruebas automatizadas de contrato/eventos; en esta ejecución no se certificaron visualmente todas esas interacciones en hardware OEM.
- No se reprodujeron los firmware Vivo/Huawei ni se certificó toda la matriz Android. No se ejecutó una actualización de la app de Play: requiere distribución interna con su firma final. El AAB no se publicó.

## Archivos entregados

- Debug: `build/app/outputs/flutter-apk/FloatingVolume-0.0.13-debug-build14.apk`.
- SHA-256 debug: `21B5E7C2A8C96DDB3B4F4E4AC8C806D555C4D8AD415D2AF24AB974A71BB4F880`.
- AAB: `build/app/outputs/bundle/release/FloatingVolume-0.0.13-build14.aab`.
- SHA-256 AAB: `38AC6DD67D4F9E77C20CE4819FA75BB5F0D855B71B4F281504992C028874A520`.
- Tamaño AAB: 59,348,746 bytes.
- Mapa: `build/app/outputs/bundle/release/FloatingVolume-0.0.13-build14-mapping.txt`.
- Notas en 11 idiomas: `docs/RELEASE_0.0.13.md`, todas inferiores a 500 caracteres.

Siguiente comprobación antes de producción: confirmar que código 14 esté libre, subir a prueba interna y verificar una actualización de Play con ajustes no predeterminados. No borrar datos ni desinstalar para esa comprobación.
