# Floating Volume 0.0.11 (12)

Nombre de versión en Google Play: `0.0.11`.
Código de versión: `12`. Confirmar que Play Console no haya recibido otro paquete con este código o uno superior.

## Notas para Google Play

```text
<es-419>
• Incorporamos diagnósticos de errores y métricas de rendimiento para detectar problemas y mejorar la estabilidad.
• Actualizamos la política de privacidad con información sobre diagnósticos y reportes de soporte.
• Conservamos el envío de reportes con hasta dos imágenes opcionales.
</es-419>
<en-US>
• Added crash diagnostics and performance monitoring to help identify issues and improve stability.
• Updated the privacy policy with information about diagnostics and support reports.
• Support reports remain available with up to two optional images.
</en-US>
```

## Alcance y publicación

Firebase Crashlytics y Performance Monitoring habilitados en producción; Google Analytics desactivado. No se incluyen flags de autoprueba ni un error intencionado en release. Los anuncios usan las unidades de producción.

Política bilingüe publicada: https://www.fixbitsolutions.com/privacy/floating-volume/

Antes del lanzamiento: actualizar Seguridad de los datos, subir el AAB a prueba interna y comprobar arranque, controles flotantes, anuncios y reportes desde una instalación distribuida por Play. Verificar recepción de datos en la app Firebase de producción; los eventos de debug no validan el dashboard de producción.

No se afirma una corrección definitiva del problema específico del realme GT Neo sin probar ese dispositivo. Este paquete no se publica automáticamente en Google Play.

## Verificación del paquete

- AAB: `build/app/outputs/bundle/release/FloatingVolume-0.0.11-build12.aab`.
- Tamaño: 59,341,415 bytes.
- SHA-256: `857CF5785CD88D0EA1D6C3407C19439E65358CC58F88F59C36F9659B33ED3F3E`.
- Firma: `jar verified`; certificado idéntico al AAB 0.0.10 (huella SHA-256 `B5:58:3C:01:0C:D9:78:0D:56:77:FD:AC:3F:62:B7:7C:BF:B7:EC:36:9A:39:D9:B1:92:E8:CF:EC:F1:1A:2F:26`). Avisos de certificado autofirmado, falta de timestamp y lectura JarInputStream, también presentes en la versión anterior.
- Paquete `com.fixbyte.floatingvolume`, versión 0.0.11, código 12, minSdk 24, targetSdk 36.
- Arquitecturas: arm64-v8a, armeabi-v7a y x86_64.
- Recursos del AAB contienen exclusivamente el ID Firebase de producción, no el ID de debug.
- Crashlytics y Performance habilitados; Analytics desactivado en el manifiesto release.
- 30 pruebas Flutter aprobadas; `flutter analyze` sin incidencias.
- Verificación nativa `:app:testDebugUnitTest` completada correctamente (7 pruebas de posición del indicador, sin fallas).
- Mapa R8 disponible en `build/app/outputs/mapping/release/mapping.txt`. Conservarlo para diagnóstico de esta compilación.
- Compilación release completada con recuperación automática ante errores de caché incremental Kotlin entre C: y D:. Quedan avisos de próxima actualización de Gradle/Kotlin, no bloqueantes en esta compilación.

Pendiente de validación antes de producción: instalación mediante prueba interna de Google Play y recepción de eventos en Firebase de producción. No sustituir esta comprobación por los eventos sintéticos de la app debug.
