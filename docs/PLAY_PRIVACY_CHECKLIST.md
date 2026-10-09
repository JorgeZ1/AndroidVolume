# Checklist de privacidad para Google Play

## URL y ficha

- Usar `https://www.fixbitsolutions.com/privacy/floating-volume/` en **Contenido de la app → Política de privacidad**.
- Confirmar que la ficha declara **Contiene anuncios**.
- Verificar la URL en incógnito y desde un teléfono: HTTPS, HTTP 200, sin inicio de sesión.

## Seguridad de los datos

Validar las respuestas contra la versión del SDK incluida en el AAB. Por el uso de Google Mobile Ads SDK deben revisarse, como mínimo:

- ubicación aproximada derivada de IP;
- actividad/interacciones de la aplicación;
- información y rendimiento/diagnósticos de la aplicación;
- identificadores del dispositivo u otros identificadores;
- finalidades de publicidad o marketing, analítica y prevención del fraude;
- cifrado de datos en tránsito;
- tratamiento/compartición por Google y proveedores aplicables.

La respuesta exacta en Play Console depende de la configuración vigente de AdMob y no debe copiarse sin comprobarla.

## AdMob y consentimiento

- Crear y publicar el mensaje de regulaciones europeas en **AdMob → Privacidad y mensajes**.
- Configurar los mensajes regionales adicionales que correspondan al público distribuido.
- Confirmar que UMP consulta el estado al iniciar y que no solicita anuncios antes de `canRequestAds()`.
- Probar consentimiento y revocación con dispositivo de prueba y geografía EEE.
- Mantener IDs de prueba en debug e IDs reales exclusivamente en release.

## Coherencia final

- Política web, texto interno, ficha, permisos y Seguridad de los datos deben describir el mismo comportamiento.
- Revisar el SDK de anuncios y esta declaración en cada actualización.
- Conservar fecha, copia del HTML publicado y capturas de las declaraciones enviadas.

## Actualización del 4 de octubre de 2026: reportes y Firebase

- Política canónica bilingüe: `https://www.fixbitsolutions.com/privacy/floating-volume/`.
- Crashlytics: **Registros de fallas**, recopilados, no efímeros, necesarios, finalidad **Estadísticas**. No marcar compartidos solo por enviar a Firebase como proveedor que procesa por cuenta del desarrollador.
- Performance Monitoring y contexto técnico: **Diagnósticos**, recopilados, no efímeros, necesarios, finalidad **Estadísticas**. Mantener además las finalidades y el uso compartido que ya correspondan a AdMob en esta misma categoría.
- **Dispositivo u otros IDs**: incluir los identificadores de instalación de Firebase, además de los identificadores de AdMob. Mantener la declaración de compartidos por AdMob y añadir Estadísticas para Firebase.
- **Ubicación aproximada**: la IP puede usarse para país/ubicación general en Firebase y AdMob; no declarar GPS preciso si no se recopila. Conservar publicidad/medición de AdMob y Estadísticas donde corresponda.
- **Fotos** y **Otro contenido generado por usuarios**: reportes voluntarios, recopilados, no efímeros, opcionales; funciones de la app y estadísticas para investigar problemas. Supabase almacena por cuenta del desarrollador y no implica por sí solo marcar compartidos.
- **Otros datos de rendimiento de apps** no debe marcarse únicamente por el nombre Performance Monitoring: tiempos, latencia, energía y diagnósticos técnicos corresponden a Diagnósticos. Seleccionar la categoría residual solo si hay datos adicionales no cubiertos.
- Todos los canales descritos usan HTTPS/TLS. No hay creación ni acceso mediante cuentas de usuario.
- Hay solicitud de eliminación de reportes por correo con referencia. No declarar borrado automático de todos los datos en 90 días: no está implementado para reportes.
- Revisar vista previa, guardar y enviar cambios desde Descripción general de publicación. Si hay publicación administrada, publicar después de aprobación.
- La política y Seguridad de los datos pueden actualizarse sin generar AAB. Para distribuir Firebase a usuarios sí hace falta un AAB nuevo con los SDK; el AAB anterior no los contiene.

Referencias: [Firebase: divulgación de datos Android](https://firebase.google.com/docs/android/play-data-disclosure), [definiciones de Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=es-419).
