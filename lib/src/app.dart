import 'package:floating_volume/src/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class _FloatingVolumeAppView extends StatelessWidget {
  const _FloatingVolumeAppView();

  // Azul vibrante del diseño de referencia
  static const _seed = Color(0xFF2979FF);

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );

  @override
  Widget build(BuildContext context) => BlocBuilder<btheme.Bloc, stheme.State>(
    builder: (context, state) {
      final themeMode = switch (state.theme) {
        stheme.Theme.dark => ThemeMode.dark,
        stheme.Theme.light => ThemeMode.light,
        stheme.Theme.system => ThemeMode.system,
      };

      return MaterialApp(
        home: const HomeScreen(),
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: themeMode,
      );
    },
  );
}
