import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:floating_volume/src/services/ad_service.dart';
import 'package:floating_volume/src/widget_settings.dart';
import 'package:floating_volume/src/screens/privacy_policy_screen.dart';

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

// ---------------------------------------------------------------------------
// Style metadata — label and preview widget per style
// ---------------------------------------------------------------------------
extension WidgetStyleExt on WidgetStyle {
  String get label => switch (this) {
        WidgetStyle.android      => 'Android',
        WidgetStyle.android12    => 'Android 12',
        WidgetStyle.ios          => 'iOS',
        WidgetStyle.miui         => 'MIUI',
        WidgetStyle.samsungOneUi => 'One UI',
        WidgetStyle.rgbAurora    => 'RGB Aurora',
        WidgetStyle.rgbNeon      => 'RGB Neon',
        WidgetStyle.cosmic       => 'Cosmic',
        WidgetStyle.lava         => 'Lava',
      };

  bool get isSpecial => index >= 5; // rgbAurora, rgbNeon, cosmic, lava

  Widget get preview => switch (this) {
        WidgetStyle.android      => const _AndroidStylePreview(),
        WidgetStyle.android12    => const _Android12StylePreview(),
        WidgetStyle.ios          => const _IosStylePreview(),
        WidgetStyle.miui         => const _MiuiStylePreview(),
        WidgetStyle.samsungOneUi => const _SamsungOneUiPreview(),
        WidgetStyle.rgbAurora    => const _RgbAuroraPreview(),
        WidgetStyle.rgbNeon      => const _RgbNeonPreview(),
        WidgetStyle.cosmic       => const _CosmicPreview(),
        WidgetStyle.lava         => const _LavaPreview(),
      };
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
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
// Permissions view
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
// Main view — stateful to persist/restore selected style
// ---------------------------------------------------------------------------
class _MainView extends StatefulWidget {
  const _MainView();

  @override
  State<_MainView> createState() => _MainViewState();
}

class _MainViewState extends State<_MainView> {
  WidgetStyle _selectedStyle = WidgetStyle.android;
  bool _styleLoaded = false;
  bool _isPinned = false;
  bool _useSystemVolume = false;
  bool _specialUnlocked = false;
  String? _unlockTimeLeft;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_styleLoaded) return; // guard against re-entry
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('widget_style');
    final style = WidgetStyle.values.where((s) => s.name == name).firstOrNull
        ?? WidgetStyle.android;
    final pinned = prefs.getBool('widget_pinned') ?? false;
    final sysVol = prefs.getBool('widget_use_sys_vol') ?? false;
    final unlocked = await AdService.isUnlocked();
    final timeLeft = await AdService.timeLeftLabel();
    if (mounted && !_styleLoaded) {
      setState(() {
        _selectedStyle = style;
        _isPinned = pinned;
        _useSystemVolume = sysVol;
        _specialUnlocked = unlocked;
        _unlockTimeLeft = timeLeft;
        _styleLoaded = true;
      });
      try { await WidgetSettings.setWidgetStyle(style); } catch (_) {}
      try { await WidgetSettings.setPinned(pinned); } catch (_) {}
      try { await WidgetSettings.setUseSystemVolume(sysVol); } catch (_) {}
    }
  }

  Future<void> _selectStyle(WidgetStyle style) async {
    setState(() => _selectedStyle = style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_style', style.name);
    try { await WidgetSettings.setWidgetStyle(style); } catch (_) {}
  }

  Future<void> _togglePin(bool value) async {
    setState(() => _isPinned = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_pinned', value);
    try { await WidgetSettings.setPinned(value); } catch (_) {}
  }

  Future<void> _toggleSysVol(bool value) async {
    setState(() => _useSystemVolume = value);
    try { await WidgetSettings.setUseSystemVolume(value); } catch (_) {}
  }

  void _showUnlockSheet(WidgetStyle style) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UnlockSheet(
        style: style,
        onUnlocked: () async {
          final timeLeft = await AdService.timeLeftLabel();
          if (mounted) {
            setState(() {
              _specialUnlocked = true;
              _unlockTimeLeft = timeLeft;
            });
            _selectStyle(style);
          }
        },
      ),
    );
  }

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
                SwitchListTile(
                  secondary: const Icon(Icons.push_pin_outlined),
                  title: const Text('Botones de pin en su posición'),
                  value: _isPinned,
                  onChanged: _togglePin,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                SwitchListTile(
                  secondary: const Icon(Icons.tune_outlined),
                  title: const Text('Usar indicador nativo del sistema'),
                  value: _useSystemVolume,
                  onChanged: _toggleSysVol,
                ),
              ],
            ),
          ),

          const Gap(12),

          // ── Widget appearance card moved to bottom ──

          const Gap(24),

          // ── Style selector ───────────────────────────────────────────────
          _SectionLabel('Estilos de Sistema Clásicos'),
          const Gap(12),
          SizedBox(
            height: 190,
            child: _styleLoaded
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5, // classic styles
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) {
                      final style = WidgetStyle.values[index];
                      return _StyleCard(
                        label: style.label,
                        selected: _selectedStyle == style,
                        preview: style.preview,
                        onTap: () => _selectStyle(style),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          const Gap(20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SectionLabel('🌟 Estilos Especiales y Creativos'),
              if (_specialUnlocked && _unlockTimeLeft != null) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700).withAlpha(100)),
                  ),
                  child: Text(
                    '⏱ $_unlockTimeLeft',
                    style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const Gap(12),
          SizedBox(
            height: 190,
            child: _styleLoaded
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4, // rgbAurora, rgbNeon, cosmic, lava
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) {
                      final style = WidgetStyle.values[5 + index];
                      final locked = !_specialUnlocked;
                      return _StyleCard(
                        label: style.label,
                        selected: _selectedStyle == style,
                        locked: locked,
                        preview: style.preview,
                        onTap: () => locked
                            ? _showUnlockSheet(style)
                            : _selectStyle(style),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
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

          const Gap(24),

          // ── Advanced Personalization ──────────────────────────────────────
          _SectionLabel('Opciones Avanzadas'),
          const Gap(12),
          _FloatingButtonsSettingsCard(
            onChanged: () => setState(() {}),
          ),
          const Gap(12),
          _VolumeIndicatorSettingsCard(
            onChanged: () => setState(() {}),
          ),
          const Gap(16),
          FilledButton.icon(
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaurar Valores Predeterminados'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.tertiary,
              foregroundColor: cs.onTertiary,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Restaurar todo?'),
                  content: const Text('Se perderán las posiciones, tamaños y opacidades que has configurado para este diseño.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await WidgetSettings.restoreDefaultsForStyle(WidgetSettings.style);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valores de fábrica restablecidos para este diseño.')),
                  );
                }
              }
            },
          ),

          const Gap(24),

          // ── Privacy policy ───────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Política de privacidad'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
            ),
          ),

          const Gap(32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Style card — tappable, animated selection border
// ---------------------------------------------------------------------------
class _StyleCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool locked;
  final Widget preview;
  final VoidCallback onTap;

  const _StyleCard({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 148,
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF5F5FA) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kBlue : cs.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _kBlue.withAlpha(80), blurRadius: 10, spreadRadius: 1)]
              : isLight
                  ? [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))]
                  : [],
        ),
        child: Stack(
          children: [
            Column(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check_circle_rounded, size: 13, color: _kBlue),
                        const Gap(4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? _kBlue : (isLight ? Colors.black87 : Colors.white70),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (locked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(165),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 26),
                      Gap(6),
                      Text('Especial',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      Gap(3),
                      Text('Ver anuncio',
                          style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unlock sheet — shown when user taps a locked special style
// ---------------------------------------------------------------------------
class _UnlockSheet extends StatefulWidget {
  final WidgetStyle style;
  final VoidCallback onUnlocked;

  const _UnlockSheet({required this.style, required this.onUnlocked});

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  bool _loading = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD700), size: 40),
          const Gap(12),
          Text(
            'Estilo Especial: ${widget.style.label}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            'Ve un breve anuncio para desbloquear todos los\nestilos especiales durante 3 días.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const Gap(24),
          if (_loading)
            const CircularProgressIndicator()
          else if (_failed)
            Text(
              'Anuncio no disponible.\nIntenta de nuevo más tarde.',
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center,
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Ver anuncio — desbloquear 3 días'),
              onPressed: _watchAd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black87,
              ),
            ),
          const Gap(12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAd() async {
    setState(() { _loading = true; _failed = false; });
    final shown = await AdService.showAd(
      onRewarded: () {
        if (mounted) Navigator.pop(context);
        widget.onUnlocked();
      },
    );
    if (mounted && !shown) {
      setState(() { _loading = false; _failed = true; });
    }
  }
}

// ===========================================================================
// Style Previews — Classic
// ===========================================================================

// ── Android ─────────────────────────────────────────────────────────────────
class _AndroidStylePreview extends StatelessWidget {
  const _AndroidStylePreview();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final fg = dark ? Colors.white : _kBlue;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PreviewCircle(label: '+', bg: bg, fg: fg, border: !dark),
            const Gap(10),
            _PreviewCircle(label: '−', bg: bg, fg: fg, border: !dark),
          ],
        ),
        const Gap(10),
        _SlimSliderPreview(),
      ],
    );
  }
}

// ── Android 12 ──────────────────────────────────────────────────────────────
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

// ── iOS ─────────────────────────────────────────────────────────────────────
class _IosStylePreview extends StatelessWidget {
  const _IosStylePreview();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseAlpha = dark ? 55 : 100;
    final frostedBtn = BoxDecoration(
      color: (dark ? Colors.white : Colors.black).withAlpha(baseAlpha),
      shape: BoxShape.circle,
      border: Border.all(color: (dark ? Colors.white : Colors.black).withAlpha(dark ? 80 : 30), width: 1),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, height: 44,
              decoration: frostedBtn,
              alignment: Alignment.center,
              child: Text('+', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const Gap(10),
            Container(
              width: 44, height: 44,
              decoration: frostedBtn,
              alignment: Alignment.center,
              child: Text('−', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const Gap(10),
        Container(
          width: 32,
          height: 100,
          decoration: BoxDecoration(
            color: (dark ? Colors.white : Colors.black).withAlpha(baseAlpha),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (dark ? Colors.white : Colors.black).withAlpha(dark ? 80 : 30), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: double.infinity,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : Colors.black).withAlpha(200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── MIUI ────────────────────────────────────────────────────────────────────
class _MiuiStylePreview extends StatelessWidget {
  const _MiuiStylePreview();
  static const _orange = Color(0xFFFF6900);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiuiButton(label: '+', accent: _orange),
            const Gap(8),
            _MiuiButton(label: '−', accent: _orange),
          ],
        ),
        const Gap(10),
        Container(
          width: 14,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiuiButton extends StatelessWidget {
  final String label;
  final Color accent;
  const _MiuiButton({required this.label, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(5.0), // ~15% roundness
        border: Border.all(color: accent.withAlpha(210), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.bold, height: 1),
      ),
    );
  }
}

// ── Samsung One UI ──────────────────────────────────────────────────────────
class _SamsungOneUiPreview extends StatelessWidget {
  const _SamsungOneUiPreview();
  static const _teal = Color(0xFF1DB3A8);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _OneUiButton(icon: Icons.add_rounded, accent: _teal),
            const Gap(8),
            _OneUiButton(icon: Icons.remove_rounded, accent: _teal),
          ],
        ),
        const Gap(10),
        Container(
          width: 32,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: _teal.withAlpha(200),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('VOL', style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OneUiButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  const _OneUiButton({required this.icon, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(10.0), // Squircle
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

// ===========================================================================
// Style Previews — Animated (Special)
// ===========================================================================

// ── RGB Aurora ──────────────────────────────────────────────────────────────
class _RgbAuroraPreview extends StatefulWidget {
  const _RgbAuroraPreview();
  @override
  State<_RgbAuroraPreview> createState() => _RgbAuroraPreviewState();
}

class _RgbAuroraPreviewState extends State<_RgbAuroraPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final hue = (_ctrl.value * 360) % 360;
        final c1 = HSVColor.fromAHSV(1, hue, 0.9, 1).toColor();
        final c2 = HSVColor.fromAHSV(1, (hue + 120) % 360, 0.9, 1).toColor();
        final c3 = HSVColor.fromAHSV(1, (hue + 240) % 360, 0.9, 1).toColor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GradientCircle(label: '+', colors: [c1, c2]),
                const Gap(10),
                _GradientCircle(label: '−', colors: [c2, c3]),
              ],
            ),
            const Gap(10),
            Container(
              width: 12,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c1, c2, c3],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Shared gradient circle used by Aurora, Cosmic, and Lava previews
class _GradientCircle extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  const _GradientCircle({
    required this.label,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end   = Alignment.bottomRight,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: begin, end: end),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

// ── RGB Neon ────────────────────────────────────────────────────────────────

class _RgbNeonPreview extends StatefulWidget {
  const _RgbNeonPreview();
  @override
  State<_RgbNeonPreview> createState() => _RgbNeonPreviewState();
}

class _RgbNeonPreviewState extends State<_RgbNeonPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final pingPong = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
        final cyan    = Color.lerp(const Color(0xFF00FFFF), const Color(0xFF00B4FF), pingPong)!;
        final magenta = Color.lerp(const Color(0xFFFF00FF), const Color(0xFFFF0090), pingPong)!;
        
        final trueCyan = const Color(0xFF00FFFF);
        final trueMagenta = const Color(0xFFFF00FF);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NeonButton(label: '+', glowColor: cyan, t: t, colors: [trueCyan, trueMagenta, trueCyan]),
                const Gap(10),
                _NeonButton(label: '−', glowColor: magenta, t: 1.0 - t, colors: [trueMagenta, trueCyan, trueMagenta]),
              ],
            ),
            const Gap(10),
            Container(
              width: 18,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: SweepGradient(
                  colors: [trueCyan, trueMagenta, trueCyan],
                  transform: GradientRotation(t * 2 * math.pi),
                ),
                boxShadow: [BoxShadow(color: cyan.withAlpha(120), blurRadius: 8)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: magenta,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final Color glowColor;
  final double t;
  final List<Color> colors;
  const _NeonButton({required this.label, required this.glowColor, required this.t, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: colors,
          transform: GradientRotation(t * 2 * math.pi),
        ),
        boxShadow: [
          BoxShadow(color: glowColor.withAlpha(160), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: glowColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cosmic ───────────────────────────────────────────────────────────────────
// Deep-space gradient that morphs between space-blue, purple, and gold.
class _CosmicPreview extends StatefulWidget {
  const _CosmicPreview();
  @override
  State<_CosmicPreview> createState() => _CosmicPreviewState();
}

class _CosmicPreviewState extends State<_CosmicPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _spaceBlue = Color(0xFF0D1B69);
  static const _purple    = Color(0xFF9B5DE5);
  static const _deepPurple = Color(0xFF5B10A0);
  static const _gold      = Color(0xFFFFD700);
  static const _orange    = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t  = _ctrl.value;
        final pingPong = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
        final c1 = Color.lerp(_spaceBlue, const Color(0xFF1A0A3F), pingPong)!;
        final c2 = Color.lerp(_purple, _deepPurple, pingPong)!;
        final c3 = Color.lerp(_gold, _orange, pingPong)!;
        
        final borderColors = [
            _purple, Colors.transparent, _gold, Colors.transparent, _purple
        ];
        
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CosmicStarPainter(_ctrl.value),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CosmicButton(label: '+', bgColors: [c1, c2], borderColors: borderColors, t: t),
                    const Gap(10),
                    _CosmicButton(label: '−', bgColors: [c2, c3], borderColors: borderColors, t: t),
                  ],
                ),
                const Gap(10),
                Container(
                  width: 18,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: SweepGradient(
                      colors: borderColors,
                      transform: GradientRotation(t * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(color: c2.withAlpha(160), blurRadius: 14),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0221),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 45,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: c2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CosmicButton extends StatelessWidget {
  final String label;
  final List<Color> bgColors;
  final List<Color> borderColors;
  final double t;

  const _CosmicButton({
    required this.label, required this.bgColors, required this.borderColors, required this.t
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: borderColors,
          transform: GradientRotation(t * 2 * math.pi),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1),
          ),
        ),
      ),
    );
  }
}

class _CosmicStarPainter extends CustomPainter {
  final double t;
  _CosmicStarPainter(this.t);

  static const _stars = [
    Offset(0.10, 0.10), Offset(0.88, 0.18), Offset(0.55, 0.50),
    Offset(0.20, 0.78), Offset(0.80, 0.70), Offset(0.40, 0.25),
    Offset(0.70, 0.88),
  ];
  static const _colors = [
    Color(0xFFFFD700), Color(0xFFFFFFFF), Color(0xFF9B5DE5),
    Color(0xFFFFFFFF), Color(0xFFFFD700), Color(0xFF9B5DE5),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _stars.length; i++) {
      final phase = (t + i / _stars.length) % 1.0;
      final alpha = phase < 0.20
          ? phase / 0.20
          : phase < 0.35
              ? 1.0 - (phase - 0.20) / 0.15
              : 0.0;
      if (alpha <= 0) continue;
      paint.color = _colors[i].withOpacity(alpha * 0.9);
      final cx = _stars[i].dx * size.width;
      final cy = _stars[i].dy * size.height;
      canvas.drawCircle(Offset(cx, cy), 1.8, paint);
      // Cross sparkle
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 0.8;
      canvas.drawLine(Offset(cx - 4, cy), Offset(cx + 4, cy), paint);
      canvas.drawLine(Offset(cx, cy - 4), Offset(cx, cy + 4), paint);
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(_CosmicStarPainter old) => old.t != t;
}

// ── Lava ─────────────────────────────────────────────────────────────────────
// Molten lava: dark crimson → lava orange → fire tip with heat shimmer.
class _LavaPreview extends StatefulWidget {
  const _LavaPreview();
  @override
  State<_LavaPreview> createState() => _LavaPreviewState();
}

class _LavaPreviewState extends State<_LavaPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _heartbeat;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();
    _heartbeat = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),   // first beat up
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 12),   // valley
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.75), weight: 12),  // second beat
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 0.0), weight: 14),  // back to rest
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),             // rest pause
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heartbeat,
      builder: (_, __) {
        final t      = _heartbeat.value;
        final dark   = Color.lerp(const Color(0xFF3D0000), const Color(0xFF6B0000), t)!;
        final mid    = Color.lerp(const Color(0xFFFF4500), const Color(0xFFFF6A00), t)!;
        final bright = Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFFD700), t)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GradientCircle(
                  label: '+', colors: [dark, mid],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ),
                const Gap(10),
                _GradientCircle(
                  label: '−', colors: [mid, bright],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ),
              ],
            ),
            const Gap(10),
            Container(
              width: 12,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [dark, mid, bright],
                ),
                boxShadow: [
                  BoxShadow(color: mid.withAlpha(150), blurRadius: 10),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Shared preview sub-widgets
// ===========================================================================
class _PreviewCircle extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool border;
  const _PreviewCircle({required this.label, required this.bg, required this.fg, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg, 
        shape: BoxShape.circle,
        border: border ? Border.all(color: Colors.grey.withAlpha(50)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold, height: 1),
      ),
    );
  }
}

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
            width: 8,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

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
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced Personalization Cards
// ---------------------------------------------------------------------------

class _FloatingButtonsSettingsCard extends StatelessWidget {
  final VoidCallback onChanged;
  const _FloatingButtonsSettingsCard({required this.onChanged});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Botones Flotantes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Gap(16),
            _buildSliderRow(
              context,
              icon: Icons.aspect_ratio_outlined,
              label: 'Tamaño',
              value: WidgetSettings.buttonSize.toDouble(),
              min: 36, max: 72, divisions: 18,
              onChanged: (v) { WidgetSettings.setButtonSize(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.buttonSize}px',
            ),
            _buildSliderRow(
              context,
              icon: Icons.rounded_corner_outlined,
              label: 'Redondeo',
              value: WidgetSettings.buttonCornerRadius,
              min: 0.0, max: 0.5, divisions: 10,
              onChanged: (v) { WidgetSettings.setButtonCornerRadius(v); onChanged(); },
              formatStr: '${(WidgetSettings.buttonCornerRadius * 200).round()}%',
            ),
            _buildSliderRow(
              context,
              icon: Icons.height_outlined,
              label: 'Separación',
              value: WidgetSettings.buttonGap.toDouble(),
              min: 0, max: 40, divisions: 20,
              onChanged: (v) { WidgetSettings.setButtonGap(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.buttonGap}px',
            ),
            _buildSliderRow(
              context,
              icon: Icons.opacity_outlined,
              label: 'Opacidad',
              value: WidgetSettings.opacity,
              min: 0.0, max: 1.0, divisions: 20,
              onChanged: (v) { WidgetSettings.setOpacity(v); onChanged(); },
              formatStr: '${(WidgetSettings.opacity * 100).round()}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeIndicatorSettingsCard extends StatelessWidget {
  final VoidCallback onChanged;
  const _VolumeIndicatorSettingsCard({required this.onChanged});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barra de Volumen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Gap(16),
            _buildSliderRow(
              context,
              icon: Icons.timer_outlined,
              label: 'Duración',
              value: WidgetSettings.indicatorHideDelay.toDouble(),
              min: 500, max: 4000, divisions: 14,
              onChanged: (v) { WidgetSettings.setIndicatorHideDelay(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.indicatorHideDelay / 1000}s',
            ),
            _buildSliderRow(
              context,
              icon: Icons.straighten_outlined,
              label: 'Ancho',
              value: WidgetSettings.indicatorWidth.toDouble(),
              min: 24, max: 100, divisions: 38,
              onChanged: (v) { WidgetSettings.setIndicatorWidth(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.indicatorWidth}px',
            ),
            _buildSliderRow(
              context,
              icon: Icons.height_rounded,
              label: 'Alto',
              value: WidgetSettings.indicatorHeight.toDouble(),
              min: 100, max: 300, divisions: 40,
              onChanged: (v) { WidgetSettings.setIndicatorHeight(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.indicatorHeight}px',
            ),
            _buildSliderRow(
              context,
              icon: Icons.space_bar_rounded,
              label: 'Distancia',
              value: WidgetSettings.indicatorGap.toDouble(),
              min: -20, max: 80, divisions: 25,
              onChanged: (v) { WidgetSettings.setIndicatorGap(v.toInt()); onChanged(); },
              formatStr: '${WidgetSettings.indicatorGap}px',
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildSliderRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required double value,
  required double min,
  required double max,
  required int divisions,
  required ValueChanged<double> onChanged,
  required String formatStr,
}) {
  final cs = Theme.of(context).colorScheme;
  return Column(
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const Gap(10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            formatStr,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          overlayShape: SliderComponentShape.noOverlay,
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      const Gap(12),
    ],
  );
}

