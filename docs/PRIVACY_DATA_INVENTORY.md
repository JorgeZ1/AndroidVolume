# Inventario de privacidad — Floating Volume

Actualizado: 4 de octubre de 2026

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
| Vencimiento individual por estilo especial | Recompensa de anuncio | Solo dispositivo (`SharedPreferences`) | Mantener el estilo seleccionado durante 72 horas acumulables por anuncio | Hasta vencer, restablecer, borrar datos o desinstalar |
| Estilo especial gratuito destacado y vencimiento | Rotación local aleatoria | Solo dispositivo (`SharedPreferences`) | Ofrecer un estilo especial gratis por ciclo de 72 horas | Se reemplaza al iniciar un ciclo nuevo; borrar datos o desinstalar también lo reinicia |
| Niveles de volumen | Android `AudioManager` | Local; contexto técnico limitado en Crashlytics | Mostrar/modificar canales y diagnosticar solicitudes ignoradas | Último estado técnico, no historial de audio |
| Fallas, trazas de pila y contexto técnico limitado | Flutter/Android y Crashlytics | Firebase de Google | Diagnóstico y corrección de errores | Según retención del proveedor; automático en producción, debug solo por opt-in técnico |
| Tiempos, metadatos de red e identificadores de instalación | Firebase Performance/Crashlytics | Firebase de Google | Rendimiento y diagnóstico | Según políticas del proveedor; sin Google Analytics ni captura de pantallas |
| Tipo de error, descripción e imágenes seleccionadas (máximo 2) | Envío voluntario con consentimiento | Supabase, us-east-1, tablas/Storage privados | Investigar errores | Eliminación por soporte o solicitud usando referencia del reporte |
| Fabricante/modelo, SDK Android y versión de app | Envío voluntario con reporte | Supabase | Diagnóstico de compatibilidad | Igual que el reporte; sin ID de publicidad/identificador de dispositivo |
| Metadatos de conexión (p. ej. IP) | Infraestructura HTTP | Supabase | Operación y seguridad de infraestructura | Según registros/retención del proveedor; no se guardan en la tabla de reportes |
| Dirección IP / ubicación general estimada | Google Mobile Ads SDK | Google y proveedores publicitarios aplicables | Publicidad, medición, análisis y fraude | Conforme a políticas de Google |
| Aperturas, toques y vistas de video | Google Mobile Ads SDK | Google y proveedores aplicables | Publicidad, medición y análisis | Conforme a políticas de Google |
| Diagnósticos, rendimiento y uso de energía | Google Mobile Ads SDK | Google | Funcionamiento, análisis y fraude | Conforme a políticas de Google |
| ID de publicidad, App Set ID y otros identificadores aplicables | Android / Google Mobile Ads SDK | Google y proveedores aplicables | Publicidad, medición y fraude | Controlable mediante UMP/Android según región y modalidad |

Google declara que los datos transmitidos automáticamente por Mobile Ads SDK se cifran en tránsito mediante TLS. Floating Volume no requiere cuenta de usuario. Existe un backend de soporte en Supabase para reportes voluntarios, también mediante HTTPS.

## Permisos revisados

- `SYSTEM_ALERT_WINDOW`: controles sobre otras apps.
- `MODIFY_AUDIO_SETTINGS`: lectura/cambio local de volumen.
- `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_SPECIAL_USE`: servicio visible iniciado por el usuario.
- `POST_NOTIFICATIONS`: notificación del servicio.
- `RECEIVE_BOOT_COMPLETED`: restaurar un servicio previamente habilitado.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: continuidad opcional.
- `KILL_BACKGROUND_PROCESSES`: reinicio técnico del servicio; no lee datos de otras apps.
- `INTERNET`: AdMob y reportes voluntarios. `AD_ID`: AdMob.
- Selector de imágenes del sistema: acceso solo a imágenes elegidas; no se añade permiso amplio de galería ni cámara.

No se declara `FOREGROUND_SERVICE_MEDIA_PLAYBACK` y la app no reproduce, graba ni transmite audio.

## Revisión obligatoria antes de cada publicación

### Ampliación de diagnósticos — 9 de octubre de 2026

Se añade estado de permisos y ciclo de vida, categorías filtradas de errores,
historial técnico en memoria limitado a 30 eventos por capa, contadores de
operación locales al proceso y tiempos de permisos/servicio/ajustes. No se
incorporan cuentas, identificadores propios de usuario, contenido de formularios,
captura de pantallas ni Google Analytics. Las categorías de Play ya declaradas
de registros de fallas, diagnóstico y rendimiento deben revisarse antes de
publicar; no se asume que la ficha de Console se haya actualizado automáticamente.
La copia de política web se actualiza localmente; su despliegue público queda
pendiente de la preparación de la publicación.

Repetir este inventario si se añade analítica, Crashlytics, inicio de sesión, compras, nube, nuevos SDK publicitarios o permisos. Cualquier cambio debe reflejarse simultáneamente en la política web, la política dentro de la app y Seguridad de los datos de Google Play.
