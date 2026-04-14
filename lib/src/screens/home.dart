import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('widget_style');
    final style = WidgetStyle.values.where((s) => s.name == name).firstOrNull
        ?? WidgetStyle.android;
    if (mounted) {
      setState(() {
        _selectedStyle = style;
        _styleLoaded = true;
      });
      await WidgetSettings.setWidgetStyle(style);
    }
  }

  Future<void> _selectStyle(WidgetStyle style) async {
    setState(() => _selectedStyle = style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_style', style.name);
    await WidgetSettings.setWidgetStyle(style);
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

          _SectionLabel('🌟 Estilos Especiales y Creativos'),
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
// Style card — tappable, animated selection border
// ---------------------------------------------------------------------------
class _StyleCard extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  const _StyleCard({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 148,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kBlue : cs.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _kBlue.withAlpha(80), blurRadius: 10, spreadRadius: 1)]
              : [],
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
                      color: selected ? _kBlue : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(60), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Column(
                    children: [
                      Container(height: 18, color: Colors.white.withAlpha(200)),
                      Container(height: 34, color: Colors.white.withAlpha(40)),
                    ],
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: Colors.white.withAlpha(200), size: 16),
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
          width: 8,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(4),
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
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(180), width: 1.5),
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
                  child: Icon(Icons.volume_up_rounded, size: 14, color: Colors.white.withAlpha(220)),
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
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
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
        final cyan =
            Color.lerp(const Color(0xFF00FFFF), const Color(0xFF00B4FF), _ctrl.value)!;
        final magenta =
            Color.lerp(const Color(0xFFFF00FF), const Color(0xFFFF0090), _ctrl.value)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NeonButton(label: '+', glowColor: cyan),
                const Gap(10),
                _NeonButton(label: '−', glowColor: magenta),
              ],
            ),
            const Gap(10),
            Container(
              width: 14,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: cyan.withAlpha(200), width: 1.5),
                boxShadow: [BoxShadow(color: cyan.withAlpha(120), blurRadius: 8)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [magenta, cyan],
                      ),
                    ),
                  ),
                ],
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
  const _NeonButton({required this.label, required this.glowColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: glowColor, width: 2),
        boxShadow: [
          BoxShadow(color: glowColor.withAlpha(180), blurRadius: 10, spreadRadius: 1)
        ],
      ),
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
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t  = _ctrl.value;
        final c1 = Color.lerp(_spaceBlue, const Color(0xFF1A0A3F), t)!;
        final c2 = Color.lerp(_purple, _deepPurple, t)!;
        final c3 = Color.lerp(_gold, _orange, t)!;
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
                  colors: [c3, c2, c1],
                ),
                boxShadow: [
                  BoxShadow(color: c2.withAlpha(120), blurRadius: 10),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t      = _ctrl.value;
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
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
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
                  ? Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant)
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
