import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
        title: const Text("Permissions"),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Grant all permissions to enable the floating widget.",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: cs.onSurface.withAlpha(178),
            ),
          ),
          const Gap(20),
          const _PermissionCard(
            icon: Icons.picture_in_picture_alt_rounded,
            title: "Overlay",
            description: "Draw over other apps",
            type: _PermissionType.overlay,
          ),
          const Gap(10),
          const _PermissionCard(
            icon: Icons.notifications_outlined,
            title: "Notifications",
            description: "Show a persistent notification while active",
            type: _PermissionType.notification,
          ),
          const Gap(10),
          const _PermissionCard(
            icon: Icons.battery_charging_full_outlined,
            title: "Battery Optimization",
            description: "Prevent the system from stopping the service",
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
        final isGranted = switch (type) {
          _PermissionType.overlay =>
            state.overlayPermission.status.isGranted,
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
              color: isGranted
                  ? Colors.green.shade600.withAlpha(60)
                  : cs.outlineVariant,
            ),
          ),
          color: isGranted
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
                color: isGranted
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
            subtitle: Text(description),
            trailing: isGranted
                ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600)
                : FilledButton.tonal(
                    onPressed: () {
                      context.read<bpermissions.Bloc>().add(requestEvent);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("Grant"),
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
        title: const Text("App keeps closing?"),
        subtitle: const Text(
          "Your device may be killing the service. Tap to learn more.",
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
