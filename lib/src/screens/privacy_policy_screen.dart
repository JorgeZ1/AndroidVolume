import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = '16 de abril de 2026';
  static const String _githubUrl =
      'https://github.com/mkalmousli/FloatingVolume/issues';
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
            body: 'Floating Volume es una aplicación gratuita que muestra botones '
                'flotantes de control de volumen sobre otras aplicaciones en Android. '
                'Esta política de privacidad describe cómo manejamos la información '
                'del usuario y qué datos terceros pueden recopilar.',
          ),

          const _Section(
            icon: Icons.lock_outline_rounded,
            title: '2. Datos que NO recopila la aplicación',
            body: 'Floating Volume NO recopila ni transmite a ningún servidor propio:\n\n'
                '• Nombres, correos electrónicos ni datos de contacto\n'
                '• Contraseñas ni datos de cuenta\n'
                '• Grabaciones de audio, cámara ni micrófono\n'
                '• Historial de llamadas ni mensajes\n'
                '• Ubicación precisa o aproximada\n\n'
                'Todas las preferencias del usuario (estilo visual, opacidad, '
                'posición de los botones, configuración avanzada) se almacenan '
                'exclusivamente en el almacenamiento local del dispositivo mediante '
                'SharedPreferences y no son enviadas a ningún servidor.',
          ),

          const _Section(
            icon: Icons.settings_suggest_outlined,
            title: '3. Permisos del sistema utilizados',
            body: 'La aplicación solicita los siguientes permisos para su funcionamiento:\n\n'
                '• SYSTEM_ALERT_WINDOW: Necesario para mostrar los botones flotantes sobre '
                'otras aplicaciones. Sin este permiso la app no puede funcionar.\n\n'
                '• REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: Necesario para mantener el servicio '
                'activo en segundo plano y que los botones sigan apareciendo en todo momento, '
                'especialmente en dispositivos con gestión agresiva de batería.\n\n'
                '• FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK: Para ejecutar el '
                'servicio de botones flotantes de forma estable con una notificación persistente.\n\n'
                '• MODIFY_AUDIO_SETTINGS: Para leer y modificar el volumen del sistema.\n\n'
                '• POST_NOTIFICATIONS: Para mostrar la notificación de control en el panel de '
                'notificaciones (requerido en Android 13+).\n\n'
                '• INTERNET: Requerido por Google AdMob para cargar anuncios.',
          ),

          _LinkSection(
            icon: Icons.campaign_outlined,
            title: '4. Publicidad — Google AdMob',
            body: 'Floating Volume utiliza Google AdMob para mostrar anuncios de video '
                'recompensados en la sección de Estilos Especiales. Al ver un anuncio, '
                'desbloqueas estilos premium por 3 días.\n\n'
                'Google AdMob puede recopilar y procesar los siguientes datos para '
                'personalizar y mostrar anuncios:\n\n'
                '• Identificador de publicidad de Android (AAID/GAID)\n'
                '• Dirección IP (para geolocalización aproximada)\n'
                '• Información del dispositivo (modelo, versión de Android)\n'
                '• Datos de interacción con anuncios\n\n'
                'Puedes inhabilitar los anuncios personalizados en:\n'
                'Ajustes → Google → Anuncios → "Inhabilitar personalización de anuncios"\n\n'
                'O también puedes restablecer tu Identificador de Publicidad.',
            links: [
              _PolicyLink('Política de Privacidad de Google', _googlePrivacyUrl),
              _PolicyLink('Cómo inhabilitar anuncios personalizados', _admobOptOutUrl),
            ],
          ),

          const _LinkSection(
            icon: Icons.gavel_outlined,
            title: '5. Consentimiento — RGPD / CCPA / LGPD',
            body: 'Si resides en el Área Económica Europea (AEE), Reino Unido, '
                'California (EE.UU.) o Brasil, al abrir la aplicación por primera vez '
                'se mostrará un formulario de consentimiento de Google (User Messaging '
                'Platform — UMP) para el uso de datos personales con fines publicitarios.\n\n'
                'Puedes:\n'
                '• Aceptar o rechazar el uso de datos para publicidad personalizada\n'
                '• Revocar este consentimiento en cualquier momento\n'
                '• Revisar las opciones de privacidad de cada proveedor de anuncios\n\n'
                'Si rechazas el consentimiento, podrás seguir usando la aplicación '
                'pero los anuncios podrían ser no personalizados.',
            links: [],
          ),

          const _Section(
            icon: Icons.child_care_outlined,
            title: '6. Protección de menores',
            body: 'Floating Volume no está dirigida a menores de 13 años (ni menores '
                'de 16 años en el AEE). No recopilamos conscientemente información '
                'de menores de edad. Si crees que un menor ha proporcionado datos '
                'inadvertidamente, contáctanos a través del repositorio de GitHub.',
          ),

          const _Section(
            icon: Icons.storage_outlined,
            title: '7. Retención de datos',
            body: 'Los datos de preferencias del usuario se almacenan localmente en el '
                'dispositivo y son eliminados automáticamente al desinstalar la aplicación. '
                'No se almacena ningún dato en servidores propios ya que la aplicación '
                'no cuenta con backend propio.',
          ),

          const _Section(
            icon: Icons.update_outlined,
            title: '8. Cambios a esta política',
            body: 'Podemos actualizar esta Política de Privacidad periódicamente para '
                'reflejar cambios en la aplicación o en los requisitos legales. La fecha '
                'de la última actualización siempre se indicará al inicio de este documento. '
                'Te recomendamos revisar esta política periódicamente.',
          ),

          _LinkSection(
            icon: Icons.contact_support_outlined,
            title: '9. Contacto',
            body: 'Si tienes preguntas, comentarios o solicitudes relacionadas con '
                'esta Política de Privacidad o el manejo de tus datos, puedes '
                'contactarnos abriendo un issue en el repositorio oficial de GitHub.',
            links: [
              _PolicyLink('Abrir un issue en GitHub', _githubUrl),
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
                  onTap: () => launchUrl(
                    Uri.parse(link.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 14, color: cs.primary),
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
