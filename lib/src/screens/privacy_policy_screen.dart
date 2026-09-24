import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = '13 de septiembre de 2026';
  static const String _publicPolicyUrl =
      'https://www.fixbitsolutions.com/privacy/floating-volume/';
  static const String _privacyEmail =
      'mailto:fixbyte3@gmail.com?subject=Privacidad%20Floating%20Volume';
  static const String _googlePrivacyUrl = 'https://policies.google.com/privacy';
  static const String _admobOptOutUrl =
      'https://support.google.com/ads/answer/2662922';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
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
                    'Última actualización: $_lastUpdated',
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

          const _Section(
            icon: Icons.info_outline_rounded,
            title: '1. Información general',
            body:
                'Floating Volume (com.fixbyte.floatingvolume), publicada por '
                'FixBit Solutions, es una aplicación que muestra botones '
                'flotantes de control de volumen sobre otras aplicaciones en Android. '
                'Esta política de privacidad describe cómo manejamos la información '
                'del usuario y qué datos terceros pueden recopilar.',
          ),

          const _Section(
            icon: Icons.lock_outline_rounded,
            title: '2. Información almacenada localmente',
            body:
                'FixBit Solutions no recibe en servidores propios las preferencias '
                'de Floating Volume. La aplicación no solicita:\n\n'
                '• Nombres, correos electrónicos ni datos de contacto\n'
                '• Contraseñas ni datos de cuenta\n'
                '• Grabaciones de audio, cámara ni micrófono\n'
                '• Historial de llamadas ni mensajes\n'
                '• Ubicación precisa o aproximada\n\n'
                'Las preferencias del usuario (estilo visual, opacidad, posición, '
                'configuración avanzada, canales de audio y vencimiento del acceso '
                'temporal a estilos especiales) se almacenan '
                'exclusivamente en el almacenamiento local del dispositivo mediante '
                'SharedPreferences. Esta afirmación no incluye los datos procesados '
                'por Google AdMob, descritos en la sección 4.',
          ),

          const _Section(
            icon: Icons.settings_suggest_outlined,
            title: '3. Permisos del sistema utilizados',
            body:
                'La aplicación solicita los siguientes permisos para su funcionamiento:\n\n'
                '• SYSTEM_ALERT_WINDOW: Necesario para mostrar los botones flotantes sobre '
                'otras aplicaciones. Sin este permiso la app no puede funcionar.\n\n'
                '• REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: Necesario para mantener el servicio '
                'activo en segundo plano y que los botones sigan apareciendo en todo momento, '
                'especialmente en dispositivos con gestión agresiva de batería.\n\n'
                '• FOREGROUND_SERVICE / FOREGROUND_SERVICE_SPECIAL_USE: Para ejecutar el '
                'servicio de botones flotantes de forma estable con una notificación persistente.\n\n'
                '• MODIFY_AUDIO_SETTINGS: Para leer y modificar el volumen del sistema.\n\n'
                '• POST_NOTIFICATIONS: Para mostrar la notificación de control en el panel de '
                'notificaciones (requerido en Android 13+).\n\n'
                '• RECEIVE_BOOT_COMPLETED: Para restaurar el servicio después de reiniciar '
                'cuando el usuario lo dejó habilitado.\n\n'
                '• KILL_BACKGROUND_PROCESSES: Ayuda a aplicar cambios internos del servicio; '
                'no permite leer información de otras aplicaciones.\n\n'
                '• INTERNET: Requerido por Google AdMob para cargar anuncios.',
          ),

          _LinkSection(
            icon: Icons.campaign_outlined,
            title: '4. Publicidad — Google AdMob',
            body:
                'Floating Volume utiliza Google AdMob para mostrar un banner en la '
                'pantalla principal mientras la aplicación está abierta y anuncios de '
                'video recompensados en la sección de Estilos Especiales. Al completar '
                'voluntariamente un anuncio recompensado, desbloqueas únicamente el estilo '
                'seleccionado durante 24 horas acumulables. La recompensa solo se concede cuando '
                'el SDK confirma que fue obtenida.\n\n'
                'Google Mobile Ads SDK puede recopilar o compartir:\n\n'
                '• Dirección IP para estimar una ubicación general\n'
                '• Aperturas, toques y visualizaciones de anuncios o videos\n'
                '• Diagnósticos, rendimiento, bloqueos y uso de energía\n'
                '• Identificador de publicidad, App Set ID y otros identificadores aplicables\n\n'
                'Google procesa estos datos para publicidad, medición, análisis y '
                'prevención del fraude, y declara que se cifran en tránsito mediante TLS.',
            links: [
              _PolicyLink(
                'Política de Privacidad de Google',
                _googlePrivacyUrl,
              ),
              _PolicyLink(
                'Controles de privacidad de anuncios de Google',
                _admobOptOutUrl,
              ),
            ],
          ),

          const _LinkSection(
            icon: Icons.gavel_outlined,
            title: '5. Consentimiento y opciones de anuncios',
            body:
                'Cuando las leyes o políticas aplicables lo requieren, la aplicación '
                'utiliza Google User Messaging Platform (UMP) para solicitar decisiones '
                'de privacidad antes de pedir anuncios.\n\n'
                'Puedes:\n'
                '• Aceptar o rechazar el uso de datos para publicidad personalizada\n'
                '• Revocar este consentimiento en cualquier momento\n'
                '• Revisar las opciones de privacidad de cada proveedor de anuncios\n\n'
                'Según la elección y la región, Google puede mostrar anuncios personalizados, '
                'no personalizados, limitados o aptos para entrega técnica. Rechazar la '
                'personalización no necesariamente elimina la publicidad.',
            links: [],
          ),

          const _Section(
            icon: Icons.child_care_outlined,
            title: '6. Protección de menores',
            body:
                'Floating Volume no está dirigida a menores de 13 años (ni menores '
                'de 16 años en el AEE). No recopilamos conscientemente información '
                'de menores de edad. Si crees que existe un problema relacionado con '
                'un menor, contáctanos mediante el correo indicado al final.',
          ),

          const _Section(
            icon: Icons.storage_outlined,
            title: '7. Retención de datos',
            body:
                'Los datos de preferencias del usuario se almacenan localmente en el '
                'dispositivo hasta que el usuario restablece la configuración, borra los '
                'datos o desinstala la aplicación. Floating Volume no tiene cuentas ni '
                'backend propio. Google conserva y elimina los datos que procesa conforme '
                'a sus propias políticas.',
          ),

          const _Section(
            icon: Icons.update_outlined,
            title: '8. Cambios a esta política',
            body:
                'Podemos actualizar esta Política de Privacidad periódicamente para '
                'reflejar cambios en la aplicación o en los requisitos legales. La fecha '
                'de la última actualización siempre se indicará al inicio de este documento. '
                'La versión vigente se mantendrá en la misma dirección web.',
          ),

          _LinkSection(
            icon: Icons.contact_support_outlined,
            title: '9. Contacto',
            body:
                'Si tienes preguntas, comentarios o solicitudes relacionadas con '
                'esta Política de Privacidad o el manejo de tus datos, puedes '
                'contactarnos en fixbyte3@gmail.com. No envíes contraseñas ni '
                'información sensible en tu solicitud.',
            links: [
              _PolicyLink('Política pública completa', _publicPolicyUrl),
              _PolicyLink('Contactar por correo', _privacyEmail),
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
