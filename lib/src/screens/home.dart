import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:floating_volume/src/services/ad_service.dart';
import 'package:floating_volume/src/widget_settings.dart';
import 'package:floating_volume/src/screens/privacy_policy_screen.dart';
import 'package:floating_volume/src/widgets/adaptive_banner.dart';

import 'package:floating_volume/src/bloc/status/bloc.dart' as bstatus;
import 'package:floating_volume/src/bloc/status/event.dart' as estatus;
import 'package:floating_volume/src/bloc/status/state.dart' as sstatus;

import 'package:floating_volume/src/bloc/permissions/bloc.dart' as bpermissions;
import 'package:floating_volume/src/bloc/permissions/event.dart'
    as epermissions;
import 'package:floating_volume/src/bloc/permissions/state.dart'
    as spermissions;

import 'package:floating_volume/src/bloc/theme/bloc.dart' as btheme;
import 'package:floating_volume/src/bloc/theme/state.dart' as stheme;
import 'package:floating_volume/src/bloc/theme/event.dart' as etheme;

const _kBlue = Color(0xFF2979FF);

// ---------------------------------------------------------------------------
// Style metadata — label and preview widget per style
// ---------------------------------------------------------------------------
extension WidgetStyleExt on WidgetStyle {
  String get label => switch (this) {
    WidgetStyle.android => 'Android',
    WidgetStyle.android12 => 'Android 12',
    WidgetStyle.ios => 'iOS',
    WidgetStyle.miui => 'MIUI',
    WidgetStyle.samsungOneUi => 'One UI',
    WidgetStyle.rgbAurora => 'RGB Aurora',
    WidgetStyle.rgbNeon => 'RGB Neon',
    WidgetStyle.cosmic => 'Cosmic',
    WidgetStyle.lava => 'Lava',
    WidgetStyle.glacier => 'Glacier',
    WidgetStyle.matrix => 'Matrix',
    WidgetStyle.retrowave => 'Retrowave',
  };

  bool get isSpecial => index >= 5; // rgbAurora, rgbNeon, cosmic, lava

  Widget get preview => switch (this) {
    WidgetStyle.android => const _AndroidStylePreview(),
    WidgetStyle.android12 => const _Android12StylePreview(),
    WidgetStyle.ios => const _IosStylePreview(),
    WidgetStyle.miui => const _MiuiStylePreview(),
    WidgetStyle.samsungOneUi => const _SamsungOneUiPreview(),
    WidgetStyle.rgbAurora => const _RgbAuroraPreview(),
    WidgetStyle.rgbNeon => const _RgbNeonPreview(),
    WidgetStyle.cosmic => const _CosmicPreview(),
    WidgetStyle.lava => const _LavaPreview(),
    WidgetStyle.glacier => const _GlacierPreview(),
    WidgetStyle.matrix => const _MatrixPreview(),
    WidgetStyle.retrowave => const _RetrowavePreview(),
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

        final requiredGranted =
            state.overlayPermission.status.isGranted &&
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
        actions: const [_ThemeQuickAction(), Gap(12)],
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
                      onTap:
                          () => context.read<bpermissions.Bloc>().add(
                            epermissions.Event.requestOverlayPermission,
                          ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    _PermissionRow(
                      title: 'Ejecutar en segundo plano',
                      subtitle:
                          'Para seguir mostrando los botones de volumen en la pantalla.',
                      isGranted:
                          state.batteryOptimizationPermission.status.isGranted,
                      onTap:
                          () => context.read<bpermissions.Bloc>().add(
                            epermissions
                                .Event
                                .requestBatteryOptimizationPermission,
                          ),
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
                  onTap:
                      () => context.read<bpermissions.Bloc>().add(
                        epermissions.Event.requestNotificationPermission,
                      ),
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
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      trailing:
          isGranted
              ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600)
              : const Icon(Icons.chevron_right_rounded),
      onTap: isGranted ? null : onTap,
    );
  }
}

class _ThemeQuickAction extends StatelessWidget {
  const _ThemeQuickAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<btheme.Bloc, stheme.State>(
      builder: (context, state) {
        final icon = switch (state.theme) {
          stheme.Theme.light => Icons.light_mode_rounded,
          stheme.Theme.dark => Icons.dark_mode_rounded,
          stheme.Theme.system => Icons.brightness_auto_rounded,
        };
        final next = switch (state.theme) {
          stheme.Theme.light => stheme.Theme.dark,
          stheme.Theme.dark => stheme.Theme.system,
          stheme.Theme.system => stheme.Theme.light,
        };
        return Semantics(
          button: true,
          label: 'Cambiar tema',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.read<btheme.Bloc>().add(etheme.Change(next)),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder:
                    (child, animation) => RotationTransition(
                      turns: Tween<double>(
                        begin: .7,
                        end: 1,
                      ).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                child: Icon(icon, key: ValueKey(state.theme), size: 22),
              ),
            ),
          ),
        );
      },
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
  final ScrollController _scrollController = ScrollController();
  WidgetStyle _selectedStyle = WidgetStyle.android;
  bool _styleLoaded = false;
  bool _isPinned = false;
  bool _useSystemVolume = false;
  Map<WidgetStyle, String?> _specialTimeLeft = const {};
  bool _privacyOptionsRequired = false;
  Timer? _unlockRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _unlockRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshSpecialUnlocks(),
    );
  }

  Future<Map<WidgetStyle, String?>> _readSpecialUnlocks() async {
    final result = <WidgetStyle, String?>{};
    for (final style in WidgetStyle.values.skip(5)) {
      result[style] = await AdService.timeLeftLabel(style.name);
    }
    return result;
  }

  Future<void> _refreshSpecialUnlocks() async {
    final result = await _readSpecialUnlocks();
    if (!mounted) return;
    final selectedExpired =
        WidgetStyle.values.indexOf(_selectedStyle) >= 5 &&
        result[_selectedStyle] == null;
    setState(() {
      _specialTimeLeft = result;
      if (selectedExpired) _selectedStyle = WidgetStyle.android;
    });
    if (selectedExpired) await _selectStyle(WidgetStyle.android);
  }

  @override
  void dispose() {
    _unlockRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_styleLoaded) return; // guard against re-entry
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('widget_style');
    var style =
        WidgetStyle.values.where((s) => s.name == name).firstOrNull ??
        WidgetStyle.android;
    final pinned = prefs.getBool('widget_pinned') ?? false;
    final sysVol = prefs.getBool('widget_use_sys_vol') ?? false;
    final crtSpeed = prefs.getDouble('widget_crt_speed') ?? 1.0;
    final crtGlow = prefs.getDouble('widget_crt_glow') ?? 1.0;
    final streamName = prefs.getString('widget_audio_stream') ?? 'MEDIA';
    final stream = switch (streamName) {
      'RING' => AudioStream.ring,
      'NOTIFICATION' => AudioStream.notification,
      'ALARM' => AudioStream.alarm,
      'SYSTEM' => AudioStream.system,
      'VOICE_CALL' => AudioStream.voiceCall,
      _ => AudioStream.media,
    };
    final showMixer = prefs.getBool('widget_show_mixer') ?? true;
    final autoPeek = prefs.getBool('widget_auto_peek') ?? true;
    final storedPeekDelay = prefs.getInt('widget_peek_delay') ?? 1800;
    final peekDelay =
        (storedPeekDelay == 4000 || storedPeekDelay == 5000)
            ? 1800
            : storedPeekDelay;
    final peekSize = prefs.getInt('widget_peek_size') ?? 16;
    final specialTimeLeft = await _readSpecialUnlocks();
    if (WidgetStyle.values.indexOf(style) >= 5 &&
        specialTimeLeft[style] == null) {
      style = WidgetStyle.android;
      await prefs.setString('widget_style', style.name);
    }
    final privacyOptionsRequired = await AdService.privacyOptionsRequired();
    if (mounted && !_styleLoaded) {
      setState(() {
        _selectedStyle = style;
        _isPinned = pinned;
        _useSystemVolume = sysVol;
        _specialTimeLeft = specialTimeLeft;
        _privacyOptionsRequired = privacyOptionsRequired;
        _styleLoaded = true;
      });
      try {
        await WidgetSettings.setWidgetStyle(style);
      } catch (_) {}
      try {
        await WidgetSettings.setPinned(pinned);
      } catch (_) {}
      try {
        await WidgetSettings.setUseSystemVolume(sysVol);
      } catch (_) {}
      try {
        await WidgetSettings.setAudioStream(stream);
        await WidgetSettings.setShowAudioMixer(showMixer);
        await WidgetSettings.setAutoPeekEnabled(autoPeek);
        await WidgetSettings.setAutoPeekDelay(peekDelay);
        await WidgetSettings.setPeekSize(peekSize);
      } catch (_) {}
      try {
        await WidgetSettings.setCreativeAnimSpeed(crtSpeed);
      } catch (_) {}
      try {
        await WidgetSettings.setCreativeGlowIntensity(crtGlow);
      } catch (_) {}
    }
  }

  Future<void> _selectStyle(WidgetStyle style) async {
    setState(() => _selectedStyle = style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_style', style.name);
    try {
      await WidgetSettings.setWidgetStyle(style);
    } catch (_) {}
  }

  Future<void> _togglePin(bool value) async {
    setState(() => _isPinned = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_pinned', value);
    try {
      await WidgetSettings.setPinned(value);
    } catch (_) {}
  }

  Future<void> _toggleSysVol(bool value) async {
    setState(() => _useSystemVolume = value);
    try {
      await WidgetSettings.setUseSystemVolume(value);
    } catch (_) {}
  }

  void _showUnlockSheet(WidgetStyle style) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _UnlockSheet(
            style: style,
            onUnlocked: () async {
              final timeLeft = await AdService.timeLeftLabel(style.name);
              if (mounted) {
                setState(() {
                  _specialTimeLeft = {..._specialTimeLeft, style: timeLeft};
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
        actions: const [_ThemeQuickAction(), Gap(12)],
      ),
      bottomNavigationBar: const AdaptiveBanner(),
      body: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          BlocBuilder<bstatus.Bloc, sstatus.State>(
            builder:
                (context, state) => _ControlHub(
                  enabled: state.isEnabled,
                  loading: state.operation != sstatus.Operation.none,
                  pinned: _isPinned,
                  useSystemIndicator: _useSystemVolume,
                  onToggle:
                      () => context.read<bstatus.Bloc>().add(
                        estatus.Event.toggle,
                      ),
                  onPinnedChanged: _togglePin,
                  onSystemIndicatorChanged: _toggleSysVol,
                ),
          ),
          const Gap(28),
          const _SectionHeader(
            eyebrow: 'PERSONALIZACIÓN',
            title: 'Elige una presencia',
            subtitle: 'La apariencia que verás sobre cualquier app.',
          ),
          const Gap(14),
          _SectionHeader.compact('Sistemas clásicos'),
          const Gap(12),
          SizedBox(
            height: 202,
            child:
                _styleLoaded
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

          const Gap(24),

          _SectionHeader.compact('Estilos especiales'),
          const Gap(12),
          SizedBox(
            height: 190,
            child:
                _styleLoaded
                    ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          WidgetStyle.values.length - 5, // estilos especiales
                      separatorBuilder: (_, __) => const Gap(12),
                      itemBuilder: (context, index) {
                        final style = WidgetStyle.values[5 + index];
                        final timeLeft = _specialTimeLeft[style];
                        final locked = timeLeft == null;
                        return _StyleCard(
                          label: style.label,
                          selected: _selectedStyle == style,
                          locked: locked,
                          unlockLabel: timeLeft,
                          preview: style.preview,
                          onTap:
                              () =>
                                  locked
                                      ? _showUnlockSheet(style)
                                      : _selectStyle(style),
                        );
                      },
                    )
                    : const Center(child: CircularProgressIndicator()),
          ),

          const Gap(28),
          const _SectionHeader(
            eyebrow: 'CONTROL FINO',
            title: 'Ajustes avanzados',
            subtitle: 'Abre solo lo que quieras ajustar.',
          ),
          const Gap(12),
          _FloatingButtonsSettingsCard(onChanged: () => setState(() {})),
          const Gap(12),
          _AudioControlSettingsCard(onChanged: () => setState(() {})),
          const Gap(12),
          _VolumeIndicatorSettingsCard(onChanged: () => setState(() {})),
          const Gap(12),
          _CreativeSettingsCard(onChanged: () => setState(() {})),
          const Gap(16),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restaurar valores de fábrica'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('¿Restaurar valores de fábrica?'),
                      content: const Text(
                        'Se restaurarán todos los ajustes de la aplicación. Puedes restaurar una sola categoría desde cada sección avanzada.',
                      ),
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
                await WidgetSettings.restoreDefaultsForStyle(
                  WidgetSettings.style,
                );
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valores de fábrica restablecidos.'),
                    ),
                  );
                }
              }
            },
          ),

          const Gap(24),

          const Gap(12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de privacidad'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                ),
                if (_privacyOptionsRequired) ...[
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant,
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Opciones de privacidad de anuncios'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final error = await AdService.showPrivacyOptions();
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se pudieron abrir las opciones de privacidad.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const Gap(16),

          // ── OEM compatibility banner ──────────────────────────────────────
          const _OemCompatBanner(),

          const Gap(32),
        ],
      ),
    );
  }
}

class _ControlHub extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final bool pinned;
  final bool useSystemIndicator;
  final VoidCallback onToggle;
  final ValueChanged<bool> onPinnedChanged;
  final ValueChanged<bool> onSystemIndicatorChanged;

  const _ControlHub({
    required this.enabled,
    required this.loading,
    required this.pinned,
    required this.useSystemIndicator,
    required this.onToggle,
    required this.onPinnedChanged,
    required this.onSystemIndicatorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = enabled ? const Color(0xFF2979FF) : cs.outline;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              enabled
                  ? const [Color(0xFF1769E8), Color(0xFF5B9DFF)]
                  : [cs.surfaceContainerHighest, cs.surfaceContainer],
        ),
        boxShadow:
            enabled
                ? [
                  BoxShadow(
                    color: accent.withAlpha(70),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? Colors.white.withAlpha(38) : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  color: enabled ? Colors.white : cs.onSurface,
                ),
              ),
              const Gap(12),
              Expanded(
                child: SizedBox(
                  height: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled ? 'Botón activo' : 'Botón inactivo',
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: enabled ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        enabled
                            ? 'Disponible sobre otras aplicaciones'
                            : 'Actívalo cuando lo necesites',
                        maxLines: 2,
                        style: TextStyle(
                          color:
                              enabled
                                  ? Colors.white.withAlpha(210)
                                  : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: loading ? null : (_) => onToggle(),
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withAlpha(80),
              ),
            ],
          ),
          const Gap(4),
          Container(
            height: 1,
            color: enabled ? Colors.white.withAlpha(45) : cs.outlineVariant,
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _HubToggle(
                  icon: Icons.push_pin_outlined,
                  label: 'Fijar posición',
                  value: pinned,
                  inverted: enabled,
                  helpText:
                      'Evita que los botones flotantes cambien de lugar al arrastrarlos accidentalmente. Desactívalo cuando quieras moverlos.',
                  onChanged: onPinnedChanged,
                ),
              ),
              const Gap(4),
              Expanded(
                child: _HubToggle(
                  icon: Icons.phone_android_outlined,
                  label: 'Indicador nativo',
                  value: useSystemIndicator,
                  inverted: enabled,
                  helpText:
                      'Muestra el panel de volumen propio de Android. Para que no cubra los botones, estos se mueven al borde contrario mientras la opción está activa y regresan a su posición anterior al desactivarla.',
                  onChanged: onSystemIndicatorChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool inverted;
  final String helpText;
  final ValueChanged<bool> onChanged;
  const _HubToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.inverted,
    required this.helpText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        inverted ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final borderColor =
        inverted
            ? Colors.white.withAlpha(55)
            : Theme.of(context).colorScheme.outlineVariant;
    final background =
        inverted
            ? Colors.white.withAlpha(22)
            : Theme.of(context).colorScheme.surface.withAlpha(150);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Ink(
          height: 82,
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: color),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.05,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Más información sobre $label',
                    child: Semantics(
                      button: true,
                      label: 'Más información sobre $label',
                      child: SizedBox(
                        width: 25,
                        height: 25,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _showHelp(context),
                          child: Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor:
                        inverted ? Colors.white.withAlpha(95) : null,
                    activeThumbColor: inverted ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 32),
                  const Gap(12),
                  Text(
                    label,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Gap(8),
                  Text(
                    helpText,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  const _SectionHeader({this.eyebrow, required this.title, this.subtitle});
  const _SectionHeader.compact(this.title) : eyebrow = null, subtitle = null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: TextStyle(
              color: cs.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const Gap(4),
        ],
        Text(
          title,
          style: (subtitle == null
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.headlineSmall)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const Gap(4),
          Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ],
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
  final String? unlockLabel;
  final Widget preview;
  final VoidCallback onTap;

  const _StyleCard({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.locked = false,
    this.unlockLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$label${locked
              ? ', bloqueado'
              : unlockLabel != null
              ? ', $unlockLabel'
              : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 156,
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? _kBlue : cs.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: _kBlue.withAlpha(80),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                    : isLight
                    ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: preview,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: _kBlue,
                          ),
                          const Gap(4),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                selected
                                    ? _kBlue
                                    : (isLight
                                        ? Colors.black87
                                        : Colors.white70),
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
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: Color(0xFFFFD700),
                          size: 26,
                        ),
                        Gap(6),
                        Text(
                          'Especial',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Gap(3),
                        Text(
                          'Ver anuncio',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!locked && unlockLabel != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withAlpha(42),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withAlpha(120),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: Color(0xFFFFC400),
                        ),
                        const Gap(3),
                        Text(
                          unlockLabel!,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFFFC400),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFFD700),
            size: 40,
          ),
          const Gap(12),
          Text(
            'Estilo Especial: ${widget.style.label}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            'Ve un breve anuncio para desbloquear ${widget.style.label}\ndurante 24 horas. Cada anuncio añade 24 horas.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
              label: const Text('Ver anuncio — desbloquear 24 horas'),
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
    setState(() {
      _loading = true;
      _failed = false;
    });
    final shown = await AdService.showAd(
      styleKey: widget.style.name,
      onRewarded: () {
        if (mounted) Navigator.pop(context);
        widget.onUnlocked();
      },
      onClosedWithoutReward: () {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _failed = true;
        });
      },
    );
    if (mounted && !shown) {
      setState(() {
        _loading = false;
        _failed = true;
      });
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
            _PreviewCircle(label: '+', bg: bg, fg: fg, border: dark),
            const Gap(10),
            _PreviewCircle(label: '−', bg: bg, fg: fg, border: dark),
          ],
        ),
        const Gap(14),
        // Matches native applyAndroid(): white/dark card, grey track, blue fill
        Transform.translate(
          offset: const Offset(0, -5),
          child: _MiniIndicator(
            card: bg,
            track: dark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E0),
            fill: _kBlue,
            text: fg,
            border:
                dark ? Colors.white.withAlpha(70) : Colors.black.withAlpha(45),
          ),
        ),
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
        // Matches native applyAndroid12(): blue card, darker track, white fill
        const _MiniIndicator(
          card: _kBlue,
          track: Color(0xFF1555CC),
          fill: Colors.white,
          text: Colors.white,
        ),
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
      border: Border.all(
        color: (dark ? Colors.white : Colors.black).withAlpha(dark ? 80 : 30),
        width: 1,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: frostedBtn,
              alignment: Alignment.center,
              child: Text(
                '+',
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Gap(10),
            Container(
              width: 44,
              height: 44,
              decoration: frostedBtn,
              alignment: Alignment.center,
              child: Text(
                '−',
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const Gap(10),
        // Matches native applyIos(): frosted card, translucent track, white fill
        _MiniIndicator(
          card: (dark ? Colors.white : Colors.black).withAlpha(baseAlpha),
          track: (dark ? Colors.white : Colors.black).withAlpha(50),
          fill: dark ? Colors.white : Colors.black87,
          text: dark ? Colors.white : Colors.black87,
          border: (dark ? Colors.white : Colors.black).withAlpha(
            dark ? 80 : 30,
          ),
          volLabel: '🔊',
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
        // Matches native applyMiui(): dark translucent card with orange border,
        // orange fill anchored at the BOTTOM (was previously drawn from the top)
        _MiniIndicator(
          card: const Color(0x281E1E1E),
          track: Colors.white.withAlpha(50),
          fill: _orange,
          text: _orange,
          border: _orange.withAlpha(160),
          volLabel: '🔊',
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
        style: TextStyle(
          color: accent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
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
        // Matches native applyOneUi(): dark translucent card, teal fill, teal text
        _MiniIndicator(
          card: const Color(0x32141419),
          track: Colors.white.withAlpha(60),
          fill: _teal,
          text: _teal,
          border: Colors.white.withAlpha(70),
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
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
    this.end = Alignment.bottomRight,
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
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
        final cyan =
            Color.lerp(
              const Color(0xFF00FFFF),
              const Color(0xFF00B4FF),
              pingPong,
            )!;
        final magenta =
            Color.lerp(
              const Color(0xFFFF00FF),
              const Color(0xFFFF0090),
              pingPong,
            )!;

        final trueCyan = const Color(0xFF00FFFF);
        final trueMagenta = const Color(0xFFFF00FF);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NeonButton(
                  label: '+',
                  glowColor: cyan,
                  t: t,
                  colors: [trueCyan, trueMagenta, trueCyan],
                ),
                const Gap(10),
                _NeonButton(
                  label: '−',
                  glowColor: magenta,
                  t: 1.0 - t,
                  colors: [trueMagenta, trueCyan, trueMagenta],
                ),
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
                boxShadow: [
                  BoxShadow(color: cyan.withAlpha(120), blurRadius: 8),
                ],
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
  const _NeonButton({
    required this.label,
    required this.glowColor,
    required this.t,
    required this.colors,
  });

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
          BoxShadow(
            color: glowColor.withAlpha(160),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
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
  static const _purple = Color(0xFF9B5DE5);
  static const _deepPurple = Color(0xFF5B10A0);
  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
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
        final c1 = Color.lerp(_spaceBlue, const Color(0xFF1A0A3F), pingPong)!;
        final c2 = Color.lerp(_purple, _deepPurple, pingPong)!;
        final c3 = Color.lerp(_gold, _orange, pingPong)!;

        final borderColors = [
          _purple,
          Colors.transparent,
          _gold,
          Colors.transparent,
          _purple,
        ];

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _CosmicStarPainter(_ctrl.value)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CosmicButton(
                      label: '+',
                      bgColors: [c1, c2],
                      borderColors: borderColors,
                      t: t,
                    ),
                    const Gap(10),
                    _CosmicButton(
                      label: '−',
                      bgColors: [c2, c3],
                      borderColors: borderColors,
                      t: t,
                    ),
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
    required this.label,
    required this.bgColors,
    required this.borderColors,
    required this.t,
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
            gradient: LinearGradient(
              colors: bgColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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
        ),
      ),
    );
  }
}

class _CosmicStarPainter extends CustomPainter {
  final double t;
  _CosmicStarPainter(this.t);

  static const _stars = [
    Offset(0.10, 0.10),
    Offset(0.88, 0.18),
    Offset(0.55, 0.50),
    Offset(0.20, 0.78),
    Offset(0.80, 0.70),
    Offset(0.40, 0.25),
    Offset(0.70, 0.88),
  ];
  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFFFFFFF),
    Color(0xFF9B5DE5),
    Color(0xFFFFFFFF),
    Color(0xFFFFD700),
    Color(0xFF9B5DE5),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _stars.length; i++) {
      final phase = (t + i / _stars.length) % 1.0;
      final alpha =
          phase < 0.20
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
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _heartbeat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 12,
      ), // first beat up
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.3),
        weight: 12,
      ), // valley
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 0.75),
        weight: 12,
      ), // second beat
      TweenSequenceItem(
        tween: Tween(begin: 0.75, end: 0.0),
        weight: 14,
      ), // back to rest
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50), // rest pause
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heartbeat,
      builder: (_, __) {
        final t = _heartbeat.value;
        final dark =
            Color.lerp(const Color(0xFF3D0000), const Color(0xFF6B0000), t)!;
        final mid =
            Color.lerp(const Color(0xFFFF4500), const Color(0xFFFF6A00), t)!;
        final bright =
            Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFFD700), t)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GradientCircle(
                  label: '+',
                  colors: [dark, mid],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                const Gap(10),
                _GradientCircle(
                  label: '−',
                  colors: [mid, bright],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
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

// ── Glacier (Aurora on Ice) ──────────────────────────────────────────────────
// Deep arctic blue → glacial cyan with an aurora tint (mint/violet) drifting
// through it, counter-rotating white "light glint" borders and an ice flash.
class _GlacierPreview extends StatefulWidget {
  const _GlacierPreview();
  @override
  State<_GlacierPreview> createState() => _GlacierPreviewState();
}

class _GlacierPreviewState extends State<_GlacierPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _btn(String label, List<Color> colors, double rot, Color glow) =>
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: const [
              Colors.white,
              Colors.transparent,
              Color(0xFF7FF6FF),
              Colors.transparent,
              Colors.white,
            ],
            transform: GradientRotation(rot * 2 * math.pi),
          ),
          boxShadow: [BoxShadow(color: glow.withAlpha(110), blurRadius: 12)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE3FCFF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final wave = math.sin(t * math.pi * 2) * 0.5 + 0.5;
        final deep =
            Color.lerp(const Color(0xFF0B2E4F), const Color(0xFF14104F), wave)!;
        final cyan =
            Color.lerp(const Color(0xFF38B6D4), const Color(0xFF52E5C4), wave)!;
        final tint =
            Color.lerp(const Color(0xFF38B6D4), const Color(0xFF7C6BE8), wave)!;
        final night =
            Color.lerp(const Color(0xFF0A1B3F), const Color(0xFF071A2E), wave)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _btn('+', [deep, cyan], t, cyan),
                const Gap(10),
                _btn('−', [tint, night], -t, tint),
              ],
            ),
            const Gap(10),
            _MiniIndicator(
              card: const Color(0xFF08131F),
              track: Colors.white.withAlpha(60),
              fill: cyan,
              text: const Color(0xFFE3FCFF),
              border: Colors.white.withAlpha(140),
            ),
          ],
        );
      },
    );
  }
}

// ── Matrix ───────────────────────────────────────────────────────────────────
// Terminal green on black with a phosphor pulse and periodic data burst.
class _MatrixPreview extends StatefulWidget {
  const _MatrixPreview();
  @override
  State<_MatrixPreview> createState() => _MatrixPreviewState();
}

class _MatrixPreviewState extends State<_MatrixPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _btn(String label, Color green) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFF020A02),
      shape: BoxShape.circle,
      border: Border.all(color: green, width: 1.5),
      boxShadow: [BoxShadow(color: green.withAlpha(90), blurRadius: 10)],
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(
        color: green,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        height: 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final pulse = math.sin(t * math.pi * 2) * 0.5 + 0.5;
        final burst = t < 0.08 ? 1.0 : 0.0;
        final green =
            Color.lerp(
              const Color(0xFF007718),
              const Color(0xFF00FF41),
              (pulse * 0.7 + burst * 0.3).clamp(0.0, 1.0),
            )!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_btn('+', green), const Gap(10), _btn('−', green)],
            ),
            const Gap(10),
            _MiniIndicator(
              card: const Color(0xFF020A02),
              track: const Color(0xFF00FF41).withAlpha(50),
              fill: green,
              text: const Color(0xFF00FF41),
              border: green,
            ),
          ],
        );
      },
    );
  }
}

// ── Retrowave ────────────────────────────────────────────────────────────────
// 80s synthwave sunset: violet → hot pink → orange with cyan accents.
class _RetrowavePreview extends StatefulWidget {
  const _RetrowavePreview();
  @override
  State<_RetrowavePreview> createState() => _RetrowavePreviewState();
}

class _RetrowavePreviewState extends State<_RetrowavePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _btn(
    String label,
    List<Color> colors,
    double t, {
    bool palm = false,
  }) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: const [
          Color(0xFFFF2975),
          Colors.transparent,
          Color(0xFF00E5FF),
          Colors.transparent,
          Color(0xFFFF2975),
        ],
        transform: GradientRotation(t * 2 * math.pi),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF2975).withAlpha(110),
          blurRadius: 12,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: palm ? const _PalmPainter(mirror: true) : null,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final pingPong = math.sin(t * math.pi * 2) * 0.5 + 0.5;
        final violet =
            Color.lerp(
              const Color(0xFF2B1055),
              const Color(0xFF4A1A7A),
              pingPong,
            )!;
        final pink =
            Color.lerp(
              const Color(0xFFFF2975),
              const Color(0xFFFF5FA2),
              pingPong,
            )!;
        final orange =
            Color.lerp(
              const Color(0xFFFF8C42),
              const Color(0xFFFFB56B),
              pingPong,
            )!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _btn('+', [violet, pink], t),
                const Gap(10),
                _btn('−', [pink, orange], t, palm: true),
              ],
            ),
            const Gap(10),
            _MiniIndicator(
              card: const Color(0xFF1A0B3D),
              track: const Color(0xFFFF2975).withAlpha(60),
              fill: pink,
              text: const Color(0xFF00E5FF),
            ),
          ],
        );
      },
    );
  }
}

// Palm tree silhouette for the Retrowave preview — mirrors the native
// PalmShadowDrawable in AnimatedStyles.kt (keep both in sync).
class _PalmPainter extends CustomPainter {
  final bool mirror;
  const _PalmPainter({this.mirror = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    final paint =
        Paint()
          ..color = const Color(0x96140428)
          ..style = PaintingStyle.fill;

    canvas.save();
    if (mirror) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    double x(double f) => w * f;
    double y(double f) => h * f;

    // Trunk: tapered filled shape leaning right
    canvas.drawPath(
      Path()
        ..moveTo(x(0.27), y(0.95))
        ..quadraticBezierTo(x(0.33), y(0.62), x(0.49), y(0.41))
        ..lineTo(x(0.545), y(0.445))
        ..quadraticBezierTo(x(0.39), y(0.66), x(0.345), y(0.95))
        ..close(),
      paint,
    );

    // Fronds: filled leaf shapes with drooping tips
    final cx = x(0.52), cy = y(0.42);
    void leaf(
      double tipX,
      double tipY,
      double upX,
      double upY,
      double dnX,
      double dnY,
    ) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy)
          ..quadraticBezierTo(x(upX), y(upY), x(tipX), y(tipY))
          ..quadraticBezierTo(x(dnX), y(dnY), cx, cy)
          ..close(),
        paint,
      );
    }

    leaf(0.08, 0.46, 0.24, 0.20, 0.30, 0.40);
    leaf(0.14, 0.22, 0.28, 0.14, 0.34, 0.30);
    leaf(0.46, 0.06, 0.42, 0.14, 0.56, 0.16);
    leaf(0.90, 0.20, 0.72, 0.10, 0.68, 0.28);
    leaf(0.96, 0.46, 0.80, 0.20, 0.72, 0.40);

    // Coconuts at the crown
    canvas.drawCircle(Offset(x(0.485), y(0.475)), w * 0.035, paint);
    canvas.drawCircle(Offset(x(0.555), y(0.475)), w * 0.035, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PalmPainter old) => old.mirror != mirror;
}

// ===========================================================================
// Shared preview sub-widgets
// ===========================================================================
class _PreviewCircle extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool border;
  const _PreviewCircle({
    required this.label,
    required this.bg,
    required this.fg,
    this.border = false,
  });

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

/// Miniature replica of the native VolumeIndicatorView layout:
/// number label on top, vertical track with a bottom-anchored fill, and a
/// "VOL" label at the bottom. Keep visually in sync with
/// android/.../VolumeIndicatorView.kt so previews match the real overlay.
class _MiniIndicator extends StatelessWidget {
  final Color card;
  final Color track;
  final Color fill;
  final Color text;
  final Color? border;
  final bool showVol;
  final String volLabel;
  final double fillFraction;

  const _MiniIndicator({
    required this.card,
    required this.track,
    required this.fill,
    required this.text,
    this.border,
    this.showVol = true,
    this.volLabel = 'VOL',
    this.fillFraction = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 104,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: border != null ? Border.all(color: border!, width: 1) : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '8',
            style: TextStyle(
              color: text,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(4),
          Container(
            width: 7,
            height: 56,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fillFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          if (showVol) ...[
            const Gap(4),
            Text(
              volLabel,
              style: TextStyle(
                color: text.withAlpha(180),
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
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

  // Styles that use rectangular buttons (corner radius slider is relevant)
  static const _rectStyles = {WidgetStyle.miui, WidgetStyle.samsungOneUi};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentStyle = WidgetSettings.style;
    final cornerApplies = _rectStyles.contains(currentStyle);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        leading: const Icon(Icons.smart_button_outlined),
        title: const Text('Botones flotantes'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                _buildSliderRow(
                  context,
                  icon: Icons.aspect_ratio_outlined,
                  label: 'Tamaño',
                  value: WidgetSettings.buttonSize.toDouble(),
                  min: 36,
                  max: 72,
                  divisions: 18,
                  onChanged: (v) {
                    WidgetSettings.setButtonSize(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.buttonSize}px',
                ),
                // Corner radius slider — only meaningful for rect-based styles
                Opacity(
                  opacity: cornerApplies ? 1.0 : 0.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSliderRow(
                        context,
                        icon: Icons.rounded_corner_outlined,
                        label: 'Redondeo (esquinas)',
                        value: WidgetSettings.buttonCornerRadius,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        onChanged:
                            cornerApplies
                                ? (v) {
                                  WidgetSettings.setButtonCornerRadius(v);
                                  onChanged();
                                }
                                : (_) {}, // no-op for circle-only styles
                        formatStr:
                            WidgetSettings.buttonCornerRadius < 0.15
                                ? 'Cuadrado'
                                : WidgetSettings.buttonCornerRadius > 0.85
                                ? 'Redondo'
                                : '${(WidgetSettings.buttonCornerRadius * 100).round()}%',
                      ),
                      if (!cornerApplies)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, bottom: 4),
                          child: Text(
                            'Solo aplica en estilos MIUI y One UI',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.height_outlined,
                  label: 'Separación',
                  value: WidgetSettings.buttonGap.toDouble(),
                  min: 0,
                  max: 40,
                  divisions: 20,
                  onChanged: (v) {
                    WidgetSettings.setButtonGap(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.buttonGap}px',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.opacity_outlined,
                  label: 'Opacidad',
                  value: WidgetSettings.opacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) {
                    WidgetSettings.setOpacity(v);
                    onChanged();
                  },
                  formatStr: '${(WidgetSettings.opacity * 100).round()}%',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.stairs_outlined,
                  label: 'Paso de volumen por tap',
                  value: WidgetSettings.volumeStep.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) {
                    WidgetSettings.setVolumeStep(v.toInt());
                    onChanged();
                  },
                  formatStr:
                      '${WidgetSettings.volumeStep} nivel${WidgetSettings.volumeStep > 1 ? 'es' : ''}',
                ),
                _buildSwitchRow(
                  context,
                  icon: Icons.vibration_outlined,
                  label: 'Vibrar al tocar',
                  value: WidgetSettings.hapticFeedback,
                  onChanged: (v) {
                    WidgetSettings.setHapticFeedback(v);
                    onChanged();
                  },
                ),
                _SectionRestoreButton(
                  onPressed: () async {
                    await WidgetSettings.restoreButtonsDefaults();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioControlSettingsCard extends StatelessWidget {
  final VoidCallback onChanged;
  const _AudioControlSettingsCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        leading: const Icon(Icons.tune_rounded),
        title: const Text('Canales de audio'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                Text(
                  'Los botones y la barra compacta controlan el canal principal. El mezclador permite ajustar los demás.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const Gap(12),
                DropdownButtonFormField<AudioStream>(
                  value: WidgetSettings.selectedAudioStream,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.tune_rounded),
                    labelText: 'Canal principal',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      AudioStream.values
                          .map(
                            (stream) => DropdownMenuItem(
                              value: stream,
                              child: Text(stream.label),
                            ),
                          )
                          .toList(),
                  onChanged: (stream) {
                    if (stream == null) return;
                    WidgetSettings.setAudioStream(stream);
                    onChanged();
                  },
                ),
                const Gap(12),
                _buildSwitchRow(
                  context,
                  icon: Icons.equalizer_rounded,
                  label: 'Permitir mezclador multibarra',
                  value: WidgetSettings.showAudioMixer,
                  onChanged: (value) {
                    WidgetSettings.setShowAudioMixer(value);
                    onChanged();
                  },
                ),
                const Gap(4),
                Text(
                  'Algunos fabricantes unen tono y notificaciones. Si ocurre, ambas barras se actualizarán juntas.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const Gap(16),
                Text(
                  'Ocultamiento al borde',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                _buildSwitchRow(
                  context,
                  icon: Icons.keyboard_double_arrow_right_rounded,
                  label: 'Plegar cuando no se usa',
                  value: WidgetSettings.autoPeekEnabled,
                  onChanged: (value) {
                    WidgetSettings.setAutoPeekEnabled(value);
                    onChanged();
                  },
                ),
                Opacity(
                  opacity: WidgetSettings.autoPeekEnabled ? 1 : 0.45,
                  child: Column(
                    children: [
                      _buildSliderRow(
                        context,
                        icon: Icons.timer_outlined,
                        label: 'Espera para plegar',
                        value: WidgetSettings.autoPeekDelay.toDouble(),
                        min: 1000,
                        max: 10000,
                        divisions: 9,
                        onChanged:
                            WidgetSettings.autoPeekEnabled
                                ? (value) {
                                  WidgetSettings.setAutoPeekDelay(
                                    value.toInt(),
                                  );
                                  onChanged();
                                }
                                : (_) {},
                        formatStr: '${WidgetSettings.autoPeekDelay ~/ 1000}s',
                      ),
                      _buildSliderRow(
                        context,
                        icon: Icons.unfold_less_rounded,
                        label: 'Pestaña visible',
                        value: WidgetSettings.peekSize.toDouble(),
                        min: 8,
                        max: 24,
                        divisions: 8,
                        onChanged:
                            WidgetSettings.autoPeekEnabled
                                ? (value) {
                                  WidgetSettings.setPeekSize(value.toInt());
                                  onChanged();
                                }
                                : (_) {},
                        formatStr: '${WidgetSettings.peekSize}px',
                      ),
                    ],
                  ),
                ),
                Text(
                  'Toca la pestaña que queda en el borde para volver a desplegar el control.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                _SectionRestoreButton(
                  onPressed: () async {
                    await WidgetSettings.restoreAudioDefaults();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
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
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        leading: const Icon(Icons.graphic_eq_rounded),
        title: const Text('Barra de volumen'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                _buildSliderRow(
                  context,
                  icon: Icons.timer_outlined,
                  label: 'Duración',
                  value: WidgetSettings.indicatorHideDelay.toDouble(),
                  min: 500,
                  max: 4000,
                  divisions: 14,
                  onChanged: (v) {
                    WidgetSettings.setIndicatorHideDelay(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.indicatorHideDelay / 1000}s',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.straighten_outlined,
                  label: 'Ancho',
                  value: WidgetSettings.indicatorWidth.toDouble(),
                  min: 24,
                  max: 100,
                  divisions: 38,
                  onChanged: (v) {
                    WidgetSettings.setIndicatorWidth(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.indicatorWidth}px',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.height_rounded,
                  label: 'Alto',
                  value: WidgetSettings.indicatorHeight.toDouble(),
                  min: 100,
                  max: 300,
                  divisions: 40,
                  onChanged: (v) {
                    WidgetSettings.setIndicatorHeight(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.indicatorHeight}px',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.space_bar_rounded,
                  label: 'Distancia',
                  value: WidgetSettings.indicatorGap.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 5,
                  onChanged: (v) {
                    WidgetSettings.setIndicatorGap(v.toInt());
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.indicatorGap}px',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.opacity_outlined,
                  label: 'Opacidad',
                  value: WidgetSettings.indicatorOpacity,
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  onChanged: (v) {
                    WidgetSettings.setIndicatorOpacity(v);
                    onChanged();
                  },
                  formatStr:
                      '${(WidgetSettings.indicatorOpacity * 100).round()}%',
                ),
                _buildSwitchRow(
                  context,
                  icon: Icons.pin_outlined,
                  label: 'Mostrar número de volumen',
                  value: WidgetSettings.showIndicatorNumber,
                  onChanged: (v) {
                    WidgetSettings.setShowIndicatorNumber(v);
                    onChanged();
                  },
                ),
                _buildSwitchRow(
                  context,
                  icon: Icons.volume_up_outlined,
                  label: 'Mostrar etiqueta inferior',
                  value: WidgetSettings.showIndicatorIcon,
                  onChanged: (v) {
                    WidgetSettings.setShowIndicatorIcon(v);
                    onChanged();
                  },
                ),
                _SectionRestoreButton(
                  onPressed: () async {
                    await WidgetSettings.restoreIndicatorDefaults();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreativeSettingsCard extends StatelessWidget {
  final VoidCallback onChanged;
  const _CreativeSettingsCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.withAlpha(100), width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        leading: const Icon(Icons.auto_awesome, color: Colors.purple),
        title: const Text('Diseños creativos'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                Text(
                  'Ajustes exclusivos para temas como Cosmic, Lava o RGB.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const Gap(16),
                _buildSliderRow(
                  context,
                  icon: Icons.speed_outlined,
                  label: 'Velocidad de Animación',
                  value: WidgetSettings.creativeAnimSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  onChanged: (v) {
                    WidgetSettings.setCreativeAnimSpeed(v);
                    onChanged();
                  },
                  formatStr: '${WidgetSettings.creativeAnimSpeed}x',
                ),
                _buildSliderRow(
                  context,
                  icon: Icons.blur_on_outlined,
                  label: 'Densidad del destello',
                  value: WidgetSettings.creativeGlowIntensity,
                  min: 0.2,
                  max: 3.0,
                  divisions: 14,
                  onChanged: (v) {
                    WidgetSettings.setCreativeGlowIntensity(v);
                    onChanged();
                  },
                  formatStr:
                      '${(WidgetSettings.creativeGlowIntensity * 100).toInt()}%',
                ),
                _SectionRestoreButton(
                  onPressed: () async {
                    await WidgetSettings.restoreCreativeDefaults();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSwitchRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const Gap(10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _SectionRestoreButton extends StatelessWidget {
  final Future<void> Function() onPressed;
  const _SectionRestoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
      label: const Text('Restaurar esta sección'),
    ),
  );
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

// ---------------------------------------------------------------------------
// OEM Compatibility Banner
// Shown once on devices with aggressive memory management (MIUI, ColorOS, One UI)
// Guides users to enable the "Auto-Start" permission in system settings.
// ---------------------------------------------------------------------------

enum _OemType { miui, colorOs, oneUi, other }

class _OemCompatBanner extends StatefulWidget {
  const _OemCompatBanner();

  @override
  State<_OemCompatBanner> createState() => _OemCompatBannerState();
}

class _OemCompatBannerState extends State<_OemCompatBanner> {
  static const _prefKey = 'oem_banner_dismissed';

  bool _dismissed = true; // start hidden until we know
  _OemType _oemType = _OemType.other;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_prefKey) ?? false;

    // Read manufacturer via dart:io Platform — works on Android
    // On Android, Platform.operatingSystemVersion includes manufacturer info
    // We use a secondary channel; for simplicity we read from the known
    // SharedPreferences key written at app start via platform channel if available,
    // otherwise fallback to a known OEM detection heuristic.
    String manufacturer = '';
    try {
      // Try to read cached manufacturer set by native side
      manufacturer = prefs.getString('device_manufacturer') ?? '';
    } catch (_) {}

    final oem = _classifyOem(manufacturer);

    if (mounted) {
      setState(() {
        _dismissed = dismissed || oem == _OemType.other;
        _oemType = oem;
      });
    }
  }

  static _OemType _classifyOem(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return _OemType.miui;
    }
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return _OemType.colorOs;
    }
    if (m.contains('samsung')) {
      return _OemType.oneUi;
    }
    return _OemType.other;
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    if (mounted) setState(() => _dismissed = true);
  }

  String get _title => switch (_oemType) {
    _OemType.miui => '⚡ Paso extra requerido en MIUI',
    _OemType.colorOs => '⚡ Paso extra requerido en ColorOS',
    _OemType.oneUi => '⚡ Paso extra requerido en One UI',
    _OemType.other => '',
  };

  String get _instructions => switch (_oemType) {
    _OemType.miui =>
      'Para que los botones flotantes no desaparezcan:\n\n'
          '1. Ve a Ajustes → Aplicaciones → Floating Volume\n'
          '2. Toca "Inicio automático" y actívalo ✅\n'
          '3. También ve a Batería → Ahorro de batería → Sin restricciones',
    _OemType.colorOs =>
      'Para evitar que el sistema detenga los botones flotantes:\n\n'
          '1. Ve a Ajustes → Aplicaciones → Floating Volume\n'
          '2. Toca "Inicio automático" y actívalo ✅\n'
          '3. También en Batería → selecciona "Sin restricciones"',
    _OemType.oneUi =>
      'Para mantener los botones activos en segundo plano:\n\n'
          '1. Ve a Ajustes → Aplicaciones → Floating Volume\n'
          '2. En Batería → selecciona "Sin restricciones"\n'
          '3. También desactiva "Batería Adaptable" si tienes problemas',
    _OemType.other => '',
  };

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _dismissed ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300).withAlpha(120)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
              ),
              title: Text(
                _title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBF360C),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFFBF360C),
                ),
                onPressed: _dismiss,
                tooltip: 'No mostrar de nuevo',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                _instructions,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5D4037),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
