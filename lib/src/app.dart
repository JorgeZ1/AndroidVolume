import 'package:floating_volume/src/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:floating_volume/src/app_language.dart';

import 'package:floating_volume/src/bloc/permissions/bloc.dart' as bpermissions;
import 'package:floating_volume/src/bloc/permissions/event.dart'
    as epermissions;
import 'package:floating_volume/src/bloc/permissions/state.dart'
    as spermissions;

import 'package:floating_volume/src/bloc/status/bloc.dart' as bstatus;
import 'package:floating_volume/src/bloc/status/event.dart' as estatus;
import 'package:floating_volume/src/bloc/status/state.dart' as sstatus;

import 'package:floating_volume/src/bloc/theme/bloc.dart' as btheme;
import 'package:floating_volume/src/bloc/theme/state.dart' as stheme;
import 'package:floating_volume/src/bloc/theme/event.dart' as etheme;

class FloatingVolumeApp extends StatelessWidget {
  const FloatingVolumeApp({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create:
            (_) =>
                bpermissions.Bloc(spermissions.State())
                  ..add(epermissions.Event.initialize),
      ),
      BlocProvider(
        create:
            (_) => bstatus.Bloc(sstatus.State())..add(estatus.Event.initialize),
      ),
      BlocProvider(
        create: (_) => btheme.Bloc()..add(etheme.Event.initialize()),
      ),
    ],
    child: _FloatingVolumeAppView(),
  );
}

class _FloatingVolumeAppView extends StatefulWidget {
  const _FloatingVolumeAppView();

  @override
  State<_FloatingVolumeAppView> createState() => _FloatingVolumeAppViewState();
}

class _FloatingVolumeAppViewState extends State<_FloatingVolumeAppView>
    with WidgetsBindingObserver {
  int _systemRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() => _systemRevision++);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Vibrant blue from the reference design.
  static const _seed = Color(0xFF2979FF);

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F8FC),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF101114),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101114),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF181A20),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLanguage>(
    valueListenable: LanguageSettings.selection,
    builder:
        (context, language, _) => BlocBuilder<btheme.Bloc, stheme.State>(
          builder: (context, state) {
            final themeMode = switch (state.theme) {
              stheme.Theme.dark => ThemeMode.dark,
              stheme.Theme.light => ThemeMode.light,
              stheme.Theme.system => ThemeMode.system,
            };

            final effective = LanguageSettings.isSpanish ? 'es' : 'en';
            return MaterialApp(
              home: HomeScreen(key: ValueKey('$effective-$_systemRevision')),
              locale:
                  language == AppLanguage.system
                      ? null
                      : Locale(language == AppLanguage.spanish ? 'es' : 'en'),
              supportedLocales: const [Locale('en'), Locale('es')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: _lightTheme,
              darkTheme: _darkTheme,
              themeMode: themeMode,
            );
          },
        ),
  );
}
