# Compatibilidad de controles flotantes — siguiente actualización

Objetivo: corregir la superposición del indicador al girar y verificar el control
de volumen fuera de la app, conservando ajustes y compatibilidad de 0.0.9 (10).
No cambiar versión ni generar un AAB hasta revisar los resultados.

## Sprint 1 — diagnóstico y referencia

- Conservar las preferencias existentes; no migrar claves ni cambiar minSdk/ABI.
- Registrar canal, volumen previo, solicitado y confirmado por Android.
- Separar recepción del toque, operación de audio y visualización del indicador.
- No introducir una ruta alternativa por marca sin reproducir el fallo.

## Sprint 2 — geometría

- Extraer un cálculo de posición puro, probado sin depender del fabricante.
- Usar límites disponibles con barras del sistema y recortes descontados.
- Medir los botones en coordenadas de pantalla y colocar el indicador en esas
  mismas coordenadas en ambos bordes.
- Mantener el indicador dentro del área segura y fuera del rectángulo de botones.
- Si falta espacio, reducir temporalmente distancia/dimensiones; no persistirlo.
- Durante arrastre/rotación retirar la barra y recalcular cuando termine el anclaje.
- Probar vertical/horizontal, navegación lateral, recortes, tamaños extremos y
  casos sin espacio suficiente.

## Sprint 3 — volumen confirmado

- Conservar setStreamVolume y las protecciones de No molestar existentes.
- Leer el volumen real después de solicitar un cambio, también en el slider.
- Confirmar de nuevo tras un breve plazo, sin reintentar ni duplicar incrementos.
- Actualizar la barra/mezclador con la lectura real y registrar solicitudes que
  Android limite o ignore. No asegurar que una llamada sin excepción cambió volumen.

## Sprint 4 — regresión

- Tests nativos del cálculo geométrico y tests/análisis Flutter.
- Compilar e instalar debug en paralelo a producción, con anuncios de prueba.
- Medir rectángulos reales en el teléfono en ambos bordes y orientaciones.
- Comparar volumen multimedia antes/después dentro de la app y en inicio/otra app.
- Verificar ocultamiento, menú auxiliar, volumen nativo y preferencias conservadas.
- Pendientes externos: realme GT Neo con Android 13, Bluetooth y cobertura física
  de otras versiones Android. Un emulador no acredita comportamiento OEM.

## Sprint 5 — puerta de publicación

- Revisar evidencia y pendientes antes de asignar 0.0.10/código disponible.
- Verificar manifest, firma, catálogo de dispositivos y actualización desde Play
  en prueba interna/cerrada antes de distribuir un AAB en producción.
- Desplegar progresivamente 10/25/50/100% según evidencia suficiente de uso.
- Si hay regresión, detener expansión; quienes actualizaron requieren otra versión.

## Resultados

Verificación local del 2 de octubre de 2026:

- Sprints 1–3 implementados: geometría independiente, áreas seguras y lectura de
  volumen confirmado. El cálculo no modifica las preferencias del usuario.
- 7 tests nativos aprobados, incluida una matriz de 360 combinaciones geométricas.
  14 tests Flutter aprobados; análisis Flutter sin incidencias.
- APK debug compilado e instalado en paralelo a Play en Samsung SM-S926W.
  No se modificaron versión, minSdk, ABIs ni firma de producción.
- Medidos ambos bordes en horizontal y el borde derecho en vertical: separación
  real de 40 px (10 dp), sin intersección y dentro de los límites seguros.
- Tras la última corrección, giro vertical → horizontal → vertical con indicador
  visible: separación y centrado vertical comprobados mediante dumpsys.
- Se corrigió un desfase de actualización de ventana: la medición del indicador
  se pospone tras el anclaje para no utilizar el frame anterior de Android.
- Multimedia confirmado por AudioService dentro de la app, en inicio y en Ajustes
  de Android. En inicio se verificó 11 → 6 → 11; en Ajustes, 6 → 1.
- Preferencias de debug, orientación y volumen inicial restaurados al finalizar.
  La app de Play se conservó intacta. El debug actualizado queda instalado.

Pendientes: reproducir el problema de audio en realme GT Neo/Android 13; probar
Bluetooth, Android antiguos y regresión manual completa de menú/indicador nativo.
Las pruebas Samsung no acreditan una solución del fallo OEM reportado en realme.
El sprint 4 está parcialmente verificado y la puerta de publicación del sprint 5
permanece pendiente. No se generó AAB ni se incrementó la versión.

Repetición sobre el debug con reportes: instalado en Samsung SM-S926W/Android 16.
Volumen desde inicio confirmado de 9 a 4. Geometría derecha en vertical y horizontal,
izquierda en horizontal y al volver a vertical: gap 10 dp, centrado y límites
seguros aprobados por el script. El intento adicional desde Ajustes no mostró
cambio de volumen en esta sesión, por lo que no se considera verificado; el
resultado confirmado fuera de la app corresponde a Inicio. Se restauraron
preferencias, orientación y volumen inicial 9. Realme
GT Neo/Android 13 sigue pendiente: no se afirma corrección OEM sin ese dispositivo.
