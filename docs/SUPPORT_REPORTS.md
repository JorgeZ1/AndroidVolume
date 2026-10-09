# Reportes de soporte

Proyecto exclusivo: `clxclwegjkqvveuyzmaf` / `floating-volume-reports`, us-east-1.
Acceso en header en inglés/español, incluso antes de conceder permisos flotantes.
Tipos: volumen, posición/giro, apariencia, anuncios/recompensas, cierre/bloqueo, otro.
Descripción de 10–2000 caracteres; imágenes opcionales JPG/PNG, máximo dos de 2 MB.
Envío manual con consentimiento; sin cuenta ni acceso amplio a la galería/cámara.
Datos técnicos: fabricante/modelo, SDK Android, versión y código de app.

## Recepción y seguridad

`submit-report` verifica JWT de proyecto mediante el gateway. El JWT anon que
lleva la app es público, NO autentica una persona: el endpoint es de recepción
anónima. Nunca da acceso de lectura a reportes ni archivos. Claves secretas solo
en el servidor. Tablas con RLS, privilegios exclusivamente service_role, bucket
privado y ninguna política pública de Storage. Se validan número/tamaño/firma
de imágenes y límite del cuerpo incluso con transferencia chunked.
Reserva transaccional de reporte con UUID/hash evita duplicados en reintentos.
Hasta 100 nuevos reportes/día globales para limitar abuso. No es defensa completa
contra bots; evaluar CAPTCHA/App Check y cuotas por origen antes de ampliar tráfico.
Si hay fallo de carga, un reporte pending permite reintentar sin duplicar archivos.

## Administración

En Supabase → Table Editor → `support_reports`: revisar status `new`, categoría,
descripción, diagnostics y attachment_paths. En Storage → `report-images`:
abrir la carpeta con el UUID del reporte para ver las imágenes privadas.
Estados de trabajo: `new`, `in_progress`, `resolved`; `pending` no completó envío.
No se creó panel administrativo público ni se incluyen credenciales admin en app.
Revisar almacenamiento del plan gratuito; eliminar adjuntos y filas cuando ya no
se necesiten, y atender solicitudes de eliminación con el UUID enviado al usuario.
Para borrar, eliminar primero objetos del bucket mediante Storage y después fila.

## Prueba real

`scripts/test_reports.ps1` crea dos PNG sintéticos, los envía, reintenta el mismo
reporte y verifica rechazo de tres imágenes y denegación de lecturas públicas.
Reporte verificado: `1f75eba0-1195-4e4f-8261-1b3f978c6d5d`, status `new`, dos PNG
de 5350 y 5410 bytes en Storage. Sin capturas personales. Se conserva para revisión.
La prueba se hizo por HTTP contra el backend; no acredita selección en teléfono.
Debug compilado e instalado en Samsung Android 16. Icono del header y campos del
formulario en español comprobados mediante árbol de accesibilidad. La selección
de imágenes/envío en el teléfono quedó pendiente al cambiar a otra aplicación.
Pruebas automatizadas cubren límite de previews, eliminación, pantalla estrecha,
serialización, UUID, fallos y reintento: 21 pruebas Flutter aprobadas, análisis
sin incidencias. Asesor de seguridad de Supabase sin avisos tras configurar
políticas explícitas exclusivamente service_role. Sin JWT: 401; reutilización
del UUID con contenido distinto: 409. Sin AAB ni cambio de versión.

Corrección de acceso al envío: botón fijo fuera del formulario desplazable,
SafeArea para navegación inferior y desplazamiento sobre el teclado, con altura
mínima táctil de 48 dp. 23 pruebas Flutter aprobadas tras añadir pruebas de ambos
insets; análisis sin incidencias. El consentimiento y la descripción obligatoria
se mantienen, no se envía automáticamente al abrir el formulario.

Selección múltiple: `pickMultiImage` con límite igual a los espacios restantes;
se pueden elegir dos imágenes en una apertura. Se mantiene el límite de dos
en app y servidor, y se permite enviar cero imágenes. Descripción mínima de
10 caracteres: helper, aviso visible y desplazamiento al campo si no valida.
Los fallos de envío se muestran también con SnackBar, conservando el borrador.

Último debug instalado con selección múltiple y footer seguro. En Samsung, el
botón se midió [80,2688][1360,2880], por encima de la navegación que empieza a
2928 px. Se abrió el selector nativo; no se seleccionaron imágenes personales.
26 pruebas Flutter aprobadas y análisis sin incidencias.

## Antes de publicar

La política dentro de la app y `docs/privacy-policy.html` fueron actualizadas.
Falta publicar el HTML revisado en el sitio canónico y revisar Seguridad de los
datos en Play Console: soporte voluntario, imágenes/otros contenidos del usuario,
información técnica y metadatos de infraestructura según tratamiento real.
No subir producción hasta reflejar este cambio de recopilación.
No se cambia 0.0.9+10 ni se genera AAB en esta implementación.
