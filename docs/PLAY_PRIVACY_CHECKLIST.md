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
