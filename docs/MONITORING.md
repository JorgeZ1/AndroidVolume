# Monitoreo técnico — 4 de octubre de 2026

Firebase: `floating-volume`. El archivo Android contiene clientes de producción
`com.fixbyte.floatingvolume` y debug `com.fixbyte.floatingvolume.debug`.
El plugin Google Services selecciona el cliente por applicationId; no se reutiliza
el registro de producción para debug. No hay Google Analytics ni sesión grabada.

## Implementación

- Crashlytics: excepciones Android, errores Flutter y asíncronos de Dart.
- Errores de framework Flutter se clasifican no fatales; errores Dart no manejados, fatales.
- Contexto Android: estilo, orientación, servicio, ocultamiento, indicador nativo
  y volumen anterior/solicitado/obtenido/confirmado.
- Eventos: creación/destrucción, menú auxiliar, anuncio recompensado y primera pantalla.
- Errores recuperados: permisos de volumen, tokens de ventanas y separación durante snap.
  Se limita cada categoría recuperada a una por minuto. No se vuelve a lanzar el error.
- Performance: mediciones automáticas Android/red, `flutter_first_frame`
  (desde inicialización del monitoreo, no desde proceso), `native_volume_request`
  y `support_report_submit` (solo duración/resultado, no contenido del reporte).
- No se registran descripciones, imágenes, tokens, IDs publicitarios ni texto de otras apps.
  Excepciones reportadas manualmente conservan clase/pila, no el mensaje arbitrario.
  Los crashes automáticos del SDK pueden incluir mensajes del sistema; no equivalen
  a anonimización absoluta. No se asigna userId.

## Prueba segura

En builds normales debug la recopilación está desactivada. Para eventos sintéticos:

```powershell
flutter build apk --debug --dart-define=MONITORING_DEBUG=true --dart-define=MONITORING_SELF_TEST=true
```

Al abrir esta variante registra una excepción no fatal Dart y una no fatal Kotlin,
y trazas de primera pantalla/autoprueba. No provoca un cierre ni un ANR artificial.
Seleccionar **Floating Volume Debug** en Firebase Crashlytics y Performance.
La recepción se debe comprobar en el panel: compilar o ver logcat no la demuestra.
Un crash fatal nativo requiere una prueba separada autorizada en un dispositivo libre.
Después de probar, reinstalar debug normal para no dejar autopruebas en cada apertura.

Producción recopila automáticamente. No hay opt-out general implementado.
Firebase no reemplaza Android vitals y no garantiza explicar todo ANR.
La primera instalación se realiza sin inicialización web ni CLI: Android configura
Firebase desde recursos Google Services y Dart usa Firebase.initializeApp().

## Antes de publicar

1. Verificar eventos reales debug en Firebase y habilitar alertas del proyecto.
2. Publicar la política web local actualizada (NO se publica automáticamente).
3. Revisar Seguridad de los datos: ahora sí hay registros de fallas, diagnósticos e
   IDs de instalación. La recopilación técnica de producción no es opcional.
   Evaluar fines y excepción de proveedor de servicios, no confundirlos con AdMob.
4. Verificar carga de mapping R8 durante una compilación release y conservarlo.
   Si en el futuro se ofusca Dart, subir también sus símbolos con Firebase CLI.
5. Probar profile en dispositivos reales para CPU/memoria/frames; los traces Firebase
   no equivalen a un perfil continuo de Flutter ni miden toda su fluidez visual.
6. Publicar escalonadamente y monitorizar nuevas fallas y ANR por versión.

Sin AAB, publicación, cambios de alertas remotas ni autenticación Firebase CLI automática.

## Verificación local

- 30 pruebas Flutter aprobadas, incluidas privacidad del mensaje de error y
  preservación de resultado/excepción de las operaciones medidas.
- `flutter analyze`: sin avisos.
- 7 pruebas Kotlin de colocación del indicador aprobadas, sin fallos.
- Compilación debug con ambos SDK Android/Dart: aprobada.
- Configuración Android release procesada sin generar AAB: selecciona app Firebase
  `1:640819350940:android:8ea6b128bf1f9ce1b14c59`.
- Debug selecciona `1:640819350940:android:8d0023a18735b3f2b14c59`.
- Android mínimo sigue en SDK 24 y objetivo SDK 36.
- Prueba física en Samsung SM-S926W: instalación correcta, apertura/reapertura
  sin cierre, excepción sintética Dart y Kotlin registradas.
- Logcat del proceso debug confirma HTTP 200 de
  `crashlyticsreports-pa.googleapis.com` y `firebaselogging-pa.googleapis.com`.
  Confirma aceptación de envíos, no validación visual de todos los campos en el panel.
- El usuario confirmó que aparecen eventos en el panel de **Debug**. El panel de
  producción aún pide SDK: no se ha ejecutado/distribuido esta integración en release.
- Pendientes: verificar las trazas en Performance, configurar alertas y publicar la
  política web. No se provocó ningún crash fatal.
- Tras autopruebas, usar debug con `MONITORING_DEBUG=true` pero sin
  `MONITORING_SELF_TEST`: registra fallas reales sin autopruebas en cada apertura.
