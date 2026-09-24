# Inventario de privacidad — Floating Volume

Actualizado: 13 de septiembre de 2026

## Alcance

- Aplicación: Floating Volume
- Paquete: `com.fixbyte.floatingvolume`
- Responsable publicado: FixBit Solutions
- Contacto: `fixbyte3@gmail.com`
- Política canónica: `https://www.fixbitsolutions.com/privacy/floating-volume/`

## Datos y tratamiento

| Dato o capacidad | Origen | Destino | Finalidad | Conservación/control |
|---|---|---|---|---|
| Estilo, tamaño, opacidad, posición y ajustes | Usuario/app | Solo dispositivo (`SharedPreferences`) | Personalización y funcionamiento | Hasta restablecer, borrar datos o desinstalar |
| Vencimiento individual por estilo especial | Recompensa de anuncio | Solo dispositivo (`SharedPreferences`) | Mantener el estilo seleccionado durante 24 horas acumulables por anuncio | Hasta vencer, restablecer, borrar datos o desinstalar |
| Niveles de volumen | Android `AudioManager` | Procesamiento local | Mostrar y modificar canales de audio | No se crea historial propio |
| Dirección IP / ubicación general estimada | Google Mobile Ads SDK | Google y proveedores publicitarios aplicables | Publicidad, medición, análisis y fraude | Conforme a políticas de Google |
| Aperturas, toques y vistas de video | Google Mobile Ads SDK | Google y proveedores aplicables | Publicidad, medición y análisis | Conforme a políticas de Google |
| Diagnósticos, rendimiento y uso de energía | Google Mobile Ads SDK | Google | Funcionamiento, análisis y fraude | Conforme a políticas de Google |
| ID de publicidad, App Set ID y otros identificadores aplicables | Android / Google Mobile Ads SDK | Google y proveedores aplicables | Publicidad, medición y fraude | Controlable mediante UMP/Android según región y modalidad |

Google declara que los datos transmitidos automáticamente por Mobile Ads SDK se cifran en tránsito mediante TLS. Floating Volume no tiene cuenta de usuario ni backend propio.

## Permisos revisados

- `SYSTEM_ALERT_WINDOW`: controles sobre otras apps.
- `MODIFY_AUDIO_SETTINGS`: lectura/cambio local de volumen.
- `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_SPECIAL_USE`: servicio visible iniciado por el usuario.
- `POST_NOTIFICATIONS`: notificación del servicio.
- `RECEIVE_BOOT_COMPLETED`: restaurar un servicio previamente habilitado.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: continuidad opcional.
- `KILL_BACKGROUND_PROCESSES`: reinicio técnico del servicio; no lee datos de otras apps.
- `INTERNET` y `AD_ID`: AdMob.

No se declara `FOREGROUND_SERVICE_MEDIA_PLAYBACK` y la app no reproduce, graba ni transmite audio.

## Revisión obligatoria antes de cada publicación

Repetir este inventario si se añade analítica, Crashlytics, inicio de sesión, compras, nube, nuevos SDK publicitarios o permisos. Cualquier cambio debe reflejarse simultáneamente en la política web, la política dentro de la app y Seguridad de los datos de Google Play.
