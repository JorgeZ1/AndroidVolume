import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:floating_volume/src/app_language.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'October 9, 2026';
  static const String _publicPolicyUrl =
      'https://www.fixbitsolutions.com/privacy/floating-volume/';
  static const String _privacyEmail =
      'mailto:fixbyte3@gmail.com?subject=Floating%20Volume%20Privacy';
  static const String _googlePrivacyUrl = 'https://policies.google.com/privacy';
  static const String _admobOptOutUrl =
      'https://support.google.com/ads/answer/2662922';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Privacy Policy', 'Política de Privacidad')),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: cs.primary),
                const Gap(8),
                Expanded(
                  child: Text(
                    tr(
                      'Last updated: $_lastUpdated',
                      'Última actualización: 9 de octubre de 2026',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          _Section(
            icon: Icons.info_outline_rounded,
            title: tr('1. Overview', '1. Información general'),
            body: tr(
              'Floating Volume (com.fixbyte.floatingvolume), published by '
                  'FixBit Solutions, is an Android app that displays floating '
                  'volume controls over other apps. This privacy policy describes '
                  'how we handle user information and what data third parties may collect.',
              'Floating Volume (com.fixbyte.floatingvolume), publicada por FixBit Solutions, es una aplicación de Android que muestra controles flotantes de volumen sobre otras aplicaciones. Esta política describe cómo manejamos la información del usuario y qué datos pueden recopilar terceros.',
            ),
          ),

          _Section(
            icon: Icons.lock_outline_rounded,
            title: tr(
              '2. Information stored locally',
              '2. Información almacenada localmente',
            ),
            body: tr(
              'Preferences are stored on the device and are not synchronized '
                  'to a user account. The app does not request:\n\n'
                  '• Names, email addresses, or contact information\n'
                  '• Passwords or account details\n'
                  '• Audio recordings, camera, or microphone access\n'
                  '• Call or message history\n'
                  '• GPS location\n\n'
                  'User preferences (visual style, opacity, position, advanced '
                  'settings, audio channels, and temporary access expiration for '
                  'special styles) are stored only on the device using '
                  'SharedPreferences. This statement does not cover data processed '
                  'by Google AdMob, voluntary reports, or Firebase technical monitoring described below. Limited context such as style and service state can be sent to Firebase; providers can estimate general location from IP addresses.',
              'Las preferencias se guardan en el dispositivo y no se sincronizan con una cuenta. La aplicación no solicita:\n\n'
                  '• Nombres, correos electrónicos ni datos de contacto\n'
                  '• Contraseñas ni datos de cuenta\n'
                  '• Grabaciones de audio ni acceso a cámara o micrófono\n'
                  '• Historial de llamadas ni mensajes\n'
                  '• Ubicación GPS\n\n'
                  'Las preferencias (estilo, opacidad, posición, ajustes avanzados, canales de audio y vencimiento de estilos) se guardan localmente mediante SharedPreferences. Esto no incluye AdMob, reportes voluntarios ni monitoreo técnico descritos abajo. Contexto limitado como estilo y estado del servicio puede enviarse a Firebase; los proveedores pueden estimar la ubicación general mediante IP.',
            ),
          ),

          _Section(
            icon: Icons.bug_report_outlined,
            title: tr(
              '2a. Voluntary support reports',
              '2a. Reportes voluntarios de soporte',
            ),
            body: tr(
              'Only when you choose Send report and consent, we send the error type, description, up to two selected images, app version and basic device information (manufacturer, model and Android version) to Supabase in the US. Reports and images are private and accessed by authorized support staff to investigate errors. No account, advertising ID or automatic screenshot is required. Avoid personal information in attachments. Supabase may process connection metadata such as IP addresses in infrastructure logs. To request deletion, email fixbyte3@gmail.com with your report reference. Data remains until removed by support or following your deletion request.',
              'Solo al elegir Enviar reporte y aceptar, enviamos el tipo de error, descripción, hasta dos imágenes elegidas, versión de la app y datos básicos del dispositivo (fabricante, modelo y versión de Android) a Supabase en Estados Unidos. Los reportes e imágenes son privados y el personal autorizado de soporte accede para investigar errores. No se requiere cuenta, ID de publicidad ni captura automática. Evita información personal en los adjuntos. Supabase puede procesar metadatos de conexión como direcciones IP en registros de infraestructura. Para solicitar eliminación, escribe a fixbyte3@gmail.com con la referencia de tu reporte. Los datos permanecen hasta que soporte los elimine o atienda tu solicitud de eliminación.',
            ),
          ),

          _Section(
            icon: Icons.settings_suggest_outlined,
            title: tr('2b. Technical monitoring', '2b. Monitoreo técnico'),
            body: tr(
              'We use Google Firebase Crashlytics and Performance Monitoring to detect errors and measure performance. Production builds collect crash stack traces, device/app versions, installation identifiers, timing/network metadata and limited technical context (such as style, orientation, permission state and error categories, app lifecycle, bounded technical sequences, window/service state and volume requests). We do not intentionally include report descriptions, selected images, personal identifiers or contents from other apps in this telemetry. These services operate independently of voluntary support reports and ad personalization choices. Data is transmitted encrypted and retained according to Firebase service policies. Google Analytics is not enabled in the app. Contact fixbyte3@gmail.com with privacy questions.',
              'Usamos Google Firebase Crashlytics y Performance Monitoring para detectar errores y medir el rendimiento. Las versiones de producción recopilan seguimientos de pila, versiones de dispositivo/app, identificadores de instalación, tiempos/metadatos de red y contexto técnico limitado (como estilo, orientación, permisos y categorías de error, ciclo de vida, secuencias técnicas limitadas, estado de ventanas/servicio y solicitudes de volumen). No incluimos intencionalmente descripciones de reportes, imágenes seleccionadas, identificadores personales ni contenido de otras apps en esta telemetría. Estos servicios operan independientemente de los reportes voluntarios y de las opciones de personalización de anuncios. Los datos se transmiten cifrados y se conservan según las políticas de Firebase. Google Analytics no está habilitado en la app. Consultas de privacidad: fixbyte3@gmail.com.',
            ),
          ),

          _Section(
            icon: Icons.settings_outlined,
            title: tr('3. System permissions', '3. Permisos del sistema'),
            body: tr(
              'The app requests these permissions to operate:\n\n'
                  '• SYSTEM_ALERT_WINDOW: Displays floating buttons over other '
                  'apps. The app cannot work without this permission.\n\n'
                  '• REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: Keeps the service active '
                  'in the background so the buttons remain available, especially '
                  'on devices with aggressive battery management.\n\n'
                  '• FOREGROUND_SERVICE / FOREGROUND_SERVICE_SPECIAL_USE: Runs the '
                  'floating-button service reliably with a persistent notification.\n\n'
                  '• MODIFY_AUDIO_SETTINGS: Reads and adjusts system volume.\n\n'
                  '• POST_NOTIFICATIONS: Shows the control notification '
                  '(required on Android 13+).\n\n'
                  '• RECEIVE_BOOT_COMPLETED: Restores the service after a restart '
                  'if the user left it enabled.\n\n'
                  '• KILL_BACKGROUND_PROCESSES: Helps apply internal service changes; '
                  'it does not provide access to other apps’ information.\n\n'
                  '• INTERNET: Loads ads, submits voluntary reports, and sends technical monitoring data.',
              'La aplicación solicita estos permisos para funcionar:\n\n'
                  '• SYSTEM_ALERT_WINDOW: Muestra los botones flotantes sobre otras apps. La app no puede funcionar sin este permiso.\n\n'
                  '• REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: Mantiene activo el servicio en segundo plano, especialmente en dispositivos con gestión agresiva de batería.\n\n'
                  '• FOREGROUND_SERVICE / FOREGROUND_SERVICE_SPECIAL_USE: Ejecuta el servicio de botones flotantes con una notificación persistente.\n\n'
                  '• MODIFY_AUDIO_SETTINGS: Lee y ajusta el volumen del sistema.\n\n'
                  '• POST_NOTIFICATIONS: Muestra la notificación de control (requerido en Android 13+).\n\n'
                  '• RECEIVE_BOOT_COMPLETED: Restaura el servicio después de reiniciar si el usuario lo dejó habilitado.\n\n'
                  '• KILL_BACKGROUND_PROCESSES: Ayuda a aplicar cambios internos; no permite acceder a información de otras apps.\n\n'
                  '• INTERNET: Carga anuncios, envía reportes voluntarios y datos de monitoreo técnico.',
            ),
          ),

          _LinkSection(
            icon: Icons.campaign_outlined,
            title: tr(
              '4. Advertising — Google AdMob',
              '4. Publicidad — Google AdMob',
            ),
            body: tr(
              'Floating Volume uses Google AdMob to show a banner on the home '
                  'screen while the app is open and rewarded video ads in the Special '
                  'Styles section. Completing a rewarded ad voluntarily unlocks only '
                  'the selected style for 72 stackable hours. One free special style '
                  'also rotates every 72 hours. A reward is granted only after the '
                  'SDK confirms it was earned.\n\n'
                  'The Google Mobile Ads SDK may collect or share:\n\n'
                  '• IP address to estimate a general location\n'
                  '• Ad or video opens, taps, and views\n'
                  '• Diagnostics, performance, crashes, and energy use\n'
                  '• Advertising ID, App Set ID, and other applicable identifiers\n\n'
                  'Google processes this data for advertising, measurement, analytics, '
                  'and fraud prevention, and states that it is encrypted in transit using TLS.',
              'Floating Volume utiliza Google AdMob para mostrar un banner en la pantalla principal mientras la app está abierta y anuncios recompensados en Estilos Especiales. Al completar voluntariamente un anuncio, se desbloquea solo el estilo elegido por 72 horas acumulables. Un estilo especial gratuito rota cada 72 horas. La recompensa se concede solo cuando el SDK confirma que fue obtenida.\n\n'
                  'Google Mobile Ads SDK puede recopilar o compartir:\n\n'
                  '• Dirección IP para estimar una ubicación general\n'
                  '• Aperturas, toques y visualizaciones de anuncios o videos\n'
                  '• Diagnósticos, rendimiento, fallos y uso de energía\n'
                  '• Identificador de publicidad, App Set ID y otros identificadores aplicables\n\n'
                  'Google procesa estos datos para publicidad, medición, análisis y prevención del fraude, y declara que se cifran en tránsito mediante TLS.',
            ),
            links: [
              _PolicyLink(
                tr('Google Privacy Policy', 'Política de Privacidad de Google'),
                _googlePrivacyUrl,
              ),
              _PolicyLink(
                tr(
                  'Google ad privacy controls',
                  'Controles de privacidad de anuncios de Google',
                ),
                _admobOptOutUrl,
              ),
            ],
          ),

          _LinkSection(
            icon: Icons.gavel_outlined,
            title: tr(
              '5. Consent and ad choices',
              '5. Consentimiento y opciones de anuncios',
            ),
            body: tr(
              'Where applicable law or policy requires it, the app uses Google '
                  'User Messaging Platform (UMP) to ask for privacy choices before '
                  'requesting ads.\n\n'
                  'You can:\n'
                  '• Accept or reject the use of data for personalized advertising\n'
                  '• Withdraw consent at any time\n'
                  '• Review each ad provider’s privacy options\n\n'
                  'Depending on your choice and region, Google may serve personalized, '
                  'non-personalized, limited, or technically eligible ads. Declining '
                  'personalization does not necessarily remove advertising.',
              'Cuando las leyes o políticas aplicables lo requieren, la app usa Google User Messaging Platform (UMP) para solicitar decisiones de privacidad antes de pedir anuncios.\n\n'
                  'Puedes:\n'
                  '• Aceptar o rechazar el uso de datos para publicidad personalizada\n'
                  '• Revocar el consentimiento en cualquier momento\n'
                  '• Revisar las opciones de privacidad de cada proveedor\n\n'
                  'Según tu elección y región, Google puede mostrar anuncios personalizados, no personalizados, limitados o aptos para entrega técnica. Rechazar la personalización no necesariamente elimina la publicidad.',
            ),
            links: const [],
          ),

          _Section(
            icon: Icons.child_care_outlined,
            title: tr('6. Children’s privacy', '6. Protección de menores'),
            body: tr(
              'Floating Volume is not intended for children under 13 (or under '
                  '16 in the EEA). We do not knowingly collect information from '
                  'minors. If you believe there is a concern involving a minor, '
                  'contact us using the email address below.',
              'Floating Volume no está dirigida a menores de 13 años (ni menores de 16 años en el AEE). No recopilamos conscientemente información de menores. Si crees que existe un problema relacionado con un menor, contáctanos mediante el correo indicado abajo.',
            ),
          ),

          _Section(
            icon: Icons.storage_outlined,
            title: tr('7. Data retention', '7. Retención de datos'),
            body: tr(
              'User preferences are stored locally on the device until the user '
                  'resets settings or clears app data. Uninstalling does not delete '
                  'submitted reports or provider-held data. Reports and attachments '
                  'remain until support removes them or handles a deletion request. '
                  'Email fixbyte3@gmail.com with your report reference to request deletion. '
                  'There is no automatic 90-day deletion of all support reports. '
                  'AdMob and Firebase retention follows their service policies.',
              'Las preferencias pueden restablecerse borrando los datos de la app. Desinstalar no elimina reportes enviados ni datos conservados por proveedores. Los reportes y adjuntos permanecen hasta que soporte los elimine o atienda una solicitud. Solicita su eliminación a fixbyte3@gmail.com con la referencia del reporte. No existe un borrado automático de todos los reportes a los 90 días. La conservación de AdMob y Firebase depende de sus políticas de servicio.',
            ),
          ),

          _Section(
            icon: Icons.update_outlined,
            title: tr(
              '8. Changes to this policy',
              '8. Cambios a esta política',
            ),
            body: tr(
              'We may update this Privacy Policy from time to time to reflect '
                  'changes to the app or legal requirements. The last-updated date '
                  'will always appear at the top of this document. The current '
                  'version will remain at the same web address.',
              'Podemos actualizar esta Política de Privacidad para reflejar cambios en la app o en los requisitos legales. La fecha de la última actualización aparecerá al inicio de este documento. La versión vigente se mantendrá en la misma dirección web.',
            ),
          ),

          _LinkSection(
            icon: Icons.contact_support_outlined,
            title: tr('9. Contact', '9. Contacto'),
            body: tr(
              'For questions, comments, or requests about this Privacy Policy '
                  'or how your data is handled, contact us at fixbyte3@gmail.com. '
                  'Do not include passwords or sensitive information in your request.',
              'Si tienes preguntas, comentarios o solicitudes sobre esta Política de Privacidad o el manejo de tus datos, escribe a fixbyte3@gmail.com. No incluyas contraseñas ni información sensible.',
            ),
            links: [
              _PolicyLink(
                tr('Full public policy', 'Política pública completa'),
                _publicPolicyUrl,
              ),
              _PolicyLink(
                tr('Contact by email', 'Contactar por correo'),
                _privacyEmail,
              ),
            ],
          ),

          const Gap(32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const Gap(4),
          Divider(color: cs.outlineVariant.withAlpha(80)),
        ],
      ),
    );
  }
}

class _PolicyLink {
  final String label;
  final String url;
  const _PolicyLink(this.label, this.url);
}

class _LinkSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<_PolicyLink> links;
  const _LinkSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (links.isNotEmpty) ...[
            const Gap(8),
            ...links.map(
              (link) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap:
                      () => launchUrl(
                        Uri.parse(link.url),
                        mode: LaunchMode.externalApplication,
                      ),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                        const Gap(4),
                        Text(
                          link.label,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Gap(4),
          Divider(color: cs.outlineVariant.withAlpha(80)),
        ],
      ),
    );
  }
}
