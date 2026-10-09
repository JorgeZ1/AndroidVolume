# Floating Volume 0.0.10 (11)

Nombre en Play Console: `0.0.10`.
Código de versión: `11` (confirmar que no se haya usado ya en Play Console).

## Notas para Google Play

```text
<es-419>
• Nuevo formulario para reportar problemas desde el encabezado, con hasta dos imágenes opcionales.
• Mejoras en la posición de la barra de volumen al girar la pantalla, para evitar superposiciones.
• Mejoras en la lectura del volumen y en los mensajes de validación y envío de reportes.
</es-419>
<en-US>
• New problem reporting form in the header, with up to two optional images.
• Improved volume indicator positioning when rotating the screen to prevent overlap.
• Improved volume readback and report validation and submission messages.
</en-US>
```

## Comprobaciones y pendientes

26 pruebas Flutter aprobadas y análisis sin incidencias tras incrementar versión.
Bundle release generado (58,030,593 bytes); firma verificada y certificado igual
al del bundle anterior. Jarsigner muestra avisos de certificado autofirmado/sin
timestamp y lectura streaming del manifiesto, pero confirma `jar verified`.
Arquitecturas: arm64-v8a, armeabi-v7a, x86_64; minSdk 24 y targetSdk 36.
Archivo: `build/app/outputs/bundle/release/FloatingVolume-0.0.10-build11.aab`.
SHA-256: `3A8D9243587B8488BF0A4A2EDB41447BE0A2A6A0777DA71D97AE1FD99C08546E`.
Geometría y volumen
fuera de la app comprobados en Samsung Android 16. No afirmar que se resolvió
el fallo de audio específico de realme GT Neo sin una prueba en ese dispositivo.

Antes de publicar: actualizar política web canónica y Seguridad de los datos en
Play Console para reportes, imágenes seleccionadas y diagnóstico voluntario.
Subir primero a prueba interna/cerrada y comprobar actualización desde Play.
No se realiza publicación automática ni push/commit en esta preparación.
