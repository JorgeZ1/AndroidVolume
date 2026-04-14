import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
        children: const [
          _Section('1. Información general',
              'Floating Volume es una aplicación gratuita que agrega botones '
              'flotantes de control de volumen a tu pantalla. Esta política '
              'explica qué datos se recopilan y cómo se usan.'),
          _Section('2. Datos que NO recopila la app',
              'La aplicación no recopila nombres, correos, números de teléfono '
              'ni ningún dato de identificación personal. No existen servidores '
              'propios que almacenen información del usuario. Las preferencias '
              '(estilo visual, opacidad, posición) se guardan solo localmente '
              'en el dispositivo.'),
          _Section('3. Publicidad — Google AdMob',
              'Esta app utiliza Google AdMob para mostrar anuncios en la sección '
              'de Estilos Especiales. AdMob puede recopilar y usar los siguientes '
              'datos para personalizar anuncios:\n\n'
              '• Identificador de publicidad de Android (AAID/GAID)\n'
              '• Dirección IP (para determinar ubicación aproximada)\n'
              '• Información del dispositivo (modelo, sistema operativo)\n'
              '• Datos de uso de la aplicación\n\n'
              'Puedes optar por no recibir anuncios personalizados en:\n'
              'Ajustes del dispositivo → Google → Anuncios → '
              '"Inhabilitar personalización de anuncios".\n\n'
              'Política de privacidad de Google: https://policies.google.com/privacy'),
          _Section('4. Consentimiento (RGPD / CCPA)',
              'Al abrir la aplicación por primera vez, se puede mostrar un '
              'formulario de consentimiento de Google (UMP) si así lo requiere '
              'tu región (Unión Europea, California, etc.). Puedes revocar el '
              'consentimiento en cualquier momento desde los ajustes del dispositivo.'),
          _Section('5. Datos del menor de edad',
              'Esta aplicación no está dirigida a menores de 13 años ni '
              'recopila conscientemente datos de menores.'),
          _Section('6. Cambios a esta política',
              'Podemos actualizar esta política ocasionalmente. Los cambios '
              'serán efectivos al publicar la nueva versión en la tienda.'),
          _Section('7. Contacto',
              'Si tienes preguntas sobre esta política de privacidad, '
              'abre un issue en el repositorio GitHub de la app.'),
          Gap(32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
          const Gap(6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
