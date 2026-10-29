
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

import 'app/theme.dart';
import 'core/database/database.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNHANDLED ERROR: $error');
    debugPrintStack(stackTrace: stack);
    return false;
  };

  try {
    await Database.instance.init();
  } catch (e, stack) {
    debugPrint('DATABASE INIT ERROR: $e');
    debugPrintStack(stackTrace: stack);
  }

  runApp(const GeoxalApp());
}

class GeoxalApp extends StatelessWidget {
  const GeoxalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Geoxal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      supportedLocales: FLocalizations.supportedLocales,
      builder: (context, child) {
        return FTheme(
          data: FThemes.zinc.light.desktop,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}


