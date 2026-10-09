# Floating Volume 0.0.12 (13)

Nombre de versión propuesto en Google Play: `0.0.12`.
Código de versión: `13`. Confirma en Play Console que no se haya usado ya este código antes de subir el paquete.

## Notas para Google Play

Pega el bloque completo en las notas de la versión. Cada idioma usa menos de 500 caracteres.

```text
<en-US>
Improved the reliability of floating controls when starting, stopping, and restoring the service. Strengthened overlay window handling and technical diagnostics to help identify stability issues.
</en-US>
<ar>
حسّنا موثوقية عناصر التحكم العائمة عند بدء الخدمة وإيقافها واستعادتها. وعزّزنا التعامل مع النوافذ العائمة والتشخيصات التقنية للمساعدة في تحديد مشكلات الاستقرار.
</ar>
<cs-CZ>
Zvýšili jsme spolehlivost plovoucích ovládacích prvků při spouštění, zastavování a obnovování služby. Vylepšili jsme práci s překryvnými okny a technickou diagnostiku, abychom snáze odhalili problémy se stabilitou.
</cs-CZ>
<da-DK>
Vi har forbedret de flydende betjeningsknappers pålidelighed, når tjenesten startes, stoppes og gendannes. Håndteringen af overlay-vinduer og den tekniske diagnosticering er styrket for bedre at kunne finde stabilitetsproblemer.
</da-DK>
<de-DE>
Die Zuverlässigkeit der schwebenden Steuerelemente beim Starten, Stoppen und Wiederherstellen des Dienstes wurde verbessert. Außerdem wurden die Behandlung von Overlay-Fenstern und die technische Diagnose zur Erkennung von Stabilitätsproblemen optimiert.
</de-DE>
<es-419>
Mejoramos la confiabilidad de los controles flotantes al iniciar, detener y restaurar el servicio. Reforzamos el manejo de ventanas superpuestas y los diagnósticos técnicos para detectar problemas de estabilidad.
</es-419>
<fi-FI>
Paransimme kelluvien säätimien luotettavuutta palvelun käynnistyksen, pysäytyksen ja palautuksen yhteydessä. Paransimme myös peiteikkunoiden käsittelyä ja teknistä diagnostiikkaa vakausongelmien tunnistamiseksi.
</fi-FI>
<fr-FR>
La fiabilité des commandes flottantes a été améliorée lors du démarrage, de l’arrêt et du rétablissement du service. La gestion des fenêtres superposées et les diagnostics techniques ont également été renforcés pour mieux repérer les problèmes de stabilité.
</fr-FR>
<it-IT>
Abbiamo migliorato l’affidabilità dei controlli mobili durante l’avvio, l’arresto e il ripristino del servizio. Abbiamo inoltre rafforzato la gestione delle finestre sovrapposte e la diagnostica tecnica per individuare meglio i problemi di stabilità.
</it-IT>
<sk>
Zlepšili sme spoľahlivosť plávajúcich ovládacích prvkov pri spustení, zastavení a obnovení služby. Vylepšili sme správu prekryvných okien a technickú diagnostiku, aby sa problémy so stabilitou dali ľahšie odhaliť.
</sk>
<sv-SE>
Vi har förbättrat de flytande kontrollernas tillförlitlighet när tjänsten startas, stoppas och återställs. Hanteringen av överläggsfönster och den tekniska diagnostiken har också stärkts för att lättare upptäcka stabilitetsproblem.
</sv-SE>
```

## Alcance y cautelas

Este paquete incorpora cambios de robustez en el ciclo de vida del servicio en primer plano y el manejo de ventanas superpuestas, además de diagnósticos técnicos. Las notas no afirman que se hayan resuelto definitivamente fallos específicos de fabricantes ni que todos los modelos Android estén certificados.

La matriz actual sigue teniendo límites importantes: en API 27, los ciclos que esperan la confirmación del servicio pasaron, pero una cancelación externa antes de que Android entregue el callback todavía reprodujo `RemoteServiceException`; en API 25 se capturaron intentos de añadir una ventana duplicada, sin cierre fatal y con el overlay recuperado; API 30/32 no pudieron certificarse por límites de automatización/RAM y API 35/36/37 siguen pendientes. El fallo `Could not find libflutter.so` del Vivo S1 y el `drawRenderNode called on a context with no surface` de Huawei no se reprodujeron en su hardware. El AAB sí incluye `libflutter.so` para `arm64-v8a`, `armeabi-v7a` y `x86_64`, pero eso no valida los splits que Play entregó a esos teléfonos.

Recomendación: usar primero una prueba interna/cerrada de Play; no presentar este AAB como una verificación completa de compatibilidad ni como solución confirmada de esos dos fallos específicos. Comprobar arranque, controles flotantes, volumen y recepción de informes de Crashlytics/Performance en Firebase de producción. Este artefacto no se publica automáticamente.

## Verificación del paquete

- AAB: `build/app/outputs/bundle/release/FloatingVolume-0.0.12-build13.aab`.
- Tamaño: 59,344,903 bytes (56.6 MiB).
- SHA-256: `0DEAA85E910BCE3B696A2DFEBC2F960FB83EF8B088435587A0893D671C77EEA4`.
- Firma: verificada (`jarsigner -verify`); certificado SHA-256 `B5:58:3C:01:0C:D9:78:0D:56:77:FD:AC:3F:62:B7:7C:BF:B7:EC:36:9A:39:D9:B1:92:E8:CF:EC:F1:1A:2F:26`, idéntico al AAB 0.0.11 (código 12).
- Metadatos del manifiesto: paquete `com.fixbyte.floatingvolume`, versión `0.0.12`, código `13`, minSdk `24`, targetSdk `36`.
- 30 pruebas Flutter aprobadas; `flutter analyze` sin incidencias; `:app:testDebugUnitTest` completado correctamente.
- Mapa R8 generado en `build/app/outputs/mapping/release/mapping.txt`; conservarlo para investigar fallos de esta compilación.
- Gradle muestra avisos no bloqueantes de compatibilidad futura con la versión actual de Gradle 8.13 y Kotlin 2.1.0.

La firma es válida. `jarsigner` también advierte que el certificado de carga es autofirmado y que no tiene sello de tiempo; la misma huella se usó en el AAB anterior. Google Play gestiona la firma final de la app al distribuirla.
