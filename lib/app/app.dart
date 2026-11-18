import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_locales.dart';
import '../core/localization/locale_cubit.dart';
import '../core/network/connectivity_cubit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';
import '../core/widgets/network_status_banner.dart';
import '../l10n/gen/app_localizations.dart';
import 'di/injection.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: sl<LocaleCubit>()),
        BlocProvider.value(value: sl<ConnectivityCubit>()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    // Chỉ rebuild MaterialApp khi theme mode hoặc locale đổi.
    final themeMode = context.select((ThemeCubit c) => c.state);
    final locale = context.select((LocaleCubit c) => c.state);
    final router = sl<GoRouter>();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // ---- Theme ----
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // ---- Localization ----
      locale: locale, // null = theo ngôn ngữ thiết bị
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: AppLocales.resolve,
      // ---- Router ----
      routerConfig: router,
      // ---- Lớp phủ cho MỌI màn ----
      builder: (context, child) => NetworkStatusBanner(child: child!),
    );
  }
}
