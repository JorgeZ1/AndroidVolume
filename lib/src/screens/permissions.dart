import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:floating_volume/src/app_language.dart';

import 'package:floating_volume/src/bloc/permissions/bloc.dart' as bpermissions;
import 'package:floating_volume/src/bloc/permissions/event.dart'
    as epermissions;
import 'package:floating_volume/src/bloc/permissions/state.dart'
    as spermissions;

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Permissions', 'Permisos')),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              'Grant all permissions to enable the floating widget.',
              'Concede los permisos para activar los botones flotantes.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurface.withAlpha(178)),
          ),
          const Gap(20),
          _PermissionCard(
            icon: Icons.picture_in_picture_alt_rounded,
            title: tr('Overlay', 'Superposición'),
            description: tr(
              'Draw over other apps',
              'Mostrar sobre otras aplicaciones',
            ),
            type: _PermissionType.overlay,
          ),
          const Gap(10),
          _PermissionCard(
            icon: Icons.notifications_outlined,
            title: tr('Notifications', 'Notificaciones'),
            description: tr(
              'Show a persistent notification while active',
              'Mostrar una notificación persistente mientras está activo',
            ),
            type: _PermissionType.notification,
          ),
          const Gap(10),
          _PermissionCard(
            icon: Icons.battery_charging_full_outlined,
            title: tr('Battery Optimization', 'Optimización de batería'),
            description: tr(
              'Prevent the system from stopping the service',
              'Evitar que el sistema detenga el servicio',
            ),
            type: _PermissionType.battery,
          ),
          const Gap(24),
          _HelpTile(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission type enum
// ---------------------------------------------------------------------------
enum _PermissionType { overlay, notification, battery }

// ---------------------------------------------------------------------------
// Single permission card
// ---------------------------------------------------------------------------
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final _PermissionType type;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<bpermissions.Bloc, spermissions.State>(
      builder: (context, state) {
        final permission = switch (type) {
          _PermissionType.overlay => state.overlayPermission,
          _PermissionType.notification => state.notificationPermission,
          _PermissionType.battery => state.batteryOptimizationPermission,
        };
        final isGranted = switch (type) {
          _PermissionType.overlay => state.overlayPermission.status.isGranted,
          _PermissionType.notification =>
            state.notificationPermission.status.isGranted,
          _PermissionType.battery =>
            state.batteryOptimizationPermission.status.isGranted,
        };

        final epermissions.Event requestEvent = switch (type) {
          _PermissionType.overlay =>
            epermissions.Event.requestOverlayPermission,
          _PermissionType.notification =>
            epermissions.Event.requestNotificationPermission,
          _PermissionType.battery =>
            epermissions.Event.requestBatteryOptimizationPermission,
        };

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color:
                  isGranted
                      ? Colors.green.shade600.withAlpha(60)
                      : cs.outlineVariant,
            ),
          ),
          color:
              isGranted
                  ? Colors.green.shade600.withAlpha(12)
                  : cs.surfaceContainerLow,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isGranted
                        ? Colors.green.shade600.withAlpha(25)
                        : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isGranted ? Colors.green.shade600 : cs.onSurfaceVariant,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              permission.operation == spermissions.PermissionOperation.failed
                  ? tr(
                    'Could not open the permission request. Try again.',
                    'No se pudo abrir la solicitud. Inténtalo de nuevo.',
                  )
                  : description,
            ),
            trailing:
                permission.operation ==
                        spermissions.PermissionOperation.requestingPermission
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : isGranted
                    ? Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade600,
                    )
                    : FilledButton.tonal(
                      onPressed:
                          state.isRequesting
                              ? null
                              : () {
                                context.read<bpermissions.Bloc>().add(
                                  requestEvent,
                                );
                              },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(tr('Grant', 'Conceder')),
                    ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Help tile
// ---------------------------------------------------------------------------
class _HelpTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.help_outline_rounded, color: cs.onSurfaceVariant),
        title: Text(tr('App keeps closing?', '¿La app se sigue cerrando?')),
        subtitle: Text(
          tr(
            'Your device may be killing the service. Tap to learn more.',
            'Tu dispositivo podría estar deteniendo el servicio. Toca para saber más.',
          ),
        ),
        trailing: Icon(Icons.open_in_new_rounded, color: cs.onSurfaceVariant),
        onTap: () async {
          await launchUrlString(
            "https://dontkillmyapp.com/",
            mode: LaunchMode.externalApplication,
          );
        },
      ),
    );
  }
}
