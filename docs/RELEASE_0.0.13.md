# Floating Volume 0.0.13 (14)

Nombre de versión en Google Play: `0.0.13`.
Código de versión: `14`. Confirmar que no esté ocupado en otra pista de Play antes de subirlo. Se mantiene separado del AAB anterior, 0.0.12 (13).

## Notas para Google Play

Cada idioma tiene menos de 500 caracteres. Estas notas incluyen la corrección de ajustes y las mejoras de robustez que ya contenía el paquete anterior.

```text
<en-US>
Fixed settings synchronization so sliders show saved values instead of defaults. Improved preference preservation, section resets, and timing labels. Also includes reliability improvements for floating controls and background service startup.
</en-US>
<ar>
أصلحنا مزامنة الإعدادات لتعرض أشرطة التمرير القيم المحفوظة بدلًا من القيم الافتراضية. حسّنا الحفاظ على التفضيلات وإعادة ضبط الأقسام وعرض المدد، بالإضافة إلى موثوقية عناصر التحكم العائمة وبدء الخدمة في الخلفية.
</ar>
<cs-CZ>
Opravili jsme synchronizaci nastavení, aby posuvníky zobrazovaly uložené hodnoty místo výchozích. Vylepšili jsme zachování předvoleb, obnovení jednotlivých sekcí a zobrazení časů i spolehlivost plovoucích ovladačů a spouštění služby na pozadí.
</cs-CZ>
<da-DK>
Vi har rettet synkroniseringen af indstillinger, så skyderne viser gemte værdier frem for standardværdier. Vi har forbedret bevarelsen af indstillinger, nulstilling af sektioner og tidsangivelser samt de flydende knappers pålidelighed og opstart af baggrundstjenesten.
</da-DK>
<de-DE>
Die Synchronisierung der Einstellungen wurde korrigiert: Regler zeigen jetzt gespeicherte statt voreingestellter Werte. Verbesserungen beim Beibehalten von Einstellungen, Zurücksetzen einzelner Bereiche und Anzeigen von Zeiten sowie bei schwebenden Steuerelementen und dem Start des Hintergrunddienstes.
</de-DE>
<es-419>
Corregimos la sincronización para que los controles muestren los valores guardados, incluido el paso de volumen por toque. Mejoramos la conservación de preferencias, la restauración por sección y los tiempos mostrados. Incluye mejoras de confiabilidad de los controles flotantes y del inicio del servicio.
</es-419>
<fi-FI>
Korjasimme asetusten synkronoinnin: liukusäätimet näyttävät tallennetut arvot oletusarvojen sijaan. Paransimme asetusten säilymistä, osioiden palautusta ja aikojen esitystä sekä kelluvien säätimien luotettavuutta ja taustapalvelun käynnistystä.
</fi-FI>
<fr-FR>
La synchronisation des réglages a été corrigée : les curseurs affichent les valeurs enregistrées plutôt que les valeurs par défaut. Meilleure conservation des préférences, réinitialisation par section et affichage des durées, avec des améliorations de fiabilité des commandes flottantes et du démarrage du service.
</fr-FR>
<it-IT>
Corretta la sincronizzazione delle impostazioni: i cursori mostrano i valori salvati invece di quelli predefiniti. Migliorati la conservazione delle preferenze, il ripristino delle singole sezioni e la visualizzazione dei tempi, oltre all’affidabilità dei controlli mobili e all’avvio del servizio in background.
</it-IT>
<sk>
Opravili sme synchronizáciu nastavení, aby posuvníky zobrazovali uložené hodnoty namiesto predvolených. Zlepšili sme zachovanie predvolieb, obnovenie jednotlivých sekcií a zobrazenie časov aj spoľahlivosť plávajúcich ovládačov a spúšťanie služby na pozadí.
</sk>
<sv-SE>
Vi har rättat synkroniseringen av inställningar så att reglagen visar sparade värden i stället för standardvärden. Förbättrad bevaring av inställningar, återställning per avsnitt och tidsvisning samt bättre tillförlitlighet för de flytande kontrollerna och bakgrundstjänstens start.
</sv-SE>
```

## Alcance

Android pasa a ser la fuente de los 25 ajustes del overlay. La interfaz no vuelve a enviar sus predeterminados durante el arranque. Las escrituras se confirman con una instantánea completa, se ordenan con las lecturas y los cambios del mezclador nativo actualizan la interfaz. La migración respeta las claves nativas existentes y solo importa las antiguas claves Flutter cuando falta su equivalente nativo.

Se conserva el redondeo por estilo. El estilo interno obsoleto CARDS, no disponible en el catálogo Flutter, se normaliza al estilo Android; los ordinales de los demás diseños conservan su correspondencia Kotlin, incluida la posición de Glacier.

Las restauraciones por sección son agrupadas. Se muestran segundos sin truncamiento y unidades dp para geometría. Los valores válidos históricos del tiempo de ocultamiento automático se conservan hasta 30 s.

Estas pruebas no certifican los firmware Vivo/Huawei ni dan por resueltos sus fallos de biblioteca nativa o superficie de renderizado. La actualización desde una instalación de Play debe comprobarse en prueba interna con la firma de distribución antes de producción. No se ha publicado automáticamente.

## Paquete verificado

- AAB: `build/app/outputs/bundle/release/FloatingVolume-0.0.13-build14.aab`, 59,348,746 bytes.
- SHA-256: `38AC6DD67D4F9E77C20CE4819FA75BB5F0D855B71B4F281504992C028874A520`.
- Paquete `com.fixbyte.floatingvolume`, versión `0.0.13`, código `14`, minSdk `24`, targetSdk `36`.
- Certificado SHA-256: `B5:58:3C:01:0C:D9:78:0D:56:77:FD:AC:3F:62:B7:7C:BF:B7:EC:36:9A:39:D9:B1:92:E8:CF:EC:F1:1A:2F:26`, igual al paquete anterior.
- `jarsigner` verifica la firma y `bundletool validate` aprueba la estructura. Jarsigner también avisa de certificado autofirmado, falta de sello temporal y orden de entradas del manifiesto al leer con JarInputStream; la misma advertencia de orden aparece en el AAB 0.0.12 (13). La validación final de subida de Google Play sigue pendiente.
- Contiene `libflutter.so` para ARM64, ARMv7 y x86_64. Esto no certifica el split concreto que recibió un Vivo.
- Mapa R8: `build/app/outputs/bundle/release/FloatingVolume-0.0.13-build14-mapping.txt`; coincide con `proguard.map` incorporado en el AAB. También se conservó por separado el mapa previo del código 13 antes de compilar.
- 38 pruebas Flutter y 15 Kotlin aprobadas; análisis sin incidencias. API 27: tres reinstalaciones, restauración y 12 comprobaciones reales de volumen aprobadas. Samsung: debug actualizado sin cambiar sus preferencias previas. Detalles en `SETTINGS_SYNC_VERIFICATION.md`.
- Gradle/Kotlin emiten avisos de compatibilidad futura y APIs obsoletas; no impidieron las compilaciones ni las pruebas.
