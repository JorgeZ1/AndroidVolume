import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:floating_volume/src/widget_settings.dart';

import 'package:floating_volume/src/bloc/status/bloc.dart' as bstatus;
import 'package:floating_volume/src/bloc/status/event.dart' as estatus;
import 'package:floating_volume/src/bloc/status/state.dart' as sstatus;

import 'package:floating_volume/src/bloc/permissions/bloc.dart' as bpermissions;
import 'package:floating_volume/src/bloc/permissions/event.dart' as epermissions;
import 'package:floating_volume/src/bloc/permissions/state.dart' as spermissions;

import 'package:floating_volume/src/bloc/theme/bloc.dart' as btheme;
import 'package:floating_volume/src/bloc/theme/state.dart' as stheme;
import 'package:floating_volume/src/bloc/theme/event.dart' as etheme;

const _kBlue = Color(0xFF2979FF);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<bpermissions.Bloc, spermissions.State>(
      builder: (context, state) {
        if (!state.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final requiredGranted = state.overlayPermission.status.isGranted &&
            state.batteryOptimizationPermission.status.isGranted;

        if (!requiredGranted) return const _PermissionsView();
        return const _MainView();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Permissions view — shown until required permissions are granted
// ---------------------------------------------------------------------------
class _PermissionsView extends StatelessWidget {
  const _PermissionsView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floating Volume'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: BlocBuilder<bpermissions.Bloc, spermissions.State>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _SectionLabel('Permisos (requeridos)'),
              const Gap(10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    _PermissionRow(
                      title: 'Capa sobrepuesta',
                      subtitle:
                          'Para renderizar los botones de volumen sobre otras aplicaciones.',
                      isGranted: state.overlayPermission.status.isGranted,
                      onTap: () => context
                          .read<bpermissions.Bloc>()
                          .add(epermissions.Event.requestOverlayPermission),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                    _PermissionRow(
                      title: 'Ejecutar en segundo plano',
                      subtitle:
                          'Para seguir mostrando los botones de volumen en la pantalla.',
                      isGranted:
                          state.batteryOptimizationPermission.status.isGranted,
                      onTap: () => context.read<bpermissions.Bloc>().add(
                          epermissions
                              .Event.requestBatteryOptimizationPermission),
                    ),
                  ],
                ),
              ),
              const Gap(20),
              _SectionLabel('Permisos (opcional)'),
              const Gap(10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: _PermissionRow(
                  title: 'Permiso de notificación',
                  subtitle:
                      'Para alternar los botones de volumen desde la notificación.',
                  isGranted: state.notificationPermission.status.isGranted,
                  onTap: () => context
                      .read<bpermissions.Bloc>()
                      .add(epermissions.Event.requestNotificationPermission),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionRow({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: isGranted
          ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600)
          : const Icon(Icons.chevron_right_rounded),
      onTap: isGranted ? null : onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Main view — shown after required permissions are granted
// ---------------------------------------------------------------------------
class _MainView extends StatelessWidget {
  const _MainView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floating Volume'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Controls card ────────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                BlocBuilder<bstatus.Bloc, sstatus.State>(
                  builder: (context, state) {
                    final loading = state.operation != sstatus.Operation.none;
                    return SwitchListTile(
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text('Mostrar botones de volumen'),
                      value: state.isEnabled,
                      onChanged: loading
                          ? null
                          : (_) => context
                              .read<bstatus.Bloc>()
                              .add(estatus.Event.toggle),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('Botones de pin en su posición'),
                  trailing: Text('No', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('Utilice el control deslizante de volumen'),
                  trailing: Text('No', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),

          const Gap(12),

          // ── Widget appearance card ────────────────────────────────────────
          const _WidgetAppearanceCard(),

          const Gap(24),

          // ── Style selector ───────────────────────────────────────────────
          _SectionLabel('Seleccionar estilo'),
          const Gap(12),
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _StyleCard(
                  label: 'Android',
                  selected: true,
                  preview: _AndroidStylePreview(),
                ),
                Gap(12),
                _StyleCard(
                  label: 'Android 12',
                  selected: false,
                  preview: _Android12StylePreview(),
                ),
              ],
            ),
          ),

          const Gap(24),

          // ── Appearance ───────────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apariencia',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface.withAlpha(153),
                        ),
                  ),
                  const Gap(12),
                  BlocBuilder<btheme.Bloc, stheme.State>(
                    builder: (context, state) {
                      return SegmentedButton<stheme.Theme>(
                        style: SegmentedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: stheme.Theme.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: stheme.Theme.system,
                            icon: Icon(Icons.contrast_outlined),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: stheme.Theme.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {state.theme},
                        onSelectionChanged: (value) => context
                            .read<btheme.Bloc>()
                            .add(etheme.Change(value.first)),
                        showSelectedIcon: false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const Gap(12),

          // ── Info / links ─────────────────────────────────────────────────
          _InfoCard(),

          const Gap(32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Style cards
// ---------------------------------------------------------------------------
class _StyleCard extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget preview;

  const _StyleCard({
    required this.label,
    required this.selected,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _kBlue : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: preview,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? _kBlue : Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Android style preview: two white circles + slim white slider
class _AndroidStylePreview extends StatelessWidget {
  const _AndroidStylePreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PreviewCircle(label: '+', bg: Colors.white, fg: _kBlue),
            const Gap(10),
            _PreviewCircle(label: '−', bg: Colors.white, fg: _kBlue),
          ],
        ),
        const Gap(10),
        _SlimSliderPreview(),
      ],
    );
  }
}

// Android 12 style preview: two blue circles + fat blue pill slider
class _Android12StylePreview extends StatelessWidget {
  const _Android12StylePreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PreviewCircle(label: '+', bg: _kBlue, fg: Colors.white),
            const Gap(10),
            _PreviewCircle(label: '−', bg: _kBlue, fg: Colors.white),
          ],
        ),
        const Gap(10),
        _FatSliderPreview(),
      ],
    );
  }
}

class _PreviewCircle extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _PreviewCircle({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

// Slim white pill with blue thumb + music note
class _SlimSliderPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 3,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: 14,
              height: 14,
              decoration:
                  const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
            ),
          ),
          const Positioned(
            bottom: 10,
            child: Icon(Icons.music_note_rounded, size: 12, color: _kBlue),
          ),
        ],
      ),
    );
  }
}

// Fat blue pill with music note (Android 12 style)
class _FatSliderPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 100,
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.music_note_rounded, size: 18, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget appearance — opacity + color mode
// ---------------------------------------------------------------------------
class _WidgetAppearanceCard extends StatefulWidget {
  const _WidgetAppearanceCard();

  @override
  State<_WidgetAppearanceCard> createState() => _WidgetAppearanceCardState();
}

class _WidgetAppearanceCardState extends State<_WidgetAppearanceCard> {
  double _opacity = WidgetSettings.opacity;
  WidgetColorMode _colorMode = WidgetSettings.colorMode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apariencia del widget',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withAlpha(153),
                  ),
            ),

            const Gap(12),

            // ── Opacity ───────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.opacity_outlined, size: 20),
                const Gap(10),
                Text('Opacidad', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${(_opacity * 100).round()}%',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Slider(
              value: _opacity,
              min: 0.2,
              max: 1.0,
              divisions: 16,
              onChanged: (v) => setState(() => _opacity = v),
              onChangeEnd: (v) => WidgetSettings.setOpacity(v),
            ),

            Divider(height: 1, color: cs.outlineVariant),
            const Gap(12),

            // ── Color mode ────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 20),
                const Gap(10),
                Text('Color', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const Gap(10),
            SegmentedButton<WidgetColorMode>(
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: WidgetColorMode.auto,
                  icon: Icon(Icons.contrast_outlined),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: WidgetColorMode.blue,
                  icon: Icon(Icons.circle, color: Color(0xFF2979FF)),
                  label: Text('Azul'),
                ),
                ButtonSegment(
                  value: WidgetColorMode.dark,
                  icon: Icon(Icons.circle, color: Color(0xFF1C1C1E)),
                  label: Text('Negro'),
                ),
              ],
              selected: {_colorMode},
              onSelectionChanged: (v) {
                setState(() => _colorMode = v.first);
                WidgetSettings.setColorMode(v.first);
              },
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info / Links Card
// ---------------------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = <_LinkItem>[
      _LinkItem(
        icon: Icons.info_outline_rounded,
        title: 'Versión',
        subtitle: 'v0.0.3 · 11 Oct 2025',
        onTap: null,
      ),
      _LinkItem(
        icon: Icons.person_outline_rounded,
        title: 'Creado por @mkalmousli',
        subtitle: 'mkalmousli.dev',
        onTap: () => launchUrlString('https://mkalmousli.dev',
            mode: LaunchMode.externalApplication),
      ),
      _LinkItem(
        icon: Icons.bug_report_outlined,
        title: 'Reportar un problema',
        subtitle: 'Abrir un issue en GitHub',
        onTap: () => launchUrlString(
            'https://github.com/mkalmousli/FloatingVolume/issues',
            mode: LaunchMode.externalApplication),
      ),
      _LinkItem(
        icon: Icons.code_rounded,
        title: 'Código fuente',
        subtitle: 'Ver en GitHub',
        onTap: () => launchUrlString(
            'https://github.com/mkalmousli/FloatingVolume',
            mode: LaunchMode.externalApplication),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: cs.onSurfaceVariant),
              title: Text(items[i].title),
              subtitle:
                  items[i].subtitle != null ? Text(items[i].subtitle!) : null,
              trailing: items[i].onTap != null
                  ? Icon(Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant)
                  : null,
              onTap: items[i].onTap,
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: cs.outlineVariant.withAlpha(128),
              ),
          ],
        ],
      ),
    );
  }
}

class _LinkItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function()? onTap;

  const _LinkItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
